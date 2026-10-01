<?php
require __DIR__ . '/Support/AppStoreTestHarness.php';
use Ekitapligim\IosApi\Service\AppStoreTransactionStore as Store;
use Ekitapligim\IosApi\Service\IosMembershipSynchronizer as Membership;

XF::$groups->changes[11]['manual-upgrade'] = [5];
$transaction = purchaseFixture();
Store::record(11, $transaction, [], 'fixture');
check(Membership::syncUser(11), 'Active entitlement synchronizes');
check(count(XF::$groups->changes[11]) === 2, 'App Store grant coexists with manual grant');
check(Membership::syncUser(11) && count(XF::$groups->changes[11]) === 2, 'Repeated sync idempotent');
$renewal = purchaseFixture('codex-next');
Store::record(0, $renewal, [], 'fixture');
check(Membership::syncUser(11) && count(XF::$groups->changes[11]) === 3, 'Renewal grant independent');
$transaction['revocationDate'] = XF::$time * 1000;
$transaction['signedDate'] += 1000;
Store::record(0, $transaction, [], 'fixture');
check(Membership::syncUser(11) && count(XF::$groups->changes[11]) === 2, 'Old refund preserves next renewal and manual entitlement');
XF::$time += 3601;
Membership::syncAll();
check(array_keys(XF::$groups->changes[11]) === ['manual-upgrade'], 'Cron removes only expired App Store grants');

$orphan = purchaseFixture('orphan', 'orphan-chain');
Store::record(0, $orphan, [], 'fixture');
Membership::syncAll();
check(!isset(XF::$groups->changes[0]), 'Orphan notification cannot grant guest permissions');
Store::record(22, $orphan, [], 'fixture');
XF::$premiumGroup = 0;
check(!Membership::syncUser(22), 'Missing premium group never reports delivered');
XF::$premiumGroup = 5;
check(Membership::syncUser(22) && count(XF::$groups->changes[22]) === 1, 'Retry after configuration recovery delivers premium');
$orphan['revocationDate'] = XF::$time * 1000;
$orphan['signedDate'] += 1000;
Store::record(0, $orphan, [], 'fixture');
XF::$groups->available = false;
check(!Membership::syncUser(22), 'Failed removal must not be acknowledged');
XF::$groups->available = true;
check(Membership::syncUser(22) && !XF::$groups->changes[22], 'Revocation retry removes premium');
echo "App Store membership: 11 delivery, renewal, refund, expiry, orphan and configuration scenarios passed.\n";
