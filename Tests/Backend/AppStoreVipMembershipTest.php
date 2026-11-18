<?php
// VIP Premium (one-time App Store product): delivery, configuration safety, refund isolation and lifetime.

namespace Ekitapligim\MobileApi\Service {
    /** Stand-in for MobileApi's display helper: the VIP group ID comes from the "VIP Destekçi" group. */
    final class MembershipDisplay
    {
        public static int $vipGroup = 6;
        public static array $vipUsers = [];
        public static function vipGroupId(): int { return self::$vipGroup; }
        public static function isVip($user): bool { return $user && in_array((int) $user->user_id, self::$vipUsers, true); }
    }
}

namespace {
    require __DIR__ . '/Support/AppStoreTestHarness.php';

    use Ekitapligim\IosApi\Service\AppStoreEntitlementPolicy as Policy;
    use Ekitapligim\IosApi\Service\AppStoreProducts as Products;
    use Ekitapligim\IosApi\Service\AppStoreTransactionStore as Store;
    use Ekitapligim\IosApi\Service\IosMembershipSynchronizer as Membership;
    use Ekitapligim\MobileApi\Service\MembershipDisplay;

    function oneTime(string $product, string $id): array
    {
        $fixture = purchaseFixture($id, $id . '-original');
        unset($fixture['expiresDate']);
        $fixture['productId'] = $product;
        $fixture['type'] = 'Non-Consumable';
        return $fixture;
    }

    $lifetimeId = 'com.ekitapligim.app.premium.lifetime';

    // Readiness follows both groups.
    check(Products::vipReady(), 'VIP is sellable when Premium and VIP groups exist');
    check(Products::groupIdsForProduct(Products::VIP) === [5, 6], 'VIP grants Premium and VIP groups');
    check(Products::groupIdsForProduct($lifetimeId) === [5], 'Unlimited Premium keeps granting Premium only');
    check(Products::groupIdsForProduct('com.ekitapligim.app.premium.monthly') === [5], 'Subscriptions keep granting Premium only');

    // Delivery.
    $vip = oneTime(Products::VIP, 'vip-1');
    check(Policy::hasValidProductType($vip) && Policy::isActive($vip, [], XF::$time * 1000), 'VIP non-consumable is active');
    Store::record(31, $vip, [], 'fixture');
    check(Membership::syncUser(31), 'VIP purchase synchronizes');
    check(array_values(XF::$groups->changes[31]) === [[5, 6]], 'VIP buyer receives Premium and VIP');
    check(Membership::syncUser(31) && count(XF::$groups->changes[31]) === 1, 'Repeated VIP sync is idempotent');
    $context = Store::purchaseContext(31);
    check($context['has_vip_supporter'] === true && $context['has_lifetime'] === false, 'Purchase context reports VIP separately');

    // Missing VIP group: never reported as delivered, recovered on retry; nothing is half-granted.
    MembershipDisplay::$vipGroup = 0;
    check(!Products::vipReady(), 'VIP is not sellable without the VIP group');
    Store::record(33, oneTime(Products::VIP, 'vip-3'), [], 'fixture');
    check(!Membership::syncUser(33), 'Missing VIP group must not acknowledge delivery');
    check(empty(XF::$groups->changes[33]), 'Nothing is granted while VIP is misconfigured');
    MembershipDisplay::$vipGroup = 5;
    check(!Membership::syncUser(33), 'VIP group equal to Premium is rejected');
    MembershipDisplay::$vipGroup = 6;
    check(Membership::syncUser(33) && array_values(XF::$groups->changes[33]) === [[5, 6]], 'Retry after configuration recovery delivers VIP');

    // Refund isolation: Unlimited Premium bought separately survives a VIP refund.
    $lifetime = oneTime($lifetimeId, 'lifetime-2');
    $vip2 = oneTime(Products::VIP, 'vip-2');
    Store::record(32, $lifetime, [], 'fixture');
    Store::record(32, $vip2, [], 'fixture');
    check(Membership::syncUser(32) && count(XF::$groups->changes[32]) === 2, 'Lifetime and VIP keep separate grants');
    $vip2['revocationDate'] = XF::$time * 1000;
    $vip2['signedDate'] += 1000;
    Store::record(0, $vip2, [], 'fixture');
    check(Membership::syncUser(32), 'VIP refund synchronizes');
    check(array_values(XF::$groups->changes[32]) === [[5]], 'VIP refund keeps the separately bought Premium');
    $context = Store::purchaseContext(32);
    check($context['has_lifetime'] === true && $context['has_vip_supporter'] === false, 'Context after VIP refund');

    // Lifetime: years later the cron keeps VIP.
    XF::$time += 5 * 365 * 86400;
    Membership::syncAll();
    check(array_values(XF::$groups->changes[31]) === [[5, 6]], 'VIP never expires');
    check(Policy::effectiveExpirationSeconds($vip, []) === 0, 'VIP has no expiration date');

    // Wrong store type is never accepted for VIP.
    check(!Policy::hasValidProductType(['productId' => Products::VIP, 'type' => 'Auto-Renewable Subscription']),
        'VIP sold as a subscription is rejected');

    echo "App Store VIP membership: delivery, configuration, refund isolation and lifetime scenarios passed.\n";
}
