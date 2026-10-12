<?php

namespace Ekitapligim\IosApi\Service;

use XF\Entity\User;

final class MobileSession
{
	private const ACCESS_LIFETIME = 3600;
	private const REFRESH_LIFETIME = 2592000;
	private const REFRESH_RETRY_GRACE = 120;
	// Reserve this past timestamp for terminal logout without a schema migration.
	private const REVOKED_EXPLICITLY = 1;

	public static function issue(User $user, string $ipAddress = '', string $userAgent = ''): array
	{
		return self::issueWithTokens($user, [
			'access_token' => self::newToken('ms_at_'),
			'refresh_token' => self::newToken('ms_rt_'),
		], $ipAddress, $userAgent);
	}

	private static function issueWithTokens(User $user, array $tokens, string $ipAddress, string $userAgent): array
	{
		self::ensureTable();
		$now = \XF::$time;

		\XF::db()->insert('xf_ekitapligim_mobile_session', [
			'user_id' => (int) $user->user_id,
			'access_token_hash' => self::hash($tokens['access_token']),
			'refresh_token_hash' => self::hash($tokens['refresh_token']),
			'created_date' => $now,
			'access_expires_date' => $now + self::ACCESS_LIFETIME,
			'refresh_expires_date' => $now + self::REFRESH_LIFETIME,
			'ip_address' => substr($ipAddress, 0, 45),
			'user_agent' => substr($userAgent, 0, 255),
		]);

		return $tokens;
	}

	public static function userIdForAccessToken(string $token): int
	{
		if (!str_starts_with($token, 'ms_at_'))
		{
			return 0;
		}

		self::ensureTable();
		return (int) \XF::db()->fetchOne(
			'SELECT user_id FROM xf_ekitapligim_mobile_session WHERE access_token_hash = ? AND revoked_date = 0 AND access_expires_date > ? LIMIT 1',
			[self::hash($token), \XF::$time]
		);
	}

	public static function rotate(string $refreshToken, string $ipAddress = '', string $userAgent = ''): ?array
	{
		if (!str_starts_with($refreshToken, 'ms_rt_'))
		{
			return null;
		}

		self::ensureTable();
		$db = \XF::db();
		$db->beginTransaction();
		try
		{
			$session = $db->fetchRow(
				'SELECT session_id, user_id, revoked_date, refresh_expires_date FROM xf_ekitapligim_mobile_session WHERE refresh_token_hash = ? FOR UPDATE',
				[self::hash($refreshToken)]
			);
			if (!$session || (int) $session['refresh_expires_date'] <= \XF::$time)
			{
				$db->commit();
				return null;
			}

			$user = \XF::em()->find('XF:User', (int) $session['user_id']);
			if (!$user || $user->is_banned || in_array($user->user_state, ['rejected', 'disabled'], true))
			{
				if (!(int) $session['revoked_date'])
				{
					$db->update('xf_ekitapligim_mobile_session', ['revoked_date' => \XF::$time], 'session_id = ?', [(int) $session['session_id']]);
				}
				$db->commit();
				return null;
			}

			$revokedDate = (int) $session['revoked_date'];
			if ($revokedDate === self::REVOKED_EXPLICITLY
				|| ($revokedDate && ($revokedDate <= \XF::$time - self::REFRESH_RETRY_GRACE || $revokedDate > \XF::$time)))
			{
				$db->commit();
				return null;
			}

			$tokens = self::rotationTokens($refreshToken);
			if ($revokedDate)
			{
				// A lost response may retry only the exact, still-active successor.
				// Explicit logout/revocation has no active successor and cannot revive it.
				$successor = $db->fetchRow(
					'SELECT user_id FROM xf_ekitapligim_mobile_session WHERE access_token_hash = ? AND refresh_token_hash = ? AND revoked_date = 0 AND access_expires_date > ? AND refresh_expires_date > ? FOR UPDATE',
					[self::hash($tokens['access_token']), self::hash($tokens['refresh_token']), \XF::$time, \XF::$time]
				);
				$db->commit();
				return $successor && (int) $successor['user_id'] === (int) $session['user_id']
					? ['user' => $user, 'tokens' => $tokens]
					: null;
			}

			$db->update('xf_ekitapligim_mobile_session', ['revoked_date' => \XF::$time], 'session_id = ?', [(int) $session['session_id']]);
			self::issueWithTokens($user, $tokens, $ipAddress, $userAgent);
			$db->commit();
			return ['user' => $user, 'tokens' => $tokens];
		}
		catch (\Throwable $e)
		{
			$db->rollback();
			throw $e;
		}
	}

	public static function revokeAccessToken(string $token): void
	{
		if (!str_starts_with($token, 'ms_at_'))
		{
			return;
		}

		self::ensureTable();
		\XF::db()->update(
			'xf_ekitapligim_mobile_session',
			// An explicit logout must also terminate a pending retry of a rotated token.
			['revoked_date' => self::REVOKED_EXPLICITLY],
			'access_token_hash = ?',
			[self::hash($token)]
		);
	}

	public static function revokeUserSessions(int $userId): void
	{
		if ($userId <= 0)
		{
			return;
		}

		self::ensureTable();
		\XF::db()->update(
			'xf_ekitapligim_mobile_session',
			['revoked_date' => \XF::$time],
			'user_id = ? AND revoked_date = 0',
			[$userId]
		);
	}

	public static function bearerToken(string $header): string
	{
		return preg_match('/^Bearer\\s+(.+)$/i', trim($header), $match) ? trim($match[1]) : '';
	}

	private static function newToken(string $prefix): string
	{
		return $prefix . rtrim(strtr(base64_encode(random_bytes(32)), '+/', '-_'), '=');
	}

	private static function rotationTokens(string $refreshToken): array
	{
		$key = (string) \XF::config('globalSalt');
		if (trim($key) === '')
		{
			throw new \RuntimeException('Mobile session refresh signing key is unavailable.');
		}

		$tokens = [];
		foreach (['access_token' => 'ms_at_', 'refresh_token' => 'ms_rt_'] AS $type => $prefix)
		{
			$bytes = hash_hmac('sha256', 'ekitapligim.mobile-session.rotation.v1.' . $type . "\0" . $refreshToken, $key, true);
			$tokens[$type] = $prefix . rtrim(strtr(base64_encode($bytes), '+/', '-_'), '=');
		}
		return $tokens;
	}

	private static function hash(string $token): string
	{
		return hash('sha256', $token);
	}

	private static function ensureTable(): void
	{
		static $created = false;
		if ($created)
		{
			return;
		}

		\XF::db()->query("\n			CREATE TABLE IF NOT EXISTS xf_ekitapligim_mobile_session (\n				session_id INT UNSIGNED NOT NULL AUTO_INCREMENT,\n				user_id INT UNSIGNED NOT NULL,\n				access_token_hash CHAR(64) NOT NULL,\n				refresh_token_hash CHAR(64) NOT NULL,\n				created_date INT UNSIGNED NOT NULL,\n				access_expires_date INT UNSIGNED NOT NULL,\n				refresh_expires_date INT UNSIGNED NOT NULL,\n				revoked_date INT UNSIGNED NOT NULL DEFAULT 0,\n				ip_address VARCHAR(45) NOT NULL DEFAULT '',\n				user_agent VARCHAR(255) NOT NULL DEFAULT '',\n				PRIMARY KEY (session_id),\n				UNIQUE KEY access_token_hash (access_token_hash),\n				UNIQUE KEY refresh_token_hash (refresh_token_hash),\n				KEY user_active (user_id, revoked_date)\n			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4\n		");
		$created = true;
	}
}
