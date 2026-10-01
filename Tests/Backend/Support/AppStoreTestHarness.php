<?php
// Standalone harness. Optional local MySQL uses connection-scoped TEMPORARY
// tables only: no production/XenForo rows or permanent schemas are changed.
class XF
{
    public static int $time = 1800000000;
    public static $database;
    public static $groups;
    public static int $premiumGroup = 5;
    public static function db() { return self::$database; }
    public static function service($name) { return self::$groups; }
    public static function options() { return (object) ['ekGooglePlayPremiumGroupId' => self::$premiumGroup]; }
    public static function em() { return new class { public function find($type, $id) { return $id > 0 ? (object) ['user_id' => $id] : null; } }; }
    public static function logError($message): void {}
}

class TestGroupChanges {
    public array $changes = [];
    public bool $available = true;
    public function addUserGroupChange($userId, $key, $groups): bool {
        if (!$this->available) { return false; }
        $this->changes[$userId][$key] = $groups;
        return true;
    }
    public function removeUserGroupChange($userId, $key): bool {
        if (!$this->available) { return false; }
        unset($this->changes[$userId][$key]);
        return true;
    }
}

class AppStoreTestDb
{
    public PDO $pdo;
    public bool $mysql = false;
    public bool $lockAvailable = true;
    public bool $failWrite = false;
    public function __construct()
    {
        $path = getenv('APPSTORE_TEST_MYSQL_CONFIG');
        if ($path) {
            $config = [];
            require $path;
            $db = $config['db'];
            if (!in_array($db['host'], ['localhost', '127.0.0.1', '::1'], true)) {
                throw new RuntimeException('Only loopback MySQL is permitted in these tests.');
            }
            $this->pdo = new PDO('mysql:host=' . $db['host'] . ';port=' . ($db['port'] ?? 3306)
                . ';dbname=' . $db['dbname'], $db['username'], $db['password']);
            $this->mysql = true;
        } else {
            $this->pdo = new PDO('sqlite::memory:');
        }
        $this->pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    }
    public function query(string $sql, $args = [])
    {
        if (str_contains($sql, 'CREATE TABLE')) {
            if ($this->pdo->inTransaction()) { throw new LogicException('DDL inside transaction'); }
            if ($this->mysql) {
                $sql = str_replace('CREATE TABLE', 'CREATE TEMPORARY TABLE', $sql);
            } elseif (str_contains($sql, 'ios_appstore_account')) {
                $sql = 'CREATE TABLE IF NOT EXISTS xf_ekitapligim_ios_appstore_account
                    (user_id INTEGER PRIMARY KEY, app_account_token TEXT UNIQUE)';
            } elseif (str_contains($sql, 'ios_appstore_state')) {
                $sql = 'CREATE TABLE IF NOT EXISTS xf_ekitapligim_ios_appstore_state
                    (transaction_id TEXT PRIMARY KEY, transaction_state TEXT, renewal_state TEXT)';
            } elseif (str_contains($sql, 'mobile_appstore_entitlement')) {
                $sql = 'CREATE TABLE IF NOT EXISTS xf_ekitapligim_mobile_appstore_entitlement
                    (entitlement_id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER, product_id TEXT,
                    transaction_id TEXT UNIQUE, original_transaction_id TEXT, environment TEXT,
                    expires_date INTEGER, active INTEGER, signed_transaction_hash TEXT, last_verified INTEGER)';
            } else {
                $sql = 'CREATE TABLE IF NOT EXISTS xf_ekitapligim_mobile_appstore_notification
                    (notification_uuid TEXT UNIQUE, notification_type TEXT, subtype TEXT, environment TEXT,
                    original_transaction_id TEXT, transaction_id TEXT, signed_payload_hash TEXT, received_at INTEGER)';
            }
        }
        if ($this->failWrite && str_contains($sql, 'INSERT INTO')) { throw new RuntimeException('Injected database outage'); }
        if (!$this->mysql) {
            $key = str_contains($sql, 'ios_appstore_account') ? 'user_id'
                : (str_contains($sql, 'mobile_appstore_notification') ? 'notification_uuid' : 'transaction_id');
            $sql = str_replace('ON DUPLICATE KEY UPDATE', 'ON CONFLICT(' . $key . ') DO UPDATE SET', $sql);
            $sql = preg_replace('/VALUES\((\w+)\)/', 'excluded.$1', $sql);
        }
        $statement = $this->pdo->prepare($sql);
        $statement->execute(is_array($args) ? $args : [$args]);
        return $statement;
    }
    public function fetchOne($sql, $args = []) {
        if (str_contains($sql, 'GET_LOCK') && !$this->lockAvailable) { return 0; }
        if (!$this->mysql && (str_contains($sql, 'GET_LOCK') || str_contains($sql, 'RELEASE_LOCK'))) { return 1; }
        return $this->query($sql, $args)->fetchColumn();
    }
    public function fetchRow($sql, $args = []) { return $this->query($sql, $args)->fetch(PDO::FETCH_ASSOC); }
    public function fetchAllColumn($sql, $args = []) { return $this->query($sql, $args)->fetchAll(PDO::FETCH_COLUMN); }
    public function beginTransaction() { $this->pdo->beginTransaction(); }
    public function commit() { $this->pdo->commit(); }
    public function rollback() { $this->pdo->rollBack(); }
}

require_once __DIR__ . '/../../../Backend/IosApi-addon/Service/AppStoreEntitlementPolicy.php';
require_once __DIR__ . '/../../../Backend/IosApi-addon/Service/AppStoreTransactionStore.php';
require_once __DIR__ . '/../../../Backend/IosApi-addon/Service/IosMembershipSynchronizer.php';

function check(bool $condition, string $message): void {
    if (!$condition) { throw new RuntimeException($message); }
}
function purchaseFixture(string $id = 'codex-audit-transaction-1', string $original = 'codex-audit-original-1'): array {
    return ['transactionId' => $id, 'originalTransactionId' => $original,
        'bundleId' => 'com.ekitapligim.app', 'productId' => 'com.ekitapligim.app.premium.monthly',
        'type' => 'Auto-Renewable Subscription', 'environment' => 'Sandbox',
        'purchaseDate' => (XF::$time - 60) * 1000, 'expiresDate' => (XF::$time + 3600) * 1000,
        'signedDate' => XF::$time * 1000];
}

XF::$database = new AppStoreTestDb();
XF::$groups = new TestGroupChanges();
\Ekitapligim\IosApi\Service\AppStoreTransactionStore::ensureTables();
