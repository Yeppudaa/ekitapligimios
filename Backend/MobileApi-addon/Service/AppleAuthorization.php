<?php

namespace Ekitapligim\MobileApi\Service;

final class AppleAuthorization
{
	private const TOKEN_URL = 'https://appleid.apple.com/auth/token';
	private const REVOKE_URL = 'https://appleid.apple.com/auth/revoke';

	public static function exchangeCode(string $authorizationCode): ?array
	{
		$config = self::configuration();
		if (!$config)
		{
			\XF::logError('Mobile Apple authorization is not configured.');
			return null;
		}

		try
		{
			$response = \XF::app()->http()->client()->post(self::TOKEN_URL, [
				'connect_timeout' => 10,
				'timeout' => 20,
				'form_params' => [
					'client_id' => $config['client_id'],
					'client_secret' => $config['client_secret'],
					'code' => $authorizationCode,
					'grant_type' => 'authorization_code',
				],
			]);
			$payload = json_decode((string) $response->getBody(), true);
			$refreshToken = is_array($payload) ? trim((string) ($payload['refresh_token'] ?? '')) : '';
			$identityToken = is_array($payload) ? trim((string) ($payload['id_token'] ?? '')) : '';
			if ($response->getStatusCode() !== 200 || $refreshToken === '' || $identityToken === '')
			{
				\XF::logError('Mobile Apple authorization code exchange failed with status ' . $response->getStatusCode() . '.');
				return null;
			}

			return ['refresh_token' => $refreshToken, 'identity_token' => $identityToken];
		}
		catch (\Throwable $e)
		{
			\XF::logException($e, false, 'Mobile Apple authorization code exchange failed: ');
			return null;
		}
	}

	public static function storeForUser(int $userId, string $refreshToken): bool
	{
		$config = self::configuration();
		if (!$config)
		{
			return false;
		}
		try
		{
			self::storeRefreshToken($userId, $refreshToken, $config['encryption_key']);
			return true;
		}
		catch (\Throwable $e)
		{
			\XF::logException($e, false, 'Mobile Apple refresh token storage failed: ');
			return false;
		}
	}

	public static function hasAuthorization(int $userId): bool
	{
		self::ensureTable();
		return (bool) \XF::db()->fetchOne(
			'SELECT 1 FROM xf_ekitapligim_mobile_apple_authorization WHERE user_id = ? AND revoked_date = 0',
			[$userId]
		);
	}

	public static function revokeForUser(int $userId): bool
	{
		self::ensureTable();
		$row = \XF::db()->fetchRow(
			'SELECT refresh_token_ciphertext, encryption_iv, encryption_tag
			 FROM xf_ekitapligim_mobile_apple_authorization WHERE user_id = ? AND revoked_date = 0',
			[$userId]
		);
		if (!$row)
		{
			return true;
		}

		$config = self::configuration();
		if (!$config)
		{
			\XF::logError('Mobile Apple revocation is not configured for user ID ' . $userId . '.');
			return false;
		}

		$refreshToken = openssl_decrypt(
			(string) $row['refresh_token_ciphertext'],
			'aes-256-gcm',
			$config['encryption_key'],
			OPENSSL_RAW_DATA,
			(string) $row['encryption_iv'],
			(string) $row['encryption_tag']
		);
		if (!is_string($refreshToken) || $refreshToken === '')
		{
			\XF::logError('Mobile Apple refresh token could not be decrypted for user ID ' . $userId . '.');
			return false;
		}

		try
		{
			$response = \XF::app()->http()->client()->post(self::REVOKE_URL, [
				'connect_timeout' => 10,
				'timeout' => 20,
				'form_params' => [
					'client_id' => $config['client_id'],
					'client_secret' => $config['client_secret'],
					'token' => $refreshToken,
					'token_type_hint' => 'refresh_token',
				],
			]);
			if ($response->getStatusCode() !== 200)
			{
				\XF::logError('Mobile Apple token revocation failed with status ' . $response->getStatusCode() . ' for user ID ' . $userId . '.');
				return false;
			}

			\XF::db()->update('xf_ekitapligim_mobile_apple_authorization', [
				'refresh_token_ciphertext' => '',
				'encryption_iv' => '',
				'encryption_tag' => '',
				'revoked_date' => \XF::$time,
			], 'user_id = ?', [$userId]);
			return true;
		}
		catch (\Throwable $e)
		{
			\XF::logException($e, false, 'Mobile Apple token revocation failed: ');
			return false;
		}
	}

	private static function storeRefreshToken(int $userId, string $refreshToken, string $key): void
	{
		self::ensureTable();
		$iv = random_bytes(12);
		$tag = '';
		$ciphertext = openssl_encrypt($refreshToken, 'aes-256-gcm', $key, OPENSSL_RAW_DATA, $iv, $tag);
		if (!is_string($ciphertext) || $ciphertext === '' || $tag === '')
		{
			throw new \RuntimeException('Apple refresh token encryption failed.');
		}

		\XF::db()->query(
			'INSERT INTO xf_ekitapligim_mobile_apple_authorization
			 (user_id, refresh_token_ciphertext, encryption_iv, encryption_tag, updated_date, revoked_date)
			 VALUES (?, ?, ?, ?, ?, 0)
			 ON DUPLICATE KEY UPDATE refresh_token_ciphertext = VALUES(refresh_token_ciphertext),
			 encryption_iv = VALUES(encryption_iv), encryption_tag = VALUES(encryption_tag),
			 updated_date = VALUES(updated_date), revoked_date = 0',
			[$userId, $ciphertext, $iv, $tag, \XF::$time]
		);
	}

	private static function configuration(): ?array
	{
		$clientId = trim((string) getenv('EKITAPLIGIM_IOS_BUNDLE_ID'));
		$clientSecret = trim((string) getenv('EKITAPLIGIM_APPLE_CLIENT_SECRET'));
		$key = base64_decode(trim((string) getenv('EKITAPLIGIM_APPLE_TOKEN_ENCRYPTION_KEY')), true);
		if ($clientId === '' || $clientSecret === '' || !is_string($key) || strlen($key) !== 32)
		{
			return null;
		}
		return ['client_id' => $clientId, 'client_secret' => $clientSecret, 'encryption_key' => $key];
	}

	private static function ensureTable(): void
	{
		\XF::db()->query("
			CREATE TABLE IF NOT EXISTS xf_ekitapligim_mobile_apple_authorization (
				user_id INT UNSIGNED NOT NULL,
				refresh_token_ciphertext BLOB NOT NULL,
				encryption_iv VARBINARY(16) NOT NULL,
				encryption_tag VARBINARY(16) NOT NULL,
				updated_date INT UNSIGNED NOT NULL DEFAULT 0,
				revoked_date INT UNSIGNED NOT NULL DEFAULT 0,
				PRIMARY KEY (user_id),
				KEY revoked_date (revoked_date)
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
		");
	}
}
