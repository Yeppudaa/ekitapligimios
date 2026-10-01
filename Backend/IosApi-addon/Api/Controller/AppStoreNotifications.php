<?php

namespace Ekitapligim\IosApi\Api\Controller;

use Ekitapligim\IosApi\Service\AppStoreEntitlementPolicy;
use Ekitapligim\IosApi\Service\AppStoreTransactionStore;
use Ekitapligim\IosApi\Service\IosMembershipSynchronizer;

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
			$data = is_array($notification['data'] ?? null) ? $notification['data']
				: (is_array($notification['summary'] ?? null) ? $notification['summary'] : []);
			$transaction = [];
			$renewalInfo = [];

			if (!empty($data['signedTransactionInfo']))
			{
				$transaction = $this->decodeAndVerifyJws((string) $data['signedTransactionInfo'])['payload'];
			}
			if (!empty($data['signedRenewalInfo']))
			{
				$renewalInfo = $this->decodeAndVerifyJws((string) $data['signedRenewalInfo'])['payload'];
			}

			$this->validateNotificationPayload($data, $transaction, $renewalInfo);

		}
		catch (\Throwable $e)
		{
			return $this->apiError('Notification could not be verified.', 'notification_verification_failed');
		}
		try
		{
			// DDL must never occur inside a transaction: MySQL implicitly commits it.
			AppStoreTransactionStore::ensureTables();
			$this->ensureNotificationTable();
			if ($transaction)
			{
				$record = AppStoreTransactionStore::record(0, $transaction, $renewalInfo, hash('sha256', $signedPayload));
				if ((int) $record['user_id'] > 0 && !IosMembershipSynchronizer::syncUser((int) $record['user_id']))
				{
					throw new \RuntimeException('Premium permission synchronization needs retry.');
				}
			}
			$this->recordNotification($notification, $transaction, $signedPayload);
		}
		catch (\Throwable $e)
		{
			// Apple retries 5xx. A 400 on a database outage permanently loses the event.
			return $this->apiError('Notification storage is temporarily unavailable.', 'notification_storage_unavailable', null, 503);
		}

		return $this->apiResult([
			'success' => true,
			'status' => 'verified_received'
		]);
	}

	protected function validateNotificationPayload(array $data, array $transaction, array $renewalInfo): void
	{
		$expectedBundleId = (string) (getenv('EKITAPLIGIM_IOS_BUNDLE_ID') ?: 'com.ekitapligim.app');
		$dataBundleId = (string) ($data['bundleId'] ?? '');
		$dataEnvironment = (string) ($data['environment'] ?? '');

		if ($dataBundleId !== $expectedBundleId)
		{
			throw new \RuntimeException('Notification bundle does not match this app.');
		}
		if (!$this->isAllowedEnvironment($dataEnvironment))
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
		if (!AppStoreEntitlementPolicy::hasValidProductType($transaction))
		{
			throw new \RuntimeException('Notification transaction type mismatch.');
		}
		if (!$this->isAllowedEnvironment($environment) || ($dataEnvironment !== '' && $environment !== $dataEnvironment))
		{
			throw new \RuntimeException('Notification transaction environment mismatch.');
		}
		if ($transactionId === '' || $originalTransactionId === '')
		{
			throw new \RuntimeException('Notification transaction identifiers are missing.');
		}
		if ($renewalInfo)
		{
			$renewalOriginalId = (string) ($renewalInfo['originalTransactionId'] ?? '');
			$renewalProductId = (string) ($renewalInfo['autoRenewProductId'] ?? '');
			$renewalEnvironment = (string) ($renewalInfo['environment'] ?? '');
			if ($renewalOriginalId !== $originalTransactionId
				|| ($renewalProductId !== '' && !$this->isAllowedProductId($renewalProductId))
				|| strcasecmp($renewalEnvironment, $environment) !== 0)
			{
				throw new \RuntimeException('Notification renewal information mismatch.');
			}
		}
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

