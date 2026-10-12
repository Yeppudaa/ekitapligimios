<?php
require __DIR__ . '/Support/AppStoreTestHarness.php';
use Ekitapligim\IosApi\Service\AppStoreTransactionStore as Store;
use Ekitapligim\IosApi\Service\IosMembershipSynchronizer as Membership;

function term(string $id, string $date, string $product = 'three_months'): array {
    $value = purchaseFixture($id, $id . '-original');
    $value['productId'] = 'com.ekitapligim.app.premium.' . $product;
    $value['type'] = $product === 'lifetime' ? 'Non-Consumable' : 'Non-Renewing Subscription';
    $value['purchaseDate'] = strtotime($date . ' 12:00:00 UTC') * 1000;
    $value['signedDate'] = $value['purchaseDate'];
    unset($value['expiresDate']);
    return $value;
}
function until(array $record, string $date, string $message): void {
    check((int) $record['expires_date'] === strtotime($date . ' 12:00:00 UTC'), $message);
}
function saved(string $id): array {
    return XF::db()->fetchRow('SELECT * FROM xf_ekitapligim_mobile_appstore_entitlement WHERE transaction_id = ?', [$id]) ?: [];
}
XF::$time = strtotime('2026-02-01 12:00:00 UTC');
$first = term('term-1', '2026-01-01');
$second = term('term-2', '2026-02-01');
until(Store::record(101, $first, [], 'fixture'), '2026-04-01', 'Single purchase unchanged');
until(Store::record(101, $second, [], 'fixture'), '2026-07-01', 'Repeat purchase retains two unused months');
for ($i = 0; $i < 3; $i++) {
    until(Store::record(101, $second, [], 'fixture'), '2026-07-01', 'Replay does not add time again');
}
until(Store::record(101, $first, [], 'fixture'), '2026-04-01', 'Old receipt cannot extend twice or erase newer term');
until(saved('term-2'), '2026-07-01', 'Second term retained after older restore');
check(Membership::syncUser(101) && count(XF::$groups->changes[101]) === 2, 'Both terms deliver permission');

$annual = term('annual', '2026-01-01', 'yearly_once');
Store::record(102, $annual, [], 'fixture');
until(Store::record(102, term('annual-extra', '2026-02-01'), [], 'fixture'), '2027-04-01', 'Shorter extra purchase extends annual');
until(Store::record(103, term('gap-first', '2025-01-01'), [], 'fixture'), '2025-04-01', 'Expired history remains expired');
until(Store::record(103, term('gap-second', '2026-02-01'), [], 'fixture'), '2026-05-01', 'A gap starts from actual purchase');

// Arrival order and first-notification ownership do not change calendar delivery.
$late = term('out-order-2', '2026-02-01');
Store::record(104, $late, [], 'fixture');
Store::record(104, term('out-order-1', '2026-01-01'), [], 'fixture');
until(saved('out-order-2'), '2026-07-01', 'Out-of-order delivery recalculates deterministically');
$orphan = term('orphan-term', '2026-01-01');
Store::record(0, $orphan, [], 'fixture');
Store::record(105, term('owned-term', '2026-02-01'), [], 'fixture');
Store::record(105, $orphan, [], 'fixture');
until(saved('owned-term'), '2026-07-01', 'Claiming an early notification retains full paid terms');

// Removing one refunded term changes only that term's contribution.
$refund = $first + ['revocationDate' => XF::$time * 1000];
$refund['signedDate'] = XF::$time * 1000 + 1000;
check(!Store::record(0, $refund, [], 'fixture')['active'], 'Refund disables its transaction');
until(saved('term-2'), '2026-05-01', 'Refunded months no longer extend a different purchase');
Store::record(101, $first, [], 'fixture');
until(saved('term-2'), '2026-05-01', 'Stale receipt cannot restore refunded months');
$reversal = $first; $reversal['signedDate'] = $refund['signedDate'] + 1000;
Store::record(0, $reversal, [], 'fixture');
until(saved('term-2'), '2026-07-01', 'Signed refund reversal restores only once');

$production = term('production-term', '2026-02-01'); $production['environment'] = 'Production';
until(Store::record(101, $production, [], 'fixture'), '2026-05-01', 'Sandbox and Production schedules are isolated');
try { Store::record(999, $second, [], 'fixture'); throw new LogicException('Wrong owner accepted'); }
catch (DomainException $e) { check($e->getMessage() === 'original_transaction_already_linked', 'Ownership unchanged'); }

Store::record(106, term('month-end-1', '2026-01-31'), [], 'fixture');
until(Store::record(106, term('month-end-2', '2026-02-28'), [], 'fixture'), '2026-07-30', 'Carried calendar periods clamp month ends');

$subscription = purchaseFixture('subscription', 'subscription-original');
$subscription['purchaseDate'] = strtotime('2026-02-01 12:00:00 UTC') * 1000;
$subscription['expiresDate'] = strtotime('2026-03-01 12:00:00 UTC') * 1000;
Store::record(107, $subscription, [], 'fixture');
until(Store::record(107, term('after-subscription', '2026-02-10'), [], 'fixture'), '2026-06-01', 'Fixed term starts after existing subscription coverage');
// New Apple coverage can interrupt a fixed term; consumed time is not duplicated.
Store::record(108, term('interrupted-term', '2026-01-01'), [], 'fixture');
$interrupt = $subscription; $interrupt['transactionId'] = 'interrupt'; $interrupt['originalTransactionId'] = 'interrupt-original';
Store::record(108, $interrupt, [], 'fixture');
until(saved('interrupted-term'), '2026-04-29', 'Only 28 overlapping days are carried over');
$interrupt2 = $interrupt; $interrupt2['transactionId'] = 'interrupt-overlap';
Store::record(108, $interrupt2, [], 'fixture');
until(saved('interrupted-term'), '2026-04-29', 'Overlapping subscription intervals count once');

Store::record(109, term('life', '2026-01-01', 'lifetime'), [], 'fixture');
$context = Store::purchaseContext(109);
check($context['has_lifetime'] && !$context['has_active_subscription'], 'Lifetime advice available without changing old token response');
check(Store::purchaseContext(107)['has_active_subscription'], 'Existing renewable subscription advised');
check(Store::purchaseContext(102)['has_fixed_term'], 'Existing fixed term advised');
check(!Store::purchaseContext(900)['has_lifetime'], 'Another user cannot inherit advice');
check(Store::record(109, term('old-client-paid', '2026-02-01'), [], 'fixture')['active'], 'Never reject a paid old-client transaction because lifetime already exists');

// A pre-ledger grant has no trustworthy purchase timeline. Keep it intact and
// begin new fixed delivery after its recorded expiry, including on replay.
$legacy = term('legacy-grant', '2026-01-01');
Store::record(110, $legacy, [], 'fixture');
XF::db()->query('DELETE FROM xf_ekitapligim_ios_appstore_state WHERE transaction_id = ?', ['legacy-grant']);
$legacyBefore = saved('legacy-grant');
$legacyExtra = term('legacy-extra', '2026-02-01');
until(Store::record(110, $legacyExtra, [], 'fixture'), '2026-07-01', 'New purchase preserves opaque legacy coverage');
until(Store::record(110, $legacyExtra, [], 'fixture'), '2026-07-01', 'Opaque legacy coverage is not added again on replay');
check(saved('legacy-grant') === $legacyBefore, 'Pre-ledger grant is never rewritten by projection');

$snapshot = saved('term-2');
XF::db()->failUpdate = true;
try { Store::record(101, term('rollback-term', '2026-02-02'), [], 'fixture'); throw new LogicException('Projection outage accepted'); }
catch (RuntimeException $e) { check(!$e instanceof LogicException, 'Projection failure propagated'); }
XF::db()->failUpdate = false;
check(saved('term-2') === $snapshot && !saved('rollback-term'), 'Projection failure rolls back all transaction and duration changes');
check(!XF::db()->fetchRow('SELECT * FROM xf_ekitapligim_ios_appstore_state WHERE transaction_id = ?', ['rollback-term']), 'No orphaned signed state after rollback');
XF::db()->blockedLockPrefix = 'ek_ios_purchase_';
try { Store::record(101, term('busy-term', '2026-02-02'), [], 'fixture'); throw new LogicException('Account lock bypassed'); }
catch (RuntimeException $e) { check(!$e instanceof DomainException && !$e instanceof LogicException, 'Cross-product lock contention is retryable'); }
XF::db()->blockedLockPrefix = '';
check(!saved('busy-term') && saved('term-2') === $snapshot, 'No write before obtaining shared account lock');
$trace = XF::db()->lockTrace;
check(end($trace)[0] === 'release' && str_starts_with(end($trace)[1], 'ekitapligim_appstore_'), 'Chain lock released after account lock failure');

XF::$time = strtotime('2026-05-02 12:00:00 UTC');
until(Store::record(101, $second, [], 'fixture'), '2026-07-01', 'Restore stays active beyond original standalone expiry');
Membership::syncUser(101);
check(count(XF::$groups->changes[101]) === 1, 'Only the extended term remains after original and production expiry');
echo "App Store fixed terms: replay, stacking, mixed plans, refunds, reversal, out-of-order, ownership, environment, calendar and legacy-client checks passed.\n";
