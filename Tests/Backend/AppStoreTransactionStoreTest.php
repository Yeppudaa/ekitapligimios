<?php
require __DIR__ . '/Support/AppStoreTestHarness.php';
use Ekitapligim\IosApi\Service\AppStoreTransactionStore as Store;

$transaction = purchaseFixture();
$record = Store::record(11, $transaction, [], 'fixture-hash');
check((bool) $record['active'], 'Initial purchase active');
Store::record(11, $transaction, [], 'fixture-hash');
check((int) XF::db()->fetchOne('SELECT COUNT(*) FROM xf_ekitapligim_mobile_appstore_entitlement') === 1, 'Verification idempotent');
try { Store::record(12, $transaction, [], 'fixture-hash'); throw new LogicException('Owner changed'); }
catch (DomainException $e) { check($e->getMessage() === 'original_transaction_already_linked', 'Ownership rejection explicit'); }

$new = purchaseFixture('codex-audit-transaction-2');
$new['expiresDate'] += 3600000;
$new['signedDate'] += 1000;
Store::record(0, $new, [], 'fixture-hash');
$revoked = $transaction;
$revoked['revocationDate'] = XF::$time * 1000;
$revoked['signedDate'] += 2000;
Store::record(0, $revoked, [], 'fixture-hash');
$stale = Store::record(11, $transaction, [], 'fixture-hash');
check(!$stale['active'], 'Stale receipt cannot undo refund');
$latest = XF::db()->fetchRow('SELECT * FROM xf_ekitapligim_mobile_appstore_entitlement WHERE transaction_id = ?', [$new['transactionId']]);
check((bool) $latest['active'] && (int) $latest['user_id'] === 11, 'Old refund preserves newer renewal and owner');
check((int) XF::db()->fetchOne('SELECT COUNT(*) FROM xf_ekitapligim_mobile_appstore_entitlement') === 2, 'Renewals keep distinct transaction IDs');

$reversal = $transaction;
$reversal['signedDate'] += 3000;
check(Store::record(0, $reversal, [], 'fixture-hash')['active'], 'Newer signed refund reversal can restore access');

$orphan = purchaseFixture('codex-audit-orphan', 'codex-audit-orphan-chain');
$orphan['revocationDate'] = XF::$time * 1000;
check(!Store::record(0, $orphan, [], 'fixture-hash')['active'], 'Notification before first verification persists');
$orphanReceipt = $orphan;
unset($orphanReceipt['revocationDate']);
$orphanReceipt['signedDate'] -= 1000;
$bound = Store::record(22, $orphanReceipt, [], 'fixture-hash');
check(!$bound['active'] && $bound['user_id'] === 22, 'First verification binds orphan without resurrecting refund');

$grace = purchaseFixture('codex-audit-grace', 'codex-audit-grace-chain');
$grace['expiresDate'] = (XF::$time - 1) * 1000;
$renewal = ['signedDate' => XF::$time * 1000, 'gracePeriodExpiresDate' => (XF::$time + 86400) * 1000];
check(Store::record(33, $grace, $renewal, 'fixture-hash')['active'], 'Grace grants access');
check(Store::record(33, $grace, [], 'fixture-hash')['active'], 'Missing renewal JWS does not erase known grace');
$ended = ['signedDate' => (XF::$time + 1) * 1000];
check(!Store::record(0, $grace, $ended, 'fixture-hash')['active'], 'New renewal JWS ends grace');
check(!Store::record(33, $grace, $renewal, 'fixture-hash')['active'], 'Old grace JWS cannot restore expired access');

XF::db()->lockAvailable = false;
try { Store::record(11, $transaction, [], 'fixture-hash'); throw new LogicException('Lock failure accepted'); }
catch (RuntimeException $e) { check(!$e instanceof DomainException, 'Lock contention is transient, not wrong account'); }
XF::db()->lockAvailable = true;
XF::db()->failWrite = true;
try { Store::record(44, purchaseFixture('codex-audit-failed', 'codex-audit-failed-chain'), [], 'fixture-hash'); throw new LogicException('Write failure accepted'); }
catch (RuntimeException $e) {}
XF::db()->failWrite = false;
check(!XF::db()->pdo->inTransaction(), 'Failed write rolls back');
check(!XF::db()->fetchRow('SELECT * FROM xf_ekitapligim_ios_appstore_state WHERE transaction_id = ?', ['codex-audit-failed']), 'No partial state after outage');
$private = $transaction + ['appAccountToken' => 'private-value', 'currency' => 'TRY'];
[$filtered] = Store::merge([], [], $private, []);
check(!isset($filtered['appAccountToken']) && !isset($filtered['currency']), 'Persist only required entitlement fields');
echo 'App Store ledger: 18 ordering, ownership, orphan, grace, rollback and privacy scenarios passed (' . (XF::db()->mysql ? 'MySQL temporary tables' : 'SQLite adapter') . ").\n";

$token = Store::accountToken(55);
check((bool) preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/D', $token), 'Purchase account token must be a v4 UUID');
check(Store::accountToken(55) === $token, 'Purchase token survives repeated preparation and username changes');
check(Store::accountToken(66) !== $token, 'Different accounts have different purchase UUIDs');
$boundTransaction = purchaseFixture('bound-before-verification', 'bound-before-verification-chain');
$boundTransaction['appAccountToken'] = strtoupper($token);
try { Store::record(66, $boundTransaction, [], 'fixture'); throw new LogicException('First verification stole another account purchase'); }
catch (DomainException $e) { check($e->getMessage() === 'original_transaction_already_linked', 'Account switch is a conflict'); }
check(Store::record(0, $boundTransaction, [], 'fixture')['user_id'] === 55, 'Notification delivers to the initiating account before first client verification');
check(Store::record(55, $boundTransaction, [], 'fixture')['active'], 'Initiating account can restore its purchase');
$boundTransaction['appAccountToken'] = '00000000-0000-4000-8000-000000000000';
try { Store::record(55, $boundTransaction, [], 'fixture'); throw new LogicException('Unknown purchase account accepted'); }
catch (DomainException $e) { check($e->getMessage() === 'app_account_token_unknown', 'Unknown purchase UUID fails closed'); }
echo "App Store account binding: 7 UUID, account-switch, early notification and restore scenarios passed.\n";
