<?php
// Standalone contract checks for signed App Store transaction policy.
require_once __DIR__ . '/../../Backend/IosApi-addon/Service/AppStoreEntitlementPolicy.php';

use Ekitapligim\IosApi\Service\AppStoreEntitlementPolicy as Policy;

function checkPolicy(bool $condition, string $message): void
{
    if (!$condition) { throw new RuntimeException($message); }
}

$purchase = strtotime('2026-09-27 12:00:00 UTC');
$purchaseMs = $purchase * 1000;
foreach ([
    'three_months' => 3,
    'six_months' => 6,
    'yearly_once' => 12,
] as $suffix => $months) {
    $transaction = [
        'productId' => 'com.ekitapligim.app.premium.' . $suffix,
        'type' => 'Non-Renewing Subscription',
        'purchaseDate' => $purchaseMs,
    ];
    $expiration = (new DateTimeImmutable('@' . $purchase))->modify('+' . $months . ' months')->getTimestamp();
    checkPolicy(Policy::effectiveExpirationSeconds($transaction, []) === $expiration, "$suffix expiration");
    checkPolicy(Policy::isActive($transaction, [], ($expiration - 1) * 1000), "$suffix active before expiry");
    checkPolicy(!Policy::isActive($transaction, [], $expiration * 1000), "$suffix inactive at expiry");
    $transaction['revocationDate'] = ($purchase + 10) * 1000;
    checkPolicy(!Policy::isActive($transaction, [], ($purchase + 20) * 1000), "$suffix revoked");
}

$lifetime = ['productId' => 'com.ekitapligim.app.premium.lifetime', 'type' => 'Non-Consumable'];
checkPolicy(Policy::isActive($lifetime, [], $purchaseMs), 'lifetime active');
checkPolicy(Policy::effectiveExpirationSeconds($lifetime, []) === 0, 'lifetime never expires');
$lifetime['revocationDate'] = $purchaseMs;
checkPolicy(!Policy::isActive($lifetime, [], $purchaseMs + 1), 'lifetime revocation');

$wrongType = ['productId' => 'com.ekitapligim.app.premium.lifetime', 'type' => 'Consumable'];
checkPolicy(!Policy::isActive($wrongType, [], $purchaseMs), 'lifetime requires non-consumable type');
$missingDate = ['productId' => 'com.ekitapligim.app.premium.three_months', 'type' => 'Non-Renewing Subscription'];
checkPolicy(!Policy::isActive($missingDate, [], $purchaseMs), 'non-renewing purchase date required');

echo "App Store entitlement policy: 17 scenarios passed.\n";

$monthEnd = ['productId' => 'com.ekitapligim.app.premium.three_months',
    'type' => 'Non-Renewing Subscription', 'purchaseDate' => strtotime('2026-01-31 12:00:00 UTC') * 1000];
checkPolicy(Policy::effectiveExpirationSeconds($monthEnd, []) === strtotime('2026-04-30 12:00:00 UTC'), 'Month end clamps');
$leap = ['productId' => 'com.ekitapligim.app.premium.yearly_once',
    'type' => 'Non-Renewing Subscription', 'purchaseDate' => strtotime('2024-02-29 12:00:00 UTC') * 1000];
checkPolicy(Policy::effectiveExpirationSeconds($leap, []) === strtotime('2025-02-28 12:00:00 UTC'), 'Leap year clamps');
$upgraded = ['productId' => 'com.ekitapligim.app.premium.monthly', 'type' => 'Auto-Renewable Subscription',
    'expiresDate' => $purchaseMs + 86400000, 'isUpgraded' => true];
checkPolicy(!Policy::isActive($upgraded, [], $purchaseMs), 'Superseded subscription cannot grant access');
echo "App Store entitlement policy: month-end, leap-year, upgraded subscription passed.\n";
