<?php

require __DIR__ . '/../Backend/IosApi-addon/Service/AppStoreProducts.php';
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
	$transaction += ['productId' => 'com.ekitapligim.app.premium.monthly', 'type' => 'Auto-Renewable Subscription'];
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

// VIP Premium is a one-time, never-expiring product like Unlimited Premium.
$vip = ['productId' => 'com.ekitapligim.app.premium.vip', 'type' => 'Non-Consumable'];
$vipChecks = [
	'vip non-consumable is valid' => AppStoreEntitlementPolicy::hasValidProductType($vip) === true,
	'vip is active without expiry' => AppStoreEntitlementPolicy::isActive($vip, [], $now) === true,
	'vip never expires' => AppStoreEntitlementPolicy::effectiveExpirationSeconds($vip, []) === 0,
	'refunded vip is inactive' => AppStoreEntitlementPolicy::isActive($vip + ['revocationDate' => $now - 1], [], $now) === false,
	'vip as subscription is rejected' => AppStoreEntitlementPolicy::hasValidProductType(
		['productId' => 'com.ekitapligim.app.premium.vip', 'type' => 'Auto-Renewable Subscription']) === false,
	'vip consumable is rejected' => AppStoreEntitlementPolicy::hasValidProductType(
		['productId' => 'com.ekitapligim.app.premium.vip', 'type' => 'Consumable']) === false,
	'lifetime unchanged' => AppStoreEntitlementPolicy::isActive(
		['productId' => 'com.ekitapligim.app.premium.lifetime', 'type' => 'Non-Consumable'], [], $now) === true,
];
foreach ($vipChecks as $name => $ok)
{
	if (!$ok)
	{
		fwrite(STDERR, "FAILED: {$name}\n");
		exit(1);
	}
}

fwrite(STDOUT, "App Store entitlement policy tests passed (" . count($cases) . " activation cases + expiration + "
	. count($vipChecks) . " VIP checks).\n");
