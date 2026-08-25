<?php

require __DIR__ . '/../Backend/IosApi-addon/Service/AppStoreEntitlementPolicy.php';

use Ekitapligim\IosApi\Service\AppStoreEntitlementPolicy;

$now = 1_700_000_000_000;

$cases = [
	'active subscription' => [
		['expiresDate' => $now + 60_000],
		[],
		true,
	],
	'expired subscription' => [
		['expiresDate' => $now - 1],
		[],
		false,
	],
	'billing grace period' => [
		['expiresDate' => $now - 1],
		['gracePeriodExpiresDate' => $now + 86_400_000],
		true,
	],
	'revoked during grace period' => [
		['expiresDate' => $now - 1, 'revocationDate' => $now - 500],
		['gracePeriodExpiresDate' => $now + 86_400_000],
		false,
	],
	'missing expiration fails closed' => [
		[],
		[],
		false,
	],
];

foreach ($cases as $name => [$transaction, $renewalInfo, $expected])
{
	$actual = AppStoreEntitlementPolicy::isActive($transaction, $renewalInfo, $now);
	if ($actual !== $expected)
	{
		fwrite(STDERR, "FAILED: {$name}\n");
		exit(1);
	}
}

$effective = AppStoreEntitlementPolicy::effectiveExpirationSeconds(
	['expiresDate' => $now - 1],
	['gracePeriodExpiresDate' => $now + 86_400_000]
);
if ($effective !== 1_700_086_400)
{
	fwrite(STDERR, "FAILED: effective grace expiration\n");
	exit(1);
}

fwrite(STDOUT, "App Store entitlement policy tests passed (" . count($cases) . " activation cases + expiration).\n");
