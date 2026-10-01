<?php

namespace Ekitapligim\IosApi\Service;

final class AppStoreEntitlementPolicy
{
	public static function isActive(array $transaction, array $renewalInfo, int $nowMilliseconds): bool
	{
		$revocationDate = (int) ($transaction['revocationDate'] ?? 0);
		if ($revocationDate > 0 || !empty($transaction['isUpgraded']) || !self::hasValidProductType($transaction))
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
			// Clamp to the last day of the destination month (Jan 31 + 3 months
			// is Apr 30), rather than PHP's overflowing month arithmetic.
			$target = $purchase->modify('first day of this month')->modify('+' . $months . ' months');
			return $target->setDate((int) $target->format('Y'), (int) $target->format('n'),
				min((int) $purchase->format('j'), (int) $target->format('t')))->getTimestamp();
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

	public static function hasValidProductType(array $transaction): bool
	{
		$product = (string) ($transaction['productId'] ?? '');
		if ($product === 'com.ekitapligim.app.premium.lifetime')
		{
			return self::isLifetimeProduct($transaction);
		}
		if (in_array($product, ['com.ekitapligim.app.premium.three_months',
			'com.ekitapligim.app.premium.six_months', 'com.ekitapligim.app.premium.yearly_once'], true))
		{
			return self::nonRenewingMonths($transaction) > 0;
		}
		return ($transaction['type'] ?? '') === 'Auto-Renewable Subscription';
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
