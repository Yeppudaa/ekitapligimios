<?php
// Load only the real XF router and cache sorter. No configured app, DB or HTTP calls.
$source = getenv('CHAT_SYNC_XF_SOURCE_ROOT') ?: 'C:/xampp/htdocs/ekitapligim/src';
spl_autoload_register(static function ($class) use ($source) {
    $file = $source . '/' . str_replace('\\', '/', $class) . '.php';
    if (is_file($file)) require_once $file;
});
if (!class_exists('XF\\Repository\\RouteRepository')) throw new RuntimeException('Local XF source required.');
class IosRouteRepository extends \XF\Repository\RouteRepository {
    public function __construct(private array $rows) {}
    public function finder($identifier) { return new class($this->rows) {
        public function __construct(private array $rows) {}
        public function where($field, $value) { $this->rows = array_filter($this->rows, fn($r) => $r->$field === $value); return $this; }
        public function with($unused) { return $this; }
        public function whereAddOnActive() { return $this; }
        public function order($fields) { usort($this->rows, fn($a, $b) => [$a->route_prefix, $a->sub_name] <=> [$b->route_prefix, $b->sub_name]); return $this; }
        public function fetch() { return $this->rows; }
    }; }
}
class IosRouteRequest extends \XF\Http\Request {
    public function __construct(private string $method) {}
    public function getRequestMethod() { return $this->method; }
}
function router(bool $legacy = false) {
    $rows = [];
    foreach (simplexml_load_file(dirname(__DIR__, 2) . '/Backend/IosApi-addon/_data/routes.xml')->route as $route) {
        $row = (object) ['route_type'=>'', 'route_prefix'=>'', 'sub_name'=>'', 'format'=>'', 'controller'=>'',
            'action_prefix'=>'', 'context'=>'', 'build_class'=>'', 'build_method'=>'', 'AddOn'=>null];
        foreach ($route->attributes() as $key=>$value) $row->$key = (string)$value;
        if ($legacy) $row->sub_name = ['chat-message-detail'=>'chat-message', 'chat-message-reactions'=>'chat-reactions'][$row->sub_name] ?? $row->sub_name;
        $rows[] = $row;
    }
    return new \XF\Mvc\Router(null, (new IosRouteRepository($rows))->getRouteCacheData('public'));
}
$checks = 0;
function check($condition, $label) { global $checks; if (!$condition) throw new RuntimeException($label); $checks++; }
$router = router();
$paths = ['rooms'=>['Ekitapligim\\MobileApi:ChatRooms', null],
    'rooms/1/messages'=>['Ekitapligim\\IosApi:ChatMessages', null],
    'rooms/1/messages/81'=>['Ekitapligim\\IosApi:ChatMessages', '81'],
    'rooms/1/messages/81/reactions'=>['Ekitapligim\\IosApi:ChatReactions', '81']];
foreach ($paths as $path=>[$controller, $messageId]) foreach (['get','post'] as $method) foreach (['','/'] as $trailing) {
    $match = $router->routeToController('ios-api/v1/chat/'.$path.$trailing, new IosRouteRequest($method));
    check($match->getController() === $controller, "$method $path controller");
    check($match->getAction() === 'index', "$method $path action");
    if ($messageId) check((string)$match->getParams()['message_id'] === $messageId, "$path message parameter");
    if (str_contains($path, 'rooms/1')) check((string)$match->getParams()['room_id'] === '1', "$path room parameter");
}
$old = router(true)->routeToController('ios-api/v1/chat/rooms/1/messages/81', new IosRouteRequest('get'));
check($old->getAction() !== 'index', 'Legacy message route shadowing must be reproduced');
echo json_encode(['ok'=>true, 'checks'=>$checks, 'legacy_shadowing_reproduced'=>true,
    'network_requests'=>0, 'db_connections'=>0, 'actual_classes'=>['XF\\Repository\\RouteRepository','XF\\Mvc\\Router']], JSON_PRETTY_PRINT).PHP_EOL;
