<?php

namespace Ekitapligim\MobileApi\Api\Controller;

class AppStoreNotifications extends AppStoreVerify
{
	public function actionPost()
	{
		$this->assertMobileWriteScope();

		$signedPayload = trim($this->filter('signedPayload', 'str'));
		if ($signedPayload === '')
		{
			$signedPayload = trim($this->filter('signed_payload', 'str'));
		}
		if ($signedPayload === '')
		{
			return $this->apiError('signedPayload is required.', 'invalid_input');
		}

		try
		{
			$notification = $this->decodeAndVerifyJws($signedPayload)['payload'];
			$data = is_array($notification['data'] ?? null) ? $notification['data'] : [];
			$transaction = [];

			if (!empty($data['signedTransactionInfo']))
			{
				$transaction = $this->decodeAndVerifyJws((string) $data['signedTransactionInfo'])['payload'];
			}

			$this->validateNotificationPayload($data, $transaction);

			$db = \XF::db();
			$db->beginTransaction();
			try
			{
				$this->recordNotification($notification, $transaction, $signedPayload);
				if ($transaction)
				{
					$this->updateEntitlementFromNotification($transaction, $signedPayload);
				}
				$db->commit();
			}
			catch (\Throwable $e)
			{
				$db->rollback();
				throw $e;
			}
		}
		catch (\Throwable $e)
		{
			\XF::logException($e, false, 'MobileApi App Store notification verification failed: ');
			return $this->apiError('Notification could not be verified.', 'notification_verification_failed');
		}

		return $this->apiResult([
			'success' => true,
			'status' => 'verified_received'
		]);
	}

	protected function validateNotificationPayload(array $data, array $transaction): void
	{
		$expectedBundleId = (string) (getenv('EKITAPLIGIM_IOS_BUNDLE_ID') ?: 'com.ekitapligim.app');
		$dataBundleId = (string) ($data['bundleId'] ?? '');
		$dataEnvironment = (string) ($data['environment'] ?? '');

		if ($dataBundleId !== '' && $dataBundleId !== $expectedBundleId)
		{
			throw new \RuntimeException('Notification bundle does not match this app.');
		}
		if ($dataEnvironment !== '' && !$this->isAllowedEnvironment($dataEnvironment))
		{
			throw new \RuntimeException('Notification environment is not allowed.');
		}
		if (!$transaction)
		{
			return;
		}

		$transactionBundleId = (string) ($transaction['bundleId'] ?? '');
		$productId = (string) ($transaction['productId'] ?? '');
		$environment = (string) ($transaction['environment'] ?? '');
		$transactionId = (string) ($transaction['transactionId'] ?? '');
		$originalTransactionId = (string) ($transaction['originalTransactionId'] ?? '');

		if ($transactionBundleId !== $expectedBundleId || ($dataBundleId !== '' && $transactionBundleId !== $dataBundleId))
		{
			throw new \RuntimeException('Notification transaction bundle mismatch.');
		}
		if (!$this->isAllowedProductId($productId))
		{
			throw new \RuntimeException('Notification product is not allowed.');
		}
		if (!$this->isAllowedEnvironment($environment) || ($dataEnvironment !== '' && $environment !== $dataEnvironment))
		{
			throw new \RuntimeException('Notification transaction environment mismatch.');
		}
		if ($transactionId === '' || $originalTransactionId === '')
		{
			throw new \RuntimeException('Notification transaction identifiers are missing.');
		}
	}

	protected function updateEntitlementFromNotification(array $transaction, string $signedPayload): void
	{
		$this->ensureEntitlementTable();
		$originalTransactionId = (string) $transaction['originalTransactionId'];
		$transactionId = (string) $transaction['transactionId'];
		$expiresDate = (int) ($transaction['expiresDate'] ?? 0);
		$revocationDate = (int) ($transaction['revocationDate'] ?? 0);
		$isActive = $revocationDate <= 0 && ($expiresDate <= 0 || $expiresDate > (\XF::$time * 1000));
		$entitlementId = (int) \XF::db()->fetchOne(
			"SELECT entitlement_id
			FROM xf_ekitapligim_mobile_appstore_entitlement
			WHERE transaction_id = ? OR original_transaction_id = ?
			ORDER BY (transaction_id = ?) DESC, entitlement_id DESC
			LIMIT 1",
			[$transactionId, $originalTransactionId, $transactionId]
		);
		if (!$entitlementId)
		{
			return;
		}

		\XF::db()->query(
			"UPDATE xf_ekitapligim_mobile_appstore_entitlement
			SET product_id = ?,
				transaction_id = ?,
				environment = ?,
				expires_date = ?,
				active = ?,
				signed_transaction_hash = ?,
				last_verified = ?
			WHERE entitlement_id = ?",
			[
				(string) $transaction['productId'],
				$transactionId,
				(string) $transaction['environment'],
				(int) floor($expiresDate / 1000),
				$isActive ? 1 : 0,
				hash('sha256', $signedPayload),
				\XF::$time,
				$entitlementId
			]
		);
	}

	protected function recordNotification(array $notification, array $transaction, string $signedPayload): void
	{
		$this->ensureNotificationTable();
		\XF::db()->query(
			"INSERT INTO xf_ekitapligim_mobile_appstore_notification
				(notification_uuid, notification_type, subtype, environment, original_transaction_id, transaction_id, signed_payload_hash, received_at)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?)
			ON DUPLICATE KEY UPDATE
				notification_type = VALUES(notification_type),
				subtype = VALUES(subtype),
				environment = VALUES(environment),
				original_transaction_id = VALUES(original_transaction_id),
				transaction_id = VALUES(transaction_id),
				signed_payload_hash = VALUES(signed_payload_hash),
				received_at = VALUES(received_at)",
			[
				(string) ($notification['notificationUUID'] ?? hash('sha256', $signedPayload)),
				(string) ($notification['notificationType'] ?? ''),
				(string) ($notification['subtype'] ?? ''),
				(string) ($notification['data']['environment'] ?? ($transaction['environment'] ?? '')),
				(string) ($transaction['originalTransactionId'] ?? ''),
				(string) ($transaction['transactionId'] ?? ''),
				hash('sha256', $signedPayload),
				\XF::$time
			]
		);
	}

	protected function ensureNotificationTable(): void
	{
		\XF::db()->query("
			CREATE TABLE IF NOT EXISTS xf_ekitapligim_mobile_appstore_notification (
				notification_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
				notification_uuid VARBINARY(100) NOT NULL,
				notification_type VARBINARY(60) NOT NULL DEFAULT '',
				subtype VARBINARY(60) NOT NULL DEFAULT '',
				environment VARBINARY(20) NOT NULL DEFAULT '',
				original_transaction_id VARBINARY(100) NOT NULL DEFAULT '',
				transaction_id VARBINARY(100) NOT NULL DEFAULT '',
				signed_payload_hash VARBINARY(64) NOT NULL,
				received_at INT UNSIGNED NOT NULL DEFAULT 0,
				PRIMARY KEY (notification_id),
				UNIQUE KEY notification_uuid (notification_uuid),
				KEY original_transaction_id (original_transaction_id),
				KEY transaction_id (transaction_id)
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
		");
	}
}
