<?php

namespace Ekitapligim\IosApi\Service;

use Ekitapligim\MobileApi\Service\MembershipDisplay;

/** App Store product rules shared by verification, notifications and group sync. */
final class AppStoreProducts
{
	/** One-time VIP Premium (non-consumable): Premium plus the VIP supporter group. */
	public const VIP = 'com.ekitapligim.app.premium.vip';
	public const VIP_CHAT_CATEGORY = 9302;

	public static function vipGroupId(): int
	{
		return class_exists(MembershipDisplay::class) ? MembershipDisplay::vipGroupId() : 0;
	}

	public static function premiumGroupId(): int
	{
		return IosMembershipSynchronizer::premiumGroupId();
	}

	/** Group IDs granted by a verified product; empty means "not configured, retry later". */
	public static function groupIdsForProduct(string $productId): array
	{
		$premiumId = self::premiumGroupId();
		if ($premiumId <= 0 || !\XF::em()->find('XF:UserGroup', $premiumId))
		{
			return [];
		}
		if ($productId !== self::VIP)
		{
			return [$premiumId];
		}
		$vipId = self::vipGroupId();
		if ($vipId <= 0 || $vipId === $premiumId || !\XF::em()->find('XF:UserGroup', $vipId))
		{
			return [];
		}
		return [$premiumId, $vipId];
	}

	/** The app may sell VIP only when both groups can be granted. */
	public static function vipReady(): bool
	{
		return count(self::groupIdsForProduct(self::VIP)) === 2;
	}

	public static function userIsVip(?\XF\Entity\User $user): bool
	{
		return $user && class_exists(MembershipDisplay::class) && MembershipDisplay::isVip($user);
	}
}
