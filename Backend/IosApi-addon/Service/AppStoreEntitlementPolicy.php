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

		// The allowlist contains only auto-renewable subscriptions. A missing expiration
		// must fail closed rather than being interpreted as a lifetime entitlement.
		return $expiresDate > $nowMilliseconds || $gracePeriodExpiresDate > $nowMilliseconds;
	}

	public static function effectiveExpirationSeconds(array $transaction, array $renewalInfo): int
	{
		return (int) floor(max(
			(int) ($transaction['expiresDate'] ?? 0),
			(int) ($renewalInfo['gracePeriodExpiresDate'] ?? 0)
		) / 1000);
	}
}
