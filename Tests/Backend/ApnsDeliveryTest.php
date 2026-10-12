<?php
declare(strict_types=1);

use Ekitapligim\IosApi\Service\ApnsPush;

final class XF
{
    public static DeliveryTestDb $db;
    public static array $errors = [];
    public static function db(): DeliveryTestDb { return self::$db; }
    public static function logError(string $message): void { self::$errors[] = $message; }
}

final class DeliveryTestDb
{
    public array $rows = [];
    public function fetchAll(string $query, array $params): array
    {
        check($query === 'SELECT token_id, device_token, created_at FROM xf_ios_device_tokens WHERE user_id = ?', 'Unexpected token query');
        return array_values(array_filter($this->rows, fn(array $row) => $row['user_id'] === $params[0]));
    }
    public function delete(string $table, string $where, array $params): int
    {
        check($table === 'xf_ios_device_tokens', 'Cleanup touched another table');
        check($where === 'token_id = ? AND device_token = ? AND user_id = ? AND created_at = ? AND created_at < ?', 'Unsafe cleanup predicate');
        [$id, $token, $user, $registeredAt, $before] = $params;
        $row = $this->rows[$id] ?? null;
        if ($row && $row['device_token'] === $token && $row['user_id'] === $user
            && $row['created_at'] === $registeredAt && $row['created_at'] < $before)
        {
            unset($this->rows[$id]);
            return 1;
        }
        return 0;
    }
}

require __DIR__ . '/../../Backend/IosApi-addon/Service/ApnsPush.php';

final class FakeApnsDelivery extends ApnsPush
{
    public static array $responses = [], $attempted = [];
    public static ?Closure $duringSend = null;
    public static bool $configured = true;
    protected static function generateJwt(): ?string { return self::$configured ? 'test-only-jwt' : null; }
    protected static function sendSingle(string $token, string $payload, string $jwt): array
    {
        self::$attempted[] = $token;
        if (self::$duringSend) { (self::$duringSend)($token); }
        return self::$responses[$token] ?? ['status' => 200, 'reason' => '', 'apns_id' => 'test-id'];
    }
}

function check(bool $ok, string $message): void { if (!$ok) { throw new RuntimeException($message); } }
function setup(): int
{
    XF::$db = new DeliveryTestDb(); XF::$errors = [];
    FakeApnsDelivery::$responses = []; FakeApnsDelivery::$attempted = [];
    FakeApnsDelivery::$duringSend = null; FakeApnsDelivery::$configured = true;
    $now = time();
    XF::$db->rows = [
        1 => ['token_id' => 1, 'device_token' => 'old-test-token', 'user_id' => 76, 'created_at' => $now - 100],
        2 => ['token_id' => 2, 'device_token' => 'valid-test-token', 'user_id' => 76, 'created_at' => $now - 90],
        3 => ['token_id' => 3, 'device_token' => 'other-user-token', 'user_id' => 77, 'created_at' => $now - 100]
    ];
    return $now;
}
function reject(int $status, string $reason, ?int $timestamp = null): void
{
    FakeApnsDelivery::$responses['old-test-token'] = ['status' => $status, 'reason' => $reason,
        'apns_id' => '9BDD5C13-651C-2B1A-0623-0EAA707D975E', 'timestamp' => $timestamp];
}
function send(): array { return FakeApnsDelivery::sendToUser(76, ['aps' => ['alert' => 'Synthetic fixture']]); }

$now = setup(); reject(410, 'Unregistered', ($now - 10) * 1000);
$summary = send();
check($summary === ['attempted' => 2, 'sent' => 1, 'failed' => 1, 'removed' => 1], 'Wrong mixed-delivery summary');
check(!isset(XF::$db->rows[1]) && isset(XF::$db->rows[2], XF::$db->rows[3]), 'Cleanup affected valid/other-user tokens');
check(XF::$errors === [], 'Expected Unregistered lifecycle logged as server error');
check(send() === ['attempted' => 1, 'sent' => 1, 'failed' => 0, 'removed' => 0], 'Stale token retried after removal');
echo "PASS: Unregistered cleanup is silent, counted, isolated and stops future attempts; valid devices still receive pushes.\n";

foreach ([null, ($now - 10) * 1000] as $timestamp)
{
    $now = setup(); reject(410, 'Unregistered', $timestamp);
    FakeApnsDelivery::$duringSend = static function(string $token): void {
        if ($token === 'old-test-token') { XF::$db->rows[1]['created_at'] = time(); }
    };
    check(send()['removed'] === 0 && isset(XF::$db->rows[1]), 'Late 410 removed re-registered token');
}
foreach (['same_second', 'newer_registration', 'reassigned', 'recreated'] as $case)
{
    $now = setup(); reject(410, 'Unregistered', ($now - 50) * 1000 + 999);
    if ($case === 'same_second') { XF::$db->rows[1]['created_at'] = $now - 50; }
    if ($case === 'newer_registration') { XF::$db->rows[1]['created_at'] = $now - 49; }
    if ($case === 'reassigned') {
        FakeApnsDelivery::$duringSend = static function(string $token): void {
            if ($token === 'old-test-token') { XF::$db->rows[1]['user_id'] = 78; }
        };
    }
    if ($case === 'recreated') {
        FakeApnsDelivery::$duringSend = static function(string $token): void {
            if ($token === 'old-test-token') {
                $replacement = XF::$db->rows[1]; unset(XF::$db->rows[1]);
                $replacement['token_id'] = 4; XF::$db->rows[4] = $replacement;
            }
        };
    }
    check(send()['removed'] === 0, 'Late response deleted changed registration: ' . $case);
    check(count(XF::$db->rows) === 3 && XF::$errors === [], 'Registration lost: ' . $case);
}
echo "PASS: APNs millisecond timestamp, second-boundary registration, concurrent renewal, account reassignment and replacement row are protected.\n";

foreach ([null, 0, -1, 'not-a-timestamp'] as $timestamp)
{
    $now = setup(); reject(410, 'Unregistered');
    FakeApnsDelivery::$responses['old-test-token']['timestamp'] = $timestamp;
    check(send()['removed'] === 1, 'Old row without usable timestamp not cleaned');
    check(XF::$errors === [], 'Missing timestamp caused error log');
}
$now = setup(); XF::$db->rows[1]['created_at'] = $now;
reject(410, 'Unregistered');
check(send()['removed'] === 0, 'Same-second registration removed without timestamp');
echo "PASS: missing/malformed timestamps use conservative request-time cleanup without deleting same-second registration.\n";

foreach ([[400, 'BadDeviceToken', 1], [400, 'DeviceTokenNotForTopic', 0],
    [403, 'InvalidProviderToken', 0], [403, 'ExpiredProviderToken', 0],
    [429, 'TooManyRequests', 0], [500, 'InternalServerError', 0],
    [503, 'ServiceUnavailable', 0], [0, 'curl_28', 0]] as [$status, $reason, $removed])
{
    setup(); reject($status, $reason);
    check(send()['removed'] === $removed, 'Wrong cleanup for ' . $reason);
    check(count(XF::$errors) === 1 && str_contains(XF::$errors[0], $reason), 'Operational error hidden or duplicated: ' . $reason);
    check(!str_contains(XF::$errors[0], 'test-token') && !str_contains(XF::$errors[0], 'test-only-jwt')
        && !str_contains(XF::$errors[0], 'Synthetic fixture'), 'Sensitive diagnostics leaked');
}
echo "PASS: bad token, topic/auth, rate-limit, server and transport failures remain visible without leaking tokens or payloads.\n";

setup();
check(send() === ['attempted' => 2, 'sent' => 2, 'failed' => 0, 'removed' => 0], 'Success behavior changed');
check(FakeApnsDelivery::sendToUser(0, [])['attempted'] === 0, 'Invalid user sent pushes');
check(FakeApnsDelivery::sendToUser(999, [])['attempted'] === 0, 'Unknown user sent pushes');
setup(); FakeApnsDelivery::$configured = false;
check(send() === ['attempted' => 0, 'sent' => 0, 'failed' => 2, 'removed' => 0], 'Missing configuration deleted tokens');
check(FakeApnsDelivery::$attempted === [] && count(XF::$db->rows) === 3, 'Unconfigured delivery touched tokens');
echo "PASS: successful, empty and unconfigured sends preserve prior behavior.\n";
echo "ALL APNS DELIVERY TESTS PASSED (offline, no APNs requests or database connection).\n";
