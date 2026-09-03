<?php

namespace Ekitapligim\IosApi\Api\Controller;

class AuthGoogle extends \Ekitapligim\MobileApi\Api\Controller\AuthGoogle
{
	private const WEB_CLIENT_IDS = [
		'507822335039-3871s4mggrgpd3kusmm2ihlhre0j2r82.apps.googleusercontent.com',
		'258534406055-v8lmgd6moijakv1kcurgit788uk5v2el.apps.googleusercontent.com',
		'258534406055-trcoiet648ohvijagtpli1h1556i2cjq.apps.googleusercontent.com',
	];

	protected function verifyGoogleToken(string $idToken): ?array
	{
		$url = 'https://oauth2.googleapis.com/tokeninfo?id_token=' . rawurlencode($idToken);
		$client = $this->app()->http()->client();

		try
		{
			$response = $client->get($url, [
				'timeout' => 10,
				'http_errors' => false,
			]);
			$status = $response->getStatusCode();
			if ($status >= 400 && $status < 500)
			{
				return null;
			}
			if ($status !== 200)
			{
				throw new \RuntimeException('Google token verification returned HTTP ' . $status);
			}

			$data = json_decode((string) $response->getBody(), true);
			if (!is_array($data))
			{
				return null;
			}

			$aud = (string) ($data['aud'] ?? '');
			$sub = (string) ($data['sub'] ?? '');
			$email = (string) ($data['email'] ?? '');
			$emailVerified = $data['email_verified'] ?? '';
			$expires = (int) ($data['exp'] ?? 0);

			if (!in_array($aud, self::WEB_CLIENT_IDS, true)
				|| $sub === ''
				|| $email === ''
				|| $expires + 120 < \XF::$time)
			{
				return null;
			}

			$verified = $emailVerified === true
				|| $emailVerified === 1
				|| in_array(strtolower((string) $emailVerified), ['1', 'true'], true);
			if (!$verified)
			{
				return null;
			}

			return [
				'sub' => $sub,
				'email' => $email,
				'name' => (string) ($data['name'] ?? ''),
				'picture' => (string) ($data['picture'] ?? ''),
			];
		}
		catch (\Throwable $e)
		{
			\XF::logException($e, false, 'IosApi Google auth verification failed: ');
			return null;
		}
	}
}
