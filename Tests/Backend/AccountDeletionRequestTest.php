<?php
namespace XF\Entity {
    class User {
        public int $user_id = 9;
        public $Auth;
        public function authenticate($password) { return $password === 'fixture-password'; }
    }
}
namespace Ekitapligim\IosApi\Service {
    class MobileSession {
        public static array $revoked = [];
        public static function revokeUserSessions($id) { self::$revoked[] = $id; }
    }
    class AppleAuthorization {
        public static bool $linked = true;
        public static bool $available = false;
        public static int $attempts = 0;
        public static function hasAuthorization($id) { return self::$linked; }
        public static function revokeForUser($id) { self::$attempts++; return self::$available; }
    }
}
namespace Ekitapligim\MobileApi\Api\Controller {
    class AbstractMobileController {
        public array $input = [];
        protected function assertMobileWriteScope(): void {}
        protected function assertRegisteredApiUser(): \XF\Entity\User { return new \XF\Entity\User(); }
        protected function filter($key, $type) { return $this->input[$key] ?? ''; }
        protected function apiResult($value) { return $value; }
        protected function apiError($message, $code, $params = null, $status = 400) { return ['error' => $code, 'status' => $status]; }
    }
}
namespace {
    require __DIR__ . '/../../Backend/IosApi-addon/Api/Controller/AccountDeletionRequest.php';
    class DeletionController extends \Ekitapligim\IosApi\Api\Controller\AccountDeletionRequest {
        public int $existing = 0;
        public int $writes = 0;
        public int $mails = 0;
        protected function ensureDeletionRequestTable(): void {}
        protected function findPendingRequestId(int $userId): int { return $this->existing; }
        protected function recordDeletionRequest(\XF\Entity\User $user, string $reason, bool $verified): int { $this->writes++; return 17; }
        protected function sendDeletionRequestMail(\XF\Entity\User $user, string $reason, int $id): void { $this->mails++; }
    }
    function check(bool $condition, string $message): void { if (!$condition) { throw new \RuntimeException($message); } }
    $controller = new DeletionController();
    $first = $controller->actionPost();
    check($first['success'] && $first['apple_revocation_pending'], 'Apple outage remains pending');
    $controller->existing = 17;
    \Ekitapligim\IosApi\Service\AppleAuthorization::$available = true;
    $retry = $controller->actionPost();
    check($retry['already_pending'] && !$retry['apple_revocation_pending'], 'Repeated request retries Apple revocation');
    check(\Ekitapligim\IosApi\Service\MobileSession::$revoked === [9, 9], 'Re-login sessions revoked on repeat');
    check($controller->writes === 1 && $controller->mails === 1, 'Repeated request does not create or send duplicates');
    $controller->input['current_password'] = 'incorrect';
    check($controller->actionPost()['error'] === 'current_password_invalid', 'Bad password rejected');
    check(count(\Ekitapligim\IosApi\Service\MobileSession::$revoked) === 2, 'Failed reauthentication has no side effects');
    echo "Account deletion: 6 repeat, revocation, reauthentication and side-effect scenarios passed.\n";
}
