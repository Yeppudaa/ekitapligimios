<?php

namespace Ekitapligim\IosApi\Service;

/**
 * Sends push notifications to iOS devices via Apple APNs HTTP/2 API with JWT authentication.
 *
 * Required XenForo options (set via Admin CP > Options):
 *   ekitapligimApnsKeyId      - The Key ID from Apple Developer portal
 *   ekitapligimApnsTeamId     - Your Apple Developer Team ID
 *   ekitapligimApnsKeyPath    - Absolute server path to the .p8 private key file
 *   ekitapligimApnsTopic      - The app bundle ID (e.g. com.ekitapligim.app)
 *   ekitapligimApnsEnvironment - "production" or "development"
 */
class ApnsPush
{
	private const APNS_PRODUCTION = 'https://api.push.apple.com';
	private const APNS_DEVELOPMENT = 'https://api.development.push.apple.com';

	/**
	 * Sends a push notification to all registered devices for a given user.
	 */
	public static function sendToUser(int $userId, array $payload): array
	{
		$summary = ['attempted' => 0, 'sent' => 0, 'failed' => 0, 'removed' => 0];
		if ($userId <= 0)
		{
			return $summary;
		}

		$db = \XF::db();
		$tokens = $db->fetchAllColumn(
			'SELECT device_token FROM xf_ios_device_tokens WHERE user_id = ?',
			[$userId]
		);

		if (empty($tokens))
		{
			return $summary;
		}

		$jwt = self::generateJwt();
		if ($jwt === null)
		{
			$summary['failed'] = count($tokens);
			return $summary;
		}

		$jsonPayload = json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
		if (!is_string($jsonPayload))
		{
			\XF::logError('APNs payload encoding failed.');
			$summary['failed'] = count($tokens);
			return $summary;
		}

		foreach ($tokens as $token)
		{
			$summary['attempted']++;
			$response = self::sendSingle($token, $jsonPayload, $jwt);
			$responseCode = (int) $response['status'];
			$reason = (string) $response['reason'];

			if ($responseCode === 200)
			{
				$summary['sent']++;
				continue;
			}

			$summary['failed']++;
			self::logFailure($responseCode, $reason, (string) $response['apns_id']);

			if (self::shouldRemoveToken($responseCode, $reason))
			{
				$db->delete('xf_ios_device_tokens', 'device_token = ?', [$token]);
				$summary['removed']++;
			}
		}

		return $summary;
	}

	public static function shouldRemoveToken(int $status, string $reason): bool
	{
		return $status === 410 || $reason === 'Unregistered' || $reason === 'BadDeviceToken';
	}

	/**
	 * Builds a standard APNs payload from alert parameters.
	 */
	public static function buildPayload(
		string $title,
		string $body,
		int $badge = 0,
		array $customData = []
	): array
	{
		$aps = [
			'alert' => [
				'title' => $title,
				'body' => $body,
			],
			'sound' => 'default',
			'content-available' => 1,
		];

		if ($badge > 0)
		{
			$aps['badge'] = $badge;
		}

		return array_merge(['aps' => $aps], $customData);
	}

	private static function sendSingle(string $deviceToken, string $jsonPayload, string $jwt): array
	{
		$options = \XF::options();
		$topic = $options->ekitapligimApnsTopic ?? 'com.ekitapligim.app';
		$environment = $options->ekitapligimApnsEnvironment ?? 'production';
		$baseUrl = $environment === 'development' ? self::APNS_DEVELOPMENT : self::APNS_PRODUCTION;

		$url = $baseUrl . '/3/device/' . $deviceToken;

		$ch = curl_init($url);
		$apnsId = '';
		curl_setopt_array($ch, [
			CURLOPT_HTTP_VERSION => CURL_HTTP_VERSION_2_0,
			CURLOPT_POST => true,
			CURLOPT_POSTFIELDS => $jsonPayload,
			CURLOPT_RETURNTRANSFER => true,
			CURLOPT_TIMEOUT => 10,
			CURLOPT_HEADERFUNCTION => static function ($curl, string $headerLine) use (&$apnsId): int
			{
				if (stripos($headerLine, 'apns-id:') === 0)
				{
					$apnsId = trim(substr($headerLine, strlen('apns-id:')));
				}
				return strlen($headerLine);
			},
			CURLOPT_HTTPHEADER => [
				'authorization: bearer ' . $jwt,
				'apns-topic: ' . $topic,
				'apns-push-type: alert',
				'apns-priority: 10',
				'content-type: application/json',
			],
		]);

		$responseBody = curl_exec($ch);
		$httpCode = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
		$reason = '';

		if (curl_errno($ch))
		{
			$reason = 'curl_' . curl_errno($ch);
			\XF::logError('APNs transport error (' . $reason . '): ' . curl_error($ch));
		}
		elseif (is_string($responseBody) && $responseBody !== '')
		{
			$decoded = json_decode($responseBody, true);
			if (is_array($decoded))
			{
				$reason = (string) ($decoded['reason'] ?? '');
			}
		}

		curl_close($ch);

		return ['status' => $httpCode, 'reason' => $reason, 'apns_id' => $apnsId];
	}

	private static function logFailure(int $status, string $reason, string $apnsId): void
	{
		$message = 'APNs delivery failed: HTTP ' . $status;
		if ($reason !== '')
		{
			$message .= ', reason=' . preg_replace('/[^A-Za-z0-9_-]/', '', $reason);
		}
		if ($apnsId !== '')
		{
			$message .= ', apns_id=' . preg_replace('/[^A-Fa-f0-9-]/', '', $apnsId);
		}
		\XF::logError($message . '.');
	}

	/**
	 * Generates a JWT for APNs authentication using the ES256 algorithm.
	 */
	private static function generateJwt(): ?string
	{
		$options = \XF::options();
		$keyId = $options->ekitapligimApnsKeyId ?? '';
		$teamId = $options->ekitapligimApnsTeamId ?? '';
		$keyPath = $options->ekitapligimApnsKeyPath ?? '';

		if ($keyId === '' || $teamId === '' || $keyPath === '' || !file_exists($keyPath))
		{
			\XF::logError('APNs configuration incomplete: keyId, teamId, or keyPath missing.');
			return null;
		}

		$keyContent = file_get_contents($keyPath);
		$privateKey = openssl_pkey_get_private($keyContent);
		if ($privateKey === false)
		{
			\XF::logError('APNs: Failed to load private key from ' . $keyPath);
			return null;
		}

		$header = self::base64UrlEncode(json_encode([
			'alg' => 'ES256',
			'kid' => $keyId,
		]));

		$claims = self::base64UrlEncode(json_encode([
			'iss' => $teamId,
			'iat' => time(),
		]));

		$signingInput = $header . '.' . $claims;
		$signature = '';
		$success = openssl_sign($signingInput, $signature, $privateKey, OPENSSL_ALGO_SHA256);

		if (!$success)
		{
			\XF::logError('APNs: Failed to sign JWT.');
			return null;
		}

		$derSignature = $signature;
		$joseSignature = self::derToJose($derSignature);

		return $signingInput . '.' . self::base64UrlEncode($joseSignature);
	}

	private static function base64UrlEncode(string $data): string
	{
		return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
	}

	/**
	 * Converts a DER-encoded ECDSA signature to the fixed-length JOSE format.
	 */
	private static function derToJose(string $der): string
	{
		$offset = 2;

		$rLength = ord($der[$offset + 1]);
		$r = substr($der, $offset + 2, $rLength);
		$offset += 2 + $rLength;

		$sLength = ord($der[$offset + 1]);
		$s = substr($der, $offset + 2, $sLength);

		$r = ltrim($r, "\x00");
		$s = ltrim($s, "\x00");

		$r = str_pad($r, 32, "\x00", STR_PAD_LEFT);
		$s = str_pad($s, 32, "\x00", STR_PAD_LEFT);

		return $r . $s;
	}
}
