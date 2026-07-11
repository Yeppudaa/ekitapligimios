<?php

namespace Ekitapligim\MobileApi\Api\Controller;

use Ekitapligim\MobileApi\Service\AppleAuthorization;
use XF\Entity\User;
use XF\Entity\UserConnectedAccount;
use XF\Repository\UserRepository;
use XF\Service\User\RegistrationService;

class AuthApple extends AbstractMobileController
{
	public function actionPost()
	{
		$this->assertMobileWriteScope();

		$identityToken = trim($this->filter('identity_token', 'str'));
		$authorizationCode = trim($this->filter('authorization_code', 'str'));
		$nonce = trim($this->filter('nonce', 'str'));
		if ($identityToken === '' || $authorizationCode === '' || $nonce === '')
		{
			return $this->apiError('Apple identity token and authorization code are required.', 'apple_token_required');
		}

		$appleUser = $this->verifyIdentityToken($identityToken, $nonce);
		if (!$appleUser)
		{
			return $this->apiError('Apple identity token could not be verified.', 'apple_token_invalid');
		}

		$exchange = AppleAuthorization::exchangeCode($authorizationCode);
		$exchangedUser = $exchange
			? $this->verifyIdentityToken((string) $exchange['identity_token'])
			: null;
		if (!$exchangedUser || !hash_equals((string) $appleUser['sub'], (string) $exchangedUser['sub']))
		{
			return $this->apiError('Apple authorization could not be completed.', 'apple_authorization_unavailable', null, 503);
		}

		$user = $this->resolveUserFromApple($appleUser);
		if (!$user)
		{
			return $this->apiError('Apple account could not be linked to a XenForo user.', 'apple_user_unavailable');
		}
		if (!AppleAuthorization::storeForUser((int) $user->user_id, (string) $exchange['refresh_token']))
		{
			return $this->apiError('Apple authorization could not be completed.', 'apple_authorization_unavailable', null, 503);
		}

		return $this->apiResult($this->buildAuthPayload($user));
	}

	protected function verifyIdentityToken(string $identityToken, ?string $rawNonce = null): ?array
	{
		$parts = explode('.', $identityToken);
		if (count($parts) !== 3)
		{
			return null;
		}

		$header = json_decode($this->base64UrlDecode($parts[0]), true);
		$payload = json_decode($this->base64UrlDecode($parts[1]), true);
		if (!is_array($header) || !is_array($payload))
		{
			return null;
		}
		if (!$this->verifyAppleSignature($parts[0] . '.' . $parts[1], $parts[2], $header))
		{
			return null;
		}

		$issuer = (string) ($payload['iss'] ?? '');
		$audience = (string) ($payload['aud'] ?? '');
		$subject = (string) ($payload['sub'] ?? '');
		$email = (string) ($payload['email'] ?? '');
		$expires = (int) ($payload['exp'] ?? 0);
		$nonce = (string) ($payload['nonce'] ?? '');

		$allowedAudiences = array_filter([
			(string) getenv('EKITAPLIGIM_IOS_BUNDLE_ID'),
			'com.ekitapligim.app'
		]);

		if ($issuer !== 'https://appleid.apple.com' || $subject === '' || $expires < \XF::$time)
		{
			return null;
		}
		if ($rawNonce !== null
			&& ($rawNonce === '' || $nonce === '' || !hash_equals(hash('sha256', $rawNonce), $nonce)))
		{
			return null;
		}
		if ($audience === '' || !in_array($audience, $allowedAudiences, true))
		{
			return null;
		}

		return [
			'sub' => $subject,
			'email' => $email,
		];
	}

	protected function verifyAppleSignature(string $signedData, string $encodedSignature, array $header): bool
	{
		if (($header['alg'] ?? '') !== 'RS256')
		{
			return false;
		}

		$keyId = (string) ($header['kid'] ?? '');
		if ($keyId === '')
		{
			return false;
		}

		$key = $this->applePublicKeyForKeyId($keyId);
		if (!$key)
		{
			return false;
		}

		$signature = $this->base64UrlDecode($encodedSignature);
		if ($signature === '')
		{
			return false;
		}

		$result = openssl_verify($signedData, $signature, $key, OPENSSL_ALGO_SHA256);
		return $result === 1;
	}

	protected function applePublicKeyForKeyId(string $keyId)
	{
		$keys = $this->fetchAppleJwks();
		foreach ($keys AS $key)
		{
			if (($key['kid'] ?? '') !== $keyId || ($key['kty'] ?? '') !== 'RSA')
			{
				continue;
			}

			$modulus = $this->base64UrlDecode((string) ($key['n'] ?? ''));
			$exponent = $this->base64UrlDecode((string) ($key['e'] ?? ''));
			if ($modulus === '' || $exponent === '')
			{
				continue;
			}

			$pem = $this->rsaPublicKeyPem($modulus, $exponent);
			$publicKey = openssl_pkey_get_public($pem);
			if ($publicKey)
			{
				return $publicKey;
			}
		}

		return null;
	}

	protected function fetchAppleJwks(): array
	{
		$cachePath = $this->appleJwksCachePath();
		if ($cachePath && is_readable($cachePath) && filemtime($cachePath) > time() - 86400)
		{
			$cached = json_decode((string) file_get_contents($cachePath), true);
			if (is_array($cached['keys'] ?? null))
			{
				return $cached['keys'];
			}
		}

		$json = @file_get_contents('https://appleid.apple.com/auth/keys');
		$decoded = is_string($json) ? json_decode($json, true) : null;
		if (!is_array($decoded) || !is_array($decoded['keys'] ?? null))
		{
			\XF::logError('Mobile Apple auth could not fetch Apple JWKS.');
			return [];
		}

		if ($cachePath)
		{
			@file_put_contents($cachePath, json_encode($decoded));
		}

		return $decoded['keys'];
	}

	protected function appleJwksCachePath(): string
	{
		try
		{
			$path = \XF::app()->config('internalDataPath') . '/mobile_apple_jwks.json';
			$directory = dirname($path);
			if (!is_dir($directory))
			{
				@mkdir($directory, 0775, true);
			}
			return $path;
		}
		catch (\Throwable $e)
		{
			return '';
		}
	}

	protected function rsaPublicKeyPem(string $modulus, string $exponent): string
	{
		$sequence = $this->asn1Sequence(
			$this->asn1Integer($modulus) .
			$this->asn1Integer($exponent)
		);

		$bitString = "\x03" . $this->asn1Length(strlen($sequence) + 1) . "\x00" . $sequence;
		$algorithm = $this->asn1Sequence(
			$this->asn1ObjectIdentifier('1.2.840.113549.1.1.1') . "\x05\x00"
		);
		$subjectPublicKeyInfo = $this->asn1Sequence($algorithm . $bitString);

		return "-----BEGIN PUBLIC KEY-----\n"
			. chunk_split(base64_encode($subjectPublicKeyInfo), 64, "\n")
			. "-----END PUBLIC KEY-----\n";
	}

	protected function asn1Sequence(string $value): string
	{
		return "\x30" . $this->asn1Length(strlen($value)) . $value;
	}

	protected function asn1Integer(string $value): string
	{
		$value = ltrim($value, "\x00");
		if ($value === '')
		{
			$value = "\x00";
		}
		if ((ord($value[0]) & 0x80) !== 0)
		{
			$value = "\x00" . $value;
		}

		return "\x02" . $this->asn1Length(strlen($value)) . $value;
	}

	protected function asn1ObjectIdentifier(string $oid): string
	{
		$parts = array_map('intval', explode('.', $oid));
		$body = chr(($parts[0] * 40) + $parts[1]);
		for ($i = 2; $i < count($parts); $i++)
		{
			$body .= $this->asn1Base128($parts[$i]);
		}

		return "\x06" . $this->asn1Length(strlen($body)) . $body;
	}

	protected function asn1Base128(int $value): string
	{
		$bytes = [chr($value & 0x7f)];
		$value >>= 7;
		while ($value > 0)
		{
			array_unshift($bytes, chr(($value & 0x7f) | 0x80));
			$value >>= 7;
		}

		return implode('', $bytes);
	}

	protected function asn1Length(int $length): string
	{
		if ($length < 128)
		{
			return chr($length);
		}

		$bytes = '';
		while ($length > 0)
		{
			$bytes = chr($length & 0xff) . $bytes;
			$length >>= 8;
		}

		return chr(0x80 | strlen($bytes)) . $bytes;
	}

	protected function resolveUserFromApple(array $appleUser): ?User
	{
		$sub = (string) $appleUser['sub'];
		$email = (string) ($appleUser['email'] ?? '');

		/** @var UserConnectedAccount|null $connected */
		$connected = $this->em()->findOne('XF:UserConnectedAccount', [
			'provider' => 'apple',
			'provider_key' => $sub,
		], ['User']);
		if ($connected && $connected->User)
		{
			return $connected->User;
		}

		$user = null;
		if ($email !== '')
		{
			/** @var User|null $user */
			$user = $this->em()->findOne('XF:User', ['email' => $email], ['Profile']);
		}
		if (!$user)
		{
			$user = $this->createAppleUser($appleUser);
		}
		if (!$user)
		{
			return null;
		}

		$this->associateAppleAccount($user, $appleUser);
		return $user;
	}

	protected function createAppleUser(array $appleUser): ?User
	{
		$email = (string) ($appleUser['email'] ?? '');
		if ($email === '')
		{
			return null;
		}

		$username = $this->buildUniqueUsername(preg_replace('/@.*$/', '', $email) ?: 'Apple Üyesi');
		/** @var RegistrationService $registration */
		$registration = $this->service(RegistrationService::class);
		$registration->setFromInput([
			'username' => $username,
			'email' => $email,
			'timezone' => $this->app()->options()->guestTimeZone,
			'style_variation' => 'default',
		]);
		$registration->setNoPassword();
		$registration->skipEmailConfirmation();

		if (!$registration->validate($errors))
		{
			\XF::logError('Mobile Apple auth registration failed: ' . implode('; ', array_map('strval', $errors)));
			return null;
		}

		return $registration->save();
	}

	protected function associateAppleAccount(User $user, array $appleUser): void
	{
		$connected = $this->em()->findOne('XF:UserConnectedAccount', [
			'user_id' => $user->user_id,
			'provider' => 'apple',
		]);
		if (!$connected)
		{
			$connected = $this->em()->create('XF:UserConnectedAccount');
			$connected->user_id = $user->user_id;
			$connected->provider = 'apple';
		}

		$connected->provider_key = (string) $appleUser['sub'];
		$connected->extra_data = [
			'email' => (string) ($appleUser['email'] ?? ''),
			'source' => 'ios_mobile_api',
		];
		$connected->save();
	}

	protected function buildUniqueUsername(string $raw): string
	{
		$name = preg_replace('/[^\pL\pN _.-]+/u', '', $raw) ?: 'Apple Üyesi';
		$name = trim(preg_replace('/\s+/u', ' ', $name));
		$name = $this->app()->stringFormatter()->wholeWordTrim($name, 22, 0, '');

		/** @var UserRepository $userRepo */
		$userRepo = $this->repository(UserRepository::class);
		$candidate = $name;
		$index = 1;
		while ($userRepo->getUserByNameOrEmail($candidate))
		{
			$index++;
			$suffix = ' ' . $index;
			$candidate = $this->app()->stringFormatter()->wholeWordTrim($name, 22 - strlen($suffix), 0, '') . $suffix;
		}
		return $candidate;
	}

	protected function buildAuthPayload(User $user): array
	{
		return $this->buildMobileAuthPayload($user);
	}

	protected function base64UrlDecode(string $value): string
	{
		return base64_decode(strtr($value, '-_', '+/') . str_repeat('=', (4 - strlen($value) % 4) % 4)) ?: '';
	}
}
