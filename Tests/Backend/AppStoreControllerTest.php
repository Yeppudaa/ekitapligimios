<?php
namespace XF\Entity { class User { public int $user_id = 11; public string $username = 'tester'; } }
namespace Ekitapligim\MobileApi\Api\Controller {
    class AbstractMobileController {
        public array $input = [];
        public bool $loggedIn = true;
        protected function assertMobileWriteScope(): void {}
        protected function assertRegisteredApiUser(): \XF\Entity\User {
            if (!$this->loggedIn) { throw new \RuntimeException('login required'); }
            return new \XF\Entity\User();
        }
        protected function filter($key, $type) { return $this->input[$key] ?? ''; }
        protected function apiResult($value) { return $value; }
        protected function apiError($message, $code, $params = null, $status = 400) { return ['error' => $code, 'status' => $status]; }
    }
}
namespace {
    require __DIR__ . '/Support/AppStoreTestHarness.php';
    require __DIR__ . '/../../Backend/IosApi-addon/Api/Controller/AppStoreVerify.php';
    require __DIR__ . '/../../Backend/IosApi-addon/Api/Controller/AppStoreNotifications.php';
    trait FixtureJws {
        public array $payloads = [];
        protected function decodeAndVerifyJws(string $jws): array {
            if (!isset($this->payloads[$jws])) { throw new \RuntimeException('Invalid signature'); }
            return ['payload' => $this->payloads[$jws]];
        }
    }
    class VerifyController extends \Ekitapligim\IosApi\Api\Controller\AppStoreVerify { use FixtureJws; }
    class NotificationController extends \Ekitapligim\IosApi\Api\Controller\AppStoreNotifications { use FixtureJws; }
    class RealVerifier extends \Ekitapligim\IosApi\Api\Controller\AppStoreVerify {
        public function decode(string $value): array { return $this->decodeAndVerifyJws($value); }
        public function acceptsEnvironment(string $value): bool { return $this->isAllowedEnvironment($value); }
    }
    $verify = new VerifyController();
    $verify->input = ['prepare_purchase' => true, 'account_name' => 'tester'];
    $prepared = $verify->actionPost();
    check($prepared['success'] && strlen($prepared['app_account_token']) === 36, 'Purchase preparation returns account UUID');
    check($verify->actionPost() === $prepared, 'Preparation retry returns same UUID');
    $verify->input['account_name'] = 'changed-account';
    check($verify->actionPost()['status'] === 409, 'Preparation rejects changed account');
    $verify->input['account_name'] = '';
    check($verify->actionPost()['status'] === 400, 'Preparation requires captured account');
    $verify->loggedIn = false;
    try { $verify->actionPost(); throw new \LogicException('Anonymous preparation accepted'); }
    catch (\RuntimeException $e) {}
    $verify->loggedIn = true;
    $transaction = purchaseFixture();
    $transaction['appAccountToken'] = $prepared['app_account_token'];
    $verify->payloads['transaction'] = $transaction;
    $verify->input = ['signed_transaction' => 'transaction', 'product_id' => $transaction['productId'], 'account_name' => 'tester'];
    check($verify->actionPost()['is_premium'], 'Verified purchase grants entitlement');
    $verify->input['account_name'] = 'other-account';
    check($verify->actionPost()['error'] === 'purchase_account_changed', 'Account changed while request suspended');
    $verify->input['account_name'] = 'tester';
    $verify->loggedIn = false;
    try { $verify->actionPost(); throw new \LogicException('Anonymous verification accepted'); }
    catch (\RuntimeException $e) {}
    $verify->loggedIn = true;
    $verify->input['signed_transaction'] = 'invalid';
    check($verify->actionPost()['error'] === 'transaction_verification_failed', 'Invalid transaction rejected');
    $verify->input['signed_transaction'] = 'transaction';
    $verify->payloads['transaction']['bundleId'] = 'other.app';
    check($verify->actionPost()['error'] === 'bundle_mismatch', 'Wrong bundle rejected');
    $verify->payloads['transaction'] = $transaction;
    $verify->payloads['transaction']['type'] = 'Consumable';
    check($verify->actionPost()['error'] === 'product_type_mismatch', 'Wrong product type rejected');
    $verify->payloads['transaction'] = $transaction;
    $verify->input['signed_renewal_info'] = 'renewal';
    $verify->payloads['renewal'] = ['signedDate' => XF::$time * 1000, 'environment' => 'Sandbox'];
    check($verify->actionPost()['error'] === 'renewal_mismatch', 'Unbound grace JWS rejected');
    unset($verify->input['signed_renewal_info']);
    XF::db()->lockAvailable = false;
    check($verify->actionPost()['status'] === 503, 'Lock timeout must be retryable');
    XF::db()->lockAvailable = true;
    XF::$groups->available = false;
    check($verify->actionPost()['status'] === 503, 'Incomplete XenForo permission delivery must retry');
    XF::$groups->available = true;

    $notification = new NotificationController();
    $notification->input = ['signedPayload' => 'notification'];
    $notification->payloads = ['notification' => ['notificationUUID' => 'codex-notification-1', 'notificationType' => 'REFUND',
        'data' => ['bundleId' => 'com.ekitapligim.app', 'environment' => 'Sandbox', 'signedTransactionInfo' => 'transaction']],
        'transaction' => $transaction + ['revocationDate' => XF::$time * 1000]];
    $notification->payloads['transaction']['signedDate'] += 1000;
    XF::db()->failWrite = true;
    check($notification->actionPost()['status'] === 503, 'Database failure asks Apple to retry');
    XF::db()->failWrite = false;
    check($notification->actionPost()['success'], 'Refund accepted after retry');
    check($notification->actionPost()['success'], 'Repeated notification idempotent');
    check(!$verify->actionPost()['is_premium'], 'API response uses saved refund, not replayed active receipt');
    $notification->input['signedPayload'] = 'invalid';
    check($notification->actionPost()['status'] === 400, 'Invalid signature rejected permanently');

    // Real parser: malformed/unsigned data is never accepted, even with a test environment.
    $real = new RealVerifier();
    foreach (['invalid', 'e30.e30.AA', str_repeat('a', 131073)] as $jws) {
        try { $real->decode($jws); throw new \LogicException('Unsigned JWS accepted'); }
        catch (\RuntimeException $e) {}
    }
    putenv('EKITAPLIGIM_APPSTORE_ENVIRONMENT=Both');
    check(!$real->acceptsEnvironment('Xcode'), 'Both never permits Xcode receipts');
    check($real->acceptsEnvironment('Production') && $real->acceptsEnvironment('Sandbox'), 'TestFlight and production accepted with Both');
    putenv('EKITAPLIGIM_APPSTORE_ENVIRONMENT');
    echo "App Store controllers: authentication, binding, verification, permission delivery and retry scenarios passed.\n";
}
