<?php

namespace Ekitapligim\MobileApi\Service;

class IosEntitlement
{
	public static function hasActiveEntitlement(\XF\Entity\User $user): bool
	{
		return self::expirationTime($user) > \XF::$time || self::hasLifetimeEntitlement($user);
	}

	public static function expirationTime(\XF\Entity\User $user): int
	{
		if (!$user->user_id)
		{
			return 0;
		}

		try
		{
			return (int) \XF::db()->fetchOne(
				"SELECT MAX(expires_date)
				FROM xf_ekitapligim_mobile_appstore_entitlement
				WHERE user_id = ?
					AND active = 1
					AND (expires_date = 0 OR expires_date > ?)",
				[(int) $user->user_id, \XF::$time]
			);
		}
		catch (\Throwable $e)
		{
			return 0;
		}
	}

	public static function hasLifetimeEntitlement(\XF\Entity\User $user): bool
	{
		if (!$user->user_id)
		{
			return false;
		}

		try
		{
			return (bool) \XF::db()->fetchOne(
				"SELECT 1
				FROM xf_ekitapligim_mobile_appstore_entitlement
				WHERE user_id = ?
					AND active = 1
					AND expires_date = 0
				LIMIT 1",
				[(int) $user->user_id]
			);
		}
		catch (\Throwable $e)
		{
			return false;
		}
	}
}
