<?php
declare(strict_types=1);

namespace XF\Entity {
    class User {
        public bool $is_banned = false;
        public string $user_state = 'valid';
        public function __construct(public int $user_id) {}
    }
}

namespace {
    use Ekitapligim\IosApi\Service\MobileSession;
    use XF\Entity\User;

    final class SessionTestDb {
        public array $rows = [];
        public int $nextId = 1;
        public int $commits = 0;
        public int $rollbacks = 0;
        public bool $failInsert = false;
        private ?array $snapshot = null;

        public function query(string $sql): void {
            check(str_contains($sql, 'CREATE TABLE IF NOT EXISTS xf_ekitapligim_mobile_session'), 'Unexpected schema operation');
        }
        public function beginTransaction(): void {
            check($this->snapshot === null, 'Nested transaction');
            $this->snapshot = [$this->rows, $this->nextId];
        }
        public function commit(): void {
            check($this->snapshot !== null, 'Commit without transaction');
            $this->snapshot = null; $this->commits++;
        }
        public function rollback(): void {
            check($this->snapshot !== null, 'Rollback without transaction');
            [$this->rows, $this->nextId] = $this->snapshot;
            $this->snapshot = null; $this->rollbacks++;
        }
        public function insert(string $table, array $row): void {
            check($table === 'xf_ekitapligim_mobile_session', 'Wrong table');
            if ($this->failInsert) throw new RuntimeException('Simulated insert failure');
            foreach ($this->rows as $existing) {
                if ($existing['access_token_hash'] === $row['access_token_hash'] || $existing['refresh_token_hash'] === $row['refresh_token_hash']) {
                    throw new RuntimeException('Duplicate token');
                }
            }
            $row['session_id'] = $this->nextId++;
            $row['revoked_date'] = 0;
            $this->rows[$row['session_id']] = $row;
        }
        public function update(string $table, array $values, string $where, array $params): void {
            check($table === 'xf_ekitapligim_mobile_session', 'Wrong update table');
            check(in_array($where, ['session_id = ?', 'access_token_hash = ?', 'access_token_hash = ? AND revoked_date = 0', 'user_id = ? AND revoked_date = 0'], true), 'Unexpected update predicate');
            $column = strtok($where, ' ');
            foreach ($this->rows as &$row) {
                if ($row[$column] === $params[0] && (!str_contains($where, 'revoked_date = 0') || !$row['revoked_date'])) {
                    $row = array_merge($row, $values);
                }
            }
        }
        public function fetchRow(string $sql, array $params): array|false {
            check($this->snapshot !== null && str_ends_with($sql, ' FOR UPDATE'), 'Refresh reads must hold transaction row locks');
            if (str_contains($sql, 'WHERE refresh_token_hash = ?')) {
                foreach ($this->rows as $row) {
                    if ($row['refresh_token_hash'] !== $params[0]) continue;
                    if (str_contains($sql, 'revoked_date = 0') && $row['revoked_date']) continue;
                    if (str_contains($sql, 'refresh_expires_date > ?') && $row['refresh_expires_date'] <= $params[1]) continue;
                    return $row;
                }
            } else {
                check(str_contains($sql, 'WHERE access_token_hash = ? AND refresh_token_hash = ? AND revoked_date = 0 AND access_expires_date > ? AND refresh_expires_date > ?'), 'Unexpected successor predicate');
                foreach ($this->rows as $row) {
                    if ($row['access_token_hash'] === $params[0] && $row['refresh_token_hash'] === $params[1] && !$row['revoked_date'] &&
                        $row['access_expires_date'] > $params[2] && $row['refresh_expires_date'] > $params[3]) return $row;
                }
            }
            return false;
        }
        public function fetchOne(string $sql, array $params): int|false {
            check(str_contains($sql, 'WHERE access_token_hash = ? AND revoked_date = 0 AND access_expires_date > ? LIMIT 1'), 'Unexpected access predicate');
            foreach ($this->rows as $row) {
                if ($row['access_token_hash'] === $params[0] && !$row['revoked_date'] && $row['access_expires_date'] > $params[1]) return $row['user_id'];
            }
            return false;
        }
    }
    final class XF {
        public static int $time = 1900000000;
        public static SessionTestDb $db;
        public static array $users = [];
        public static string $salt = 'isolated-mobile-session-test-key';
        public static function db(): SessionTestDb { return self::$db; }
        public static function config(string $name): string { check($name === 'globalSalt', 'Unexpected config'); return self::$salt; }
        public static function em(): object { return new class { public function find(string $name, int $id): ?User { return XF::$users[$id] ?? null; } }; }
    }
    function check(bool $condition, string $message): void { if (!$condition) throw new RuntimeException($message); }
    function resetSessionTest(): User {
        XF::$time = 1900000000; XF::$salt = 'isolated-mobile-session-test-key';
        XF::$db = new SessionTestDb(); XF::$users = [7 => new User(7), 8 => new User(8)];
        return XF::$users[7];
    }
    function issuedAndRotated(): array {
        $tokens = MobileSession::issue(resetSessionTest(), '127.0.0.1', 'test-client');
        $rotated = MobileSession::rotate($tokens['refresh_token'], '127.0.0.2', 'updated-client');
        check($rotated !== null, 'First refresh failed');
        return [$tokens, $rotated['tokens']];
    }
    function expectFailure(callable $action, string $expected): void {
        try { $action(); } catch (RuntimeException $e) { check($e->getMessage() === $expected, 'Unexpected exception: '.$e->getMessage()); return; }
        throw new RuntimeException('Expected exception not raised');
    }
    require __DIR__.'/../../Backend/IosApi-addon/Service/MobileSession.php';
    set_error_handler(static function ($severity, $message, $file, $line) {
        if (error_reporting() & $severity) throw new ErrorException($message, 0, $severity, $file, $line);
        return false;
    });

    [$old, $next] = issuedAndRotated();
    check(MobileSession::userIdForAccessToken($old['access_token']) === 0, 'Old access remained usable');
    check(MobileSession::userIdForAccessToken($next['access_token']) === 7, 'New access unavailable');
    $rows = XF::$db->rows;
    XF::$time += 1;
    $retry = MobileSession::rotate($old['refresh_token'], 'another-ip', 'after-app-update');
    check($retry !== null && $retry['tokens'] === $next, 'Lost-response retry must return the exact successor pair');
    check(XF::$db->rows === $rows && count(XF::$db->rows) === 2, 'Retry created or extended a session');
    XF::$time += 118;
    check(MobileSession::rotate($old['refresh_token'])['tokens'] === $next, 'Retry inside grace failed');
    XF::$time++;
    check(MobileSession::rotate($old['refresh_token']) === null, 'Grace boundary accepted');
    check(XF::$db->rows === $rows, 'Rejected retry mutated sessions');
    echo "PASS: lost-response and duplicate refresh return one successor; strict 120-second grace\n";

    $user = resetSessionTest();
    $first = MobileSession::issue($user); $second = MobileSession::issue($user);
    check($first !== $second, 'Login issuance is no longer random');
    check(XF::$db->rows[1]['access_expires_date'] === XF::$time + 3600 && XF::$db->rows[1]['refresh_expires_date'] === XF::$time + 2592000, 'Login lifetimes changed');
    $rotated = MobileSession::rotate($first['refresh_token'])['tokens'];
    check(XF::$db->rows[3]['access_expires_date'] === XF::$time + 3600 && XF::$db->rows[3]['refresh_expires_date'] === XF::$time + 2592000, 'Refresh lifetimes changed');
    check(substr($rotated['access_token'], 6) !== substr($rotated['refresh_token'], 6), 'Access/refresh derivation not separated');
    $persisted = json_encode(XF::$db->rows);
    foreach (array_merge(array_values($first), array_values($second), array_values($rotated)) as $token) {
        check(!str_contains($persisted, $token), 'Raw token stored');
    }
    check(!str_contains($persisted, XF::$salt), 'Signing key stored');
    echo "PASS: random login issuance, unchanged lifetimes, separated token types, hash-only persistence\n";

    $old = MobileSession::issue(resetSessionTest());
    MobileSession::revokeAccessToken($old['access_token']); $rows = XF::$db->rows;
    check(MobileSession::rotate($old['refresh_token']) === null && XF::$db->rows === $rows, 'Explicit logout resurrected session');
    [$old, $next] = issuedAndRotated();
    MobileSession::revokeAccessToken($old['access_token']); $rows = XF::$db->rows;
    check(MobileSession::rotate($old['refresh_token']) === null && XF::$db->rows === $rows, 'Logout using pre-refresh access still allowed lost-response recovery');
    [$old, $next] = issuedAndRotated();
    MobileSession::revokeAccessToken($next['access_token']); $rows = XF::$db->rows;
    check(MobileSession::rotate($old['refresh_token']) === null, 'Old retry resurrected logged-out successor');
    check(MobileSession::rotate($next['refresh_token']) === null && XF::$db->rows === $rows, 'Successor logout bypassed');
    [$old, $next] = issuedAndRotated();
    $other = MobileSession::issue(XF::$users[8]);
    MobileSession::revokeUserSessions(7); $rows = XF::$db->rows;
    check(MobileSession::rotate($old['refresh_token']) === null && MobileSession::rotate($next['refresh_token']) === null, 'User-wide revocation bypassed');
    check(XF::$db->rows === $rows && MobileSession::userIdForAccessToken($other['access_token']) === 8, 'User revocation affected unrelated user');
    [$old, $next] = issuedAndRotated();
    $third = MobileSession::rotate($next['refresh_token'])['tokens'];
    check(MobileSession::rotate($old['refresh_token']) === null, 'Older generation followed rotated successor');
    check(MobileSession::rotate($next['refresh_token'])['tokens'] === $third, 'Latest generation retry failed');
    echo "PASS: explicit logout, successor logout, user-wide revocation and successor rotation cannot revive old sessions\n";

    foreach (['expired_access', 'expired_refresh', 'wrong_user', 'wrong_access_hash', 'wrong_refresh_hash', 'missing_successor'] as $failure) {
        [$old, $next] = issuedAndRotated();
        switch ($failure) {
            case 'expired_access': XF::$db->rows[2]['access_expires_date'] = XF::$time; break;
            case 'expired_refresh': XF::$db->rows[2]['refresh_expires_date'] = XF::$time; break;
            case 'wrong_user': XF::$db->rows[2]['user_id'] = 8; break;
            case 'wrong_access_hash': XF::$db->rows[2]['access_token_hash'] = hash('sha256', 'different'); break;
            case 'wrong_refresh_hash': XF::$db->rows[2]['refresh_token_hash'] = hash('sha256', 'different'); break;
            case 'missing_successor': unset(XF::$db->rows[2]); break;
        }
        $rows = XF::$db->rows;
        check(MobileSession::rotate($old['refresh_token']) === null && XF::$db->rows === $rows, 'Invalid successor accepted: '.$failure);
    }
    foreach (['', 'ms_at_not-refresh', 'ms_rt_unknown'] as $invalid) {
        resetSessionTest(); check(MobileSession::rotate($invalid) === null && !XF::$db->rows, 'Invalid refresh accepted');
    }
    $old = MobileSession::issue(resetSessionTest());
    XF::$time += 2592000;
    check(MobileSession::rotate($old['refresh_token']) === null, 'Expired active refresh accepted');
    [$old, $next] = issuedAndRotated(); XF::$db->rows[1]['refresh_expires_date'] = XF::$time;
    check(MobileSession::rotate($old['refresh_token']) === null, 'Expired predecessor replay accepted');
    [$old, $next] = issuedAndRotated(); XF::$db->rows[1]['revoked_date'] = XF::$time + 1;
    check(MobileSession::rotate($old['refresh_token']) === null, 'Future revocation accepted');
    echo "PASS: successor identity/hash/expiry checks, unknown/expired refresh and future revocation\n";

    foreach (['banned', 'rejected', 'disabled', 'missing'] as $failure) {
        foreach ([false, true] as $retry) {
            if ($retry) [$old, $next] = issuedAndRotated();
            else $old = MobileSession::issue(resetSessionTest());
            if ($failure === 'missing') unset(XF::$users[7]);
            elseif ($failure === 'banned') XF::$users[7]->is_banned = true;
            else XF::$users[7]->user_state = $failure;
            $count = count(XF::$db->rows);
            check(MobileSession::rotate($old['refresh_token']) === null, 'Unavailable user accepted: '.$failure);
            check(count(XF::$db->rows) === $count, 'Unavailable user got new session');
        }
    }
    echo "PASS: banned, rejected, disabled and removed accounts cannot refresh or replay\n";

    $old = MobileSession::issue(resetSessionTest()); $rows = XF::$db->rows;
    XF::$db->failInsert = true;
    expectFailure(fn() => MobileSession::rotate($old['refresh_token']), 'Simulated insert failure');
    check(XF::$db->rows === $rows && XF::$db->rollbacks === 1, 'Failed issuance left old session revoked');
    XF::$db->failInsert = false;
    check(MobileSession::rotate($old['refresh_token']) !== null, 'Failed transaction prevented later retry');
    foreach (['', '   '] as $salt) {
        foreach ([false, true] as $retry) {
            if ($retry) [$old, $next] = issuedAndRotated();
            else $old = MobileSession::issue(resetSessionTest());
            $rows = XF::$db->rows; XF::$salt = $salt;
            expectFailure(fn() => MobileSession::rotate($old['refresh_token']), 'Mobile session refresh signing key is unavailable.');
            check(XF::$db->rows === $rows && XF::$db->rollbacks === 1, 'Missing salt changed stored session');
        }
    }
    echo "PASS: transaction rollback and empty signing key fail without invalidating a stored session\n";
    echo "ALL MOBILE SESSION RETRY TESTS PASSED\n";
}
