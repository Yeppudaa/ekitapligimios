<?php

namespace Ekitapligim\IosApi\Service;

use XF\Service\User\UserGroupChangeService;

class IosMembershipSynchronizer
{
	public const TABLE = 'xf_ekitapligim_mobile_appstore_entitlement';

	public static function premiumGroupId(): int
	{
		return (int) (\XF::options()->ekGooglePlayPremiumGroupId ?? 0);
	}

	public static function syncEntitlement(int $entitlementId): bool
	{
		$userId = (int) \XF::db()->fetchOne('SELECT user_id FROM ' . self::TABLE . ' WHERE entitlement_id = ?', [$entitlementId]);
		// Early notifications have no owner yet. Never create guest group changes.
		if ($userId <= 0) { return true; }
		$lockName = 'ek_ios_membership_' . $userId;
		if ((int) \XF::db()->fetchOne('SELECT GET_LOCK(?, 5)', [$lockName]) !== 1) { return false; }
		try { return self::syncLockedEntitlement($entitlementId); }
		finally { \XF::db()->fetchOne('SELECT RELEASE_LOCK(?)', [$lockName]); }
	}

	private static function syncLockedEntitlement(int $entitlementId): bool
	{
		$row = \XF::db()->fetchRow(
			'SELECT entitlement_id, user_id, original_transaction_id, expires_date, active FROM ' . self::TABLE . ' WHERE entitlement_id = ?',
			$entitlementId
		);
		if (!$row)
		{
			return false;
		}

		$isActive = !empty($row['active'])
			&& ((int) $row['expires_date'] === 0 || (int) $row['expires_date'] > \XF::$time);
		$changeKey = self::changeKey($entitlementId);
		$owner = (int) \XF::db()->fetchOne('SELECT user_id FROM ' . self::TABLE . '
			WHERE original_transaction_id = ? AND user_id > 0 ORDER BY entitlement_id ASC LIMIT 1', [$row['original_transaction_id']]);
		$isActive = $isActive && $owner === (int) $row['user_id'];

		try
		{
			if (!\XF::em()->find('XF:User', (int) $row['user_id'])) { return true; }
			/** @var UserGroupChangeService $service */
			$service = \XF::service(UserGroupChangeService::class);
			if (!$isActive)
			{
				return (bool) $service->removeUserGroupChange((int) $row['user_id'], $changeKey);
			}

			$groupId = self::premiumGroupId();
			if ($groupId <= 0 || !\XF::em()->find('XF:UserGroup', $groupId))
			{
				return false;
			}

			return (bool) $service->addUserGroupChange((int) $row['user_id'], $changeKey, [$groupId]);
		}
		catch (\Throwable $e)
		{
			\XF::logError('IosApi App Store group sync failed; retry required.');
			return false;
		}
	}

	public static function syncUser(int $userId): bool
	{
		if ($userId <= 0)
		{
			return false;
		}

		$ids = \XF::db()->fetchAllColumn(
			'SELECT entitlement_id FROM ' . self::TABLE . ' WHERE user_id = ?',
			$userId
		);
		if (!$ids)
		{
			return true;
		}

		$success = true;
		foreach ($ids AS $entitlementId)
		{
			$success = self::syncEntitlement((int) $entitlementId) && $success;
		}

		return $success;
	}

	public static function syncAll(): void
	{
		try
		{
			$ids = \XF::db()->fetchAllColumn('SELECT entitlement_id FROM ' . self::TABLE);
		}
		catch (\Throwable $e)
		{
			return;
		}

		foreach ($ids AS $entitlementId)
		{
			if (!self::syncEntitlement((int) $entitlementId))
			{
				\XF::logError('IosApi App Store reconciliation needs retry.');
			}
		}
	}

	public static function isGroupSynced(int $entitlementId): bool
	{
		return (bool) \XF::db()->fetchOne(
			'SELECT 1 FROM xf_user_group_change WHERE change_key = ? LIMIT 1',
			self::changeKey($entitlementId)
		);
	}

	protected static function changeKey(int $entitlementId): string
	{
		return 'appStoreEntitlement-' . $entitlementId;
	}
}
