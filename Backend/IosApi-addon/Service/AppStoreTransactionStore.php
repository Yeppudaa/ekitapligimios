<?php

namespace Ekitapligim\IosApi\Service;

/** Persists filtered verified payloads plus a separate user-to-Apple purchase UUID map; never raw JWS. */
final class AppStoreTransactionStore
{
	public static function ensureTables(): void
	{
		$db = \XF::db();
		$db->query("CREATE TABLE IF NOT EXISTS xf_ekitapligim_mobile_appstore_entitlement (
			entitlement_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
			user_id INT UNSIGNED NOT NULL,
			product_id VARBINARY(100) NOT NULL,
			transaction_id VARBINARY(100) NOT NULL,
			original_transaction_id VARBINARY(100) NOT NULL,
			environment VARBINARY(20) NOT NULL DEFAULT '',
			expires_date INT UNSIGNED NOT NULL DEFAULT 0,
			active TINYINT UNSIGNED NOT NULL DEFAULT 0,
			signed_transaction_hash VARBINARY(64) NOT NULL,
			last_verified INT UNSIGNED NOT NULL DEFAULT 0,
			PRIMARY KEY (entitlement_id), UNIQUE KEY transaction_id (transaction_id),
			KEY user_active (user_id, active, expires_date), KEY original_transaction_id (original_transaction_id)
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
		$db->query("CREATE TABLE IF NOT EXISTS xf_ekitapligim_ios_appstore_state (
			transaction_id VARBINARY(100) NOT NULL PRIMARY KEY,
			transaction_state MEDIUMBLOB NOT NULL,
			renewal_state MEDIUMBLOB NOT NULL
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
		$db->query("CREATE TABLE IF NOT EXISTS xf_ekitapligim_ios_appstore_account (
			user_id INT UNSIGNED NOT NULL PRIMARY KEY,
			app_account_token VARBINARY(36) NOT NULL,
			UNIQUE KEY app_account_token (app_account_token)
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	}

	/** Stable random UUID tied to XenForo user ID, independent of username changes. */
	public static function accountToken(int $userId): string
	{
		if ($userId <= 0) { throw new \DomainException('purchase_account_required'); }
		$bytes = random_bytes(16);
		$bytes[6] = chr((ord($bytes[6]) & 0x0f) | 0x40);
		$bytes[8] = chr((ord($bytes[8]) & 0x3f) | 0x80);
		$hex = bin2hex($bytes);
		$token = substr($hex, 0, 8) . '-' . substr($hex, 8, 4) . '-' . substr($hex, 12, 4)
			. '-' . substr($hex, 16, 4) . '-' . substr($hex, 20);
		\XF::db()->query("INSERT INTO xf_ekitapligim_ios_appstore_account (user_id, app_account_token)
			VALUES (?, ?) ON DUPLICATE KEY UPDATE user_id = VALUES(user_id)", [$userId, $token]);
		return (string) \XF::db()->fetchOne('SELECT app_account_token FROM xf_ekitapligim_ios_appstore_account WHERE user_id = ?', [$userId]);
	}

	/** Caller has already verified signatures, bundle, environment, products and renewal binding. */
	public static function record(int $userId, array $transaction, array $renewalInfo, string $signedHash): array
	{
		$db = \XF::db();
		$accountToken = strtolower((string) ($transaction['appAccountToken'] ?? ''));
		if ($accountToken !== '')
		{
			$tokenOwner = (int) $db->fetchOne('SELECT user_id FROM xf_ekitapligim_ios_appstore_account WHERE app_account_token = ?', [$accountToken]);
			if ($tokenOwner <= 0) { throw new \DomainException('app_account_token_unknown'); }
			if ($userId > 0 && $tokenOwner !== $userId) { throw new \DomainException('original_transaction_already_linked'); }
			$userId = $tokenOwner;
		}
		$originalId = (string) $transaction['originalTransactionId'];
		$transactionId = (string) $transaction['transactionId'];
		$lockName = 'ekitapligim_appstore_' . sha1($originalId);
		if ((int) $db->fetchOne('SELECT GET_LOCK(?, 5)', [$lockName]) !== 1)
		{
			throw new \RuntimeException('App Store storage busy.');
		}
		try
		{
			$db->beginTransaction();
			try
			{
				$owner = (int) $db->fetchOne("SELECT user_id FROM xf_ekitapligim_mobile_appstore_entitlement
					WHERE original_transaction_id = ? AND user_id > 0 ORDER BY entitlement_id ASC LIMIT 1", [$originalId]);
				if ($userId > 0 && $owner > 0 && $userId !== $owner)
				{
					throw new \DomainException('original_transaction_already_linked');
				}
				$owner = $owner ?: $userId;
				$existing = $db->fetchRow("SELECT * FROM xf_ekitapligim_mobile_appstore_entitlement
					WHERE transaction_id = ?", [$transactionId]);
				if ($existing && ((string) $existing['original_transaction_id'] !== $originalId
					|| (string) $existing['product_id'] !== (string) $transaction['productId']
					|| (string) $existing['environment'] !== (string) $transaction['environment']))
				{
					throw new \DomainException('transaction_identity_mismatch');
				}
				$stored = $db->fetchRow("SELECT * FROM xf_ekitapligim_ios_appstore_state WHERE transaction_id = ?", [$transactionId]);
				$previous = $stored ? json_decode($stored['transaction_state'], true, 512, JSON_THROW_ON_ERROR) : [];
				$previousRenewal = $stored ? json_decode($stored['renewal_state'], true, 512, JSON_THROW_ON_ERROR) : [];
				// A legacy record has no signed-date evidence. Never resurrect a legacy
				// inactive record using a receipt older than its last server observation.
				if (!$stored && $existing && !(int) $existing['active']
					&& (int) $transaction['signedDate'] < (int) $existing['last_verified'] * 1000)
				{
					$db->commit();
					return $existing;
				}
				[$effective, $renewal] = self::merge($previous, $previousRenewal, $transaction, $renewalInfo);
				$active = AppStoreEntitlementPolicy::isActive($effective, $renewal, \XF::$time * 1000);
				$expires = AppStoreEntitlementPolicy::effectiveExpirationSeconds($effective, $renewal);
				$db->query("INSERT INTO xf_ekitapligim_ios_appstore_state (transaction_id, transaction_state, renewal_state)
					VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE transaction_state = VALUES(transaction_state), renewal_state = VALUES(renewal_state)",
					[$transactionId, json_encode($effective, JSON_THROW_ON_ERROR), json_encode($renewal, JSON_THROW_ON_ERROR)]);
				$db->query("INSERT INTO xf_ekitapligim_mobile_appstore_entitlement
					(user_id, product_id, transaction_id, original_transaction_id, environment, expires_date, active, signed_transaction_hash, last_verified)
					VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE
					user_id = VALUES(user_id), expires_date = VALUES(expires_date), active = VALUES(active),
					signed_transaction_hash = VALUES(signed_transaction_hash), last_verified = VALUES(last_verified)",
					[$owner, $effective['productId'], $transactionId, $originalId, $effective['environment'], $expires, $active ? 1 : 0, $signedHash, \XF::$time]);
				// Notifications can precede the first authenticated verification. Keep
				// them durably under user 0, then bind the whole chain atomically.
				if ($owner > 0)
				{
					$db->query("UPDATE xf_ekitapligim_mobile_appstore_entitlement SET user_id = ?
						WHERE original_transaction_id = ? AND user_id = 0", [$owner, $originalId]);
				}
				$db->commit();
				return ['active' => $active, 'expires_date' => $expires, 'revoked' => !empty($effective['revocationDate']), 'user_id' => $owner];
			}
			catch (\Throwable $e)
			{
				$db->rollback();
				throw $e;
			}
		}
		finally
		{
			$db->fetchOne('SELECT RELEASE_LOCK(?)', [$lockName]);
		}
	}

	public static function merge(array $previous, array $previousRenewal, array $transaction, array $renewal): array
	{
		// Equal timestamps retain the stored state; an explicit revocation wins a tie.
		if (!$previous || (int) $transaction['signedDate'] > (int) $previous['signedDate']
			|| ((int) $transaction['signedDate'] === (int) $previous['signedDate'] && !empty($transaction['revocationDate'])))
		{
			$previous = array_intersect_key($transaction, array_flip([
				'transactionId', 'originalTransactionId', 'productId', 'environment', 'type',
				'purchaseDate', 'expiresDate', 'revocationDate', 'isUpgraded', 'signedDate'
			]));
		}
		if ($renewal && (!$previousRenewal || (int) $renewal['signedDate'] > (int) $previousRenewal['signedDate']))
		{
			$previousRenewal = array_intersect_key($renewal, array_flip(['signedDate', 'gracePeriodExpiresDate']));
		}
		return [$previous, $previousRenewal];
	}
}
