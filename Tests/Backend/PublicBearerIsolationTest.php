<?php
namespace XF\Entity { class User {
    public function __construct(public int $user_id = 0, public bool $is_banned = false, public string $user_state = 'valid') {}
} }
namespace XF\Mvc { class ParameterBag {} }
namespace Ekitapligim\IosApi\XF\Extension {
    class XFCP_AbstractMobileController {
        public $request;
        public function preDispatch($action, \XF\Mvc\ParameterBag $params) { return \XF::visitor()->user_id; }
    }
}
namespace Ekitapligim\IosApi\Service { class MobilePresence { public static function touch($user): void {} } }
namespace Ekitapligim\MobileApi\Service { class MobileSession {
    public static function bearerToken($header) { return preg_match('/^Bearer (.*)$/', $header, $m) ? $m[1] : ''; }
    public static function userIdForAccessToken($token) { return $token === 'valid-mobile-token' ? 8 : 0; }
} }
namespace {
    class XF {
        public static $visitor;
        public static function setVisitor($user) { self::$visitor = $user; }
        public static function visitor() { return self::$visitor; }
        public static function repository($name) { return new class { public function getGuestUser() { return new \XF\Entity\User(); } }; }
    }
    require __DIR__ . '/../../Backend/IosApi-addon/Pub/Controller/PublicEndpointTrait.php';
    require __DIR__ . '/../../Backend/IosApi-addon/XF/Extension/AbstractMobileController.php';
    class BearerController {
        use \Ekitapligim\IosApi\Pub\Controller\PublicEndpointTrait;
        public string $header = '';
        public $user;
        public function apply() { $this->applyMobileBearerVisitor(); }
        protected function getMobileAuthorizationHeader(): string { return $this->header; }
        public function em() { return $this; }
        public function find($type, $id) { return $this->user; }
    }
    $controller = new BearerController();
    foreach (['', 'Bearer expired', 'Bearer xf_user:8'] as $header) {
        XF::$visitor = new \XF\Entity\User(7);
        $controller->header = $header;
        $controller->apply();
        if (XF::$visitor->user_id !== 0) { throw new \RuntimeException('Web cookie authorized CSRF-exempt API'); }
    }
    $controller->header = 'Bearer valid-mobile-token';
    $controller->user = new \XF\Entity\User(8);
    $controller->apply();
    if (XF::$visitor->user_id !== 8) { throw new \RuntimeException('Valid bearer failed'); }
    foreach ([new \XF\Entity\User(8, true), new \XF\Entity\User(8, false, 'disabled'), null] as $user) {
        $controller->user = $user;
        $controller->apply();
        if (XF::$visitor->user_id !== 0) { throw new \RuntimeException('Ineligible bearer accepted'); }
    }
    class SharedController extends \Ekitapligim\IosApi\XF\Extension\AbstractMobileController {
        public $bearerUser;
        protected function applyMobileBearerVisitor() { if ($this->bearerUser) { \XF::setVisitor($this->bearerUser); } }
    }
    $shared = new SharedController();
    $shared->request = new class { public string $route = 'ios-api/v1/me'; public function getRoutePath() { return $this->route; } };
    XF::$visitor = new \XF\Entity\User(7);
    if ($shared->preDispatch('Index', new \XF\Mvc\ParameterBag()) !== 0) { throw new \RuntimeException('Shared iOS route accepted cookie'); }
    $shared->bearerUser = new \XF\Entity\User(8);
    if ($shared->preDispatch('Index', new \XF\Mvc\ParameterBag()) !== 8) { throw new \RuntimeException('Shared iOS bearer rejected'); }
    $shared->request->route = 'mobile-api/v1/me';
    XF::$visitor = new \XF\Entity\User(7);
    if ($shared->preDispatch('Index', new \XF\Mvc\ParameterBag()) !== 7) { throw new \RuntimeException('Android route unexpectedly changed'); }
    echo "Public API bearer isolation: 10 cookie, token, account, ban, inherited route and Android isolation scenarios passed.\n";
}
