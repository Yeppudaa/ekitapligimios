<?php
namespace Ekitapligim\MobileApi\Api\Controller {
    class AbstractMobileController {
        public array $input = [];
        public bool $authorized = true;
        protected function assertMobileWriteScope(): void { if (!$this->authorized) { throw new \RuntimeException('Denied'); } }
        protected function assertRegisteredApiUser() { return (object) ['user_id' => 9]; }
        protected function filter($key, $type) { return $this->input[$key] ?? ''; }
        public function apiError($message, $code, ?array $params = null, $status = 400) {
            return ['error' => $code, 'status' => $status];
        }
        protected function apiSuccess($data) { return ['success' => true] + $data; }
        protected function app() { return new \DeviceTestApp(); }
    }
}
namespace {
    class XF { public static int $time = 123456; }
    class DeviceTestApp { public function db() { return DeviceTestDb::$instance; } }
    class DeviceTestDb {
        public static $instance;
        public array $writes = [];
        public function insert(...$args) { $this->writes[] = ['insert', $args]; }
        public function delete(...$args) { $this->writes[] = ['delete', $args]; }
    }
    require __DIR__ . '/../../Backend/IosApi-addon/Api/Controller/MeDeviceToken.php';
    function check($value, $message) { if (!$value) { throw new \RuntimeException($message); } }
    DeviceTestDb::$instance = $db = new DeviceTestDb();
    $controller = new \Ekitapligim\IosApi\Api\Controller\MeDeviceToken();
    foreach (['', '  '] as $token) {
        $controller->input = ['device_token' => $token];
        foreach (['actionPost', 'actionDelete'] as $action) {
            check($controller->$action() === ['error' => 'missing_device_token', 'status' => 400], 'Missing token must return HTTP 400, not TypeError');
        }
    }
    check(!$db->writes, 'Missing tokens do not modify registrations');
    $controller->input = ['device_token' => ' fixture-token '];
    check($controller->actionPost()['registered'], 'Existing registration contract preserved');
    check($db->writes[0][1][1] === ['user_id' => 9, 'device_token' => 'fixture-token', 'platform' => 'ios', 'created_at' => XF::$time], 'Registration ownership and timestamp preserved');
    check($controller->actionDelete()['unregistered'], 'Existing deletion contract preserved');
    check($db->writes[1][1] === ['xf_ios_device_tokens', 'device_token = ? AND user_id = ?', ['fixture-token', 9]], 'Deletion is constrained to the current user and exact token');
    $controller->authorized = false;
    try { $controller->actionDelete(); throw new \LogicException('Scope bypassed'); }
    catch (\RuntimeException $e) { check(!$e instanceof \LogicException, 'Write scope enforced'); }
    check(count($db->writes) === 2, 'Denied request does not modify registrations');
    echo "Device token: missing/blank POST and DELETE return 400; registration, ownership and write scope passed.\n";
}
