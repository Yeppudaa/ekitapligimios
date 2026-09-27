<?php

namespace Ekitapligim\IosApi\Service;

final class AppStoreEntitlementPolicy
{
	public static function isActive(array $transaction, array $renewalInfo, int $nowMilliseconds): bool
	{
		$revocationDate = (int) ($transaction['revocationDate'] ?? 0);
		if ($revocationDate > 0)
		{
			return false;
		}

		$expiresDate = (int) ($transaction['expiresDate'] ?? 0);
		$gracePeriodExpiresDate = (int) ($renewalInfo['gracePeriodExpiresDate'] ?? 0);
		if (self::isLifetimeProduct($transaction))
		{
			return true;
		}
		if (self::nonRenewingMonths($transaction) > 0)
		{
			return self::effectiveExpirationSeconds($transaction, $renewalInfo) * 1000 > $nowMilliseconds;
		}
		return $expiresDate > $nowMilliseconds || $gracePeriodExpiresDate > $nowMilliseconds;
	}

	public static function effectiveExpirationSeconds(array $transaction, array $renewalInfo): int
	{
		if (self::isLifetimeProduct($transaction))
		{
			return 0;
		}
		$months = self::nonRenewingMonths($transaction);
		if ($months > 0)
		{
			$purchaseDate = (int) ($transaction['purchaseDate'] ?? 0);
			if ($purchaseDate <= 0)
			{
				return 0;
			}
			$purchase = new \DateTimeImmutable('@' . (int) floor($purchaseDate / 1000));
			return $purchase->modify('+' . $months . ' months')->getTimestamp();
		}
		return (int) floor(max(
			(int) ($transaction['expiresDate'] ?? 0),
			(int) ($renewalInfo['gracePeriodExpiresDate'] ?? 0)
		) / 1000);
	}

	private static function isLifetimeProduct(array $transaction): bool
	{
		return ($transaction['productId'] ?? '') === 'com.ekitapligim.app.premium.lifetime'
			&& ($transaction['type'] ?? '') === 'Non-Consumable';
	}

	private static function nonRenewingMonths(array $transaction): int
	{
		if (($transaction['type'] ?? '') !== 'Non-Renewing Subscription')
		{
			return 0;
		}
		switch ($transaction['productId'] ?? '')
		{
			case 'com.ekitapligim.app.premium.three_months': return 3;
			case 'com.ekitapligim.app.premium.six_months': return 6;
			case 'com.ekitapligim.app.premium.yearly_once': return 12;
			default: return 0;
		}
	}
}
