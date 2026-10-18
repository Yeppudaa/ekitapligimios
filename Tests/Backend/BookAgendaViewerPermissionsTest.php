<?php
// Exercise the real iOS read wrappers and UGC decorator against isolated XF boundaries.
namespace XF\Mvc {
    class ParameterBag { public function __construct(public int $post_id = 12) {} }
}
namespace Ekitapligim\MobileApi\Api\Controller {
    class BookAgenda {
        public function actionGet() { return \XF::$upstream; }
    }
    class BookAgendaComments {
        public function actionGet(\XF\Mvc\ParameterBag $params) { return \XF::$upstream; }
    }
    class BookAgendaPost {
        public function actionGet(\XF\Mvc\ParameterBag $params) { return \XF::$upstream; }
        protected function apiError($message, $code, $params, $status) { return ['error' => $code, 'status' => $status]; }
    }
}
namespace {
    class XF {
        public static int $viewerId = 7;
        public static array $ignored = [];
        public static $upstream;
        public static function visitor() { return (object) ['user_id' => self::$viewerId]; }
        public static function db() { return new class {
            public function fetchAllColumn($sql, $params) { return XF::$ignored; }
        }; }
    }
    final class AgendaResult {
        public function __construct(private array $payload) {}
        public function getResult() { return $this->payload; }
        public function setResult(array $payload) { $this->payload = $payload; }
    }
    final class AgendaReply {
        private AgendaResult $result;
        public function __construct(array $payload) { $this->result = new AgendaResult($payload); }
        public function getApiResult() { return $this->result; }
    }
    $root = dirname(__DIR__, 2) . '/Backend/IosApi-addon/';
    foreach (['Service/IgnoredUsers.php', 'Api/Controller/UgcControllerTrait.php', 'Api/Controller/BookAgenda.php',
        'Api/Controller/BookAgendaPost.php', 'Api/Controller/BookAgendaComments.php'] as $file) require_once $root . $file;

    $checks = 0;
    function same($actual, $expected, string $message): void {
        global $checks;
        $checks++;
        if ($actual !== $expected) throw new \RuntimeException($message);
    }
    function payload(array $data, $controller, bool $hasParams = false): array {
        XF::$upstream = new AgendaReply($data);
        $reply = $hasParams ? $controller->actionGet(new \XF\Mvc\ParameterBag()) : $controller->actionGet();
        return $reply->getApiResult()->getResult();
    }
    $feed = new \Ekitapligim\IosApi\Api\Controller\BookAgenda();
    $detail = new \Ekitapligim\IosApi\Api\Controller\BookAgendaPost();
    $comments = new \Ekitapligim\IosApi\Api\Controller\BookAgendaComments();

    // A signed-in author can still be denied by the entity; denial must survive decoration.
    $ownerDenied = ['id' => '12', 'actor' => ['id' => '7'], 'viewer' => [
        'can_react' => true, 'can_comment' => false, 'can_edit' => false, 'can_delete' => false,
    ]];
    $data = payload(['items' => [$ownerDenied], 'capabilities' => ['can_create' => false]], $feed);
    same($data['can_create'], false, 'Authentication bypassed create permission');
    same($data['capabilities']['canCreate'], false, 'Create alias bypassed permission');
    same($data['items'][0]['viewer']['can_edit'], false, 'Ownership bypassed entity edit denial');
    same($data['items'][0]['viewer']['can_delete'], false, 'Ownership bypassed entity delete denial');
    same($data['items'][0]['viewer']['canEdit'], false, 'Edit alias bypassed entity denial');
    same($data['items'][0]['viewer']['canComment'], false, 'Comment denial was lost');
    same($data['items'][0]['viewer']['canReact'], true, 'Reaction permission was lost');

    // Moderators' permitted actions on other authors must be retained, too.
    $otherAllowed = ['id' => '13', 'actor' => ['id' => '8'], 'viewer' => [
        'can_edit' => true, 'can_delete' => true, 'can_comment' => true, 'following_actor' => true,
    ]];
    $data = payload(['items' => [$otherAllowed], 'capabilities' => ['can_create' => true, 'can_upload' => false]], $feed);
    same($data['canCreate'], true, 'Create permission was lost');
    same($data['items'][0]['viewer']['canEdit'], true, 'Non-owner edit permission was lost');
    same($data['items'][0]['viewer']['canDelete'], true, 'Non-owner delete permission was lost');
    same($data['items'][0]['viewer']['canComment'], true, 'Comment permission was lost');
    same($data['items'][0]['viewer']['followingActor'], true, 'Follow state was lost');
    same($data['capabilities']['can_upload'], false, 'Unrelated capability changed');

    // Missing rights cannot be reconstructed from the author's identity.
    $missingViewer = ['id' => '14', 'actor' => ['id' => '7']];
    $data = payload(['items' => [$missingViewer]], $feed);
    same($data['items'][0], $missingViewer, 'Ownership fabricated absent viewer permissions');
    same(array_key_exists('can_create', $data), false, 'Absent create permission was fabricated');
    same(array_key_exists('capabilities', $data), false, 'Absent capabilities were fabricated');

    // Nested detail comments and both supported collection names use the same source permissions.
    $data = payload(['post' => $ownerDenied + ['comments' => [$ownerDenied, $otherAllowed]]], $detail, true);
    same($data['post']['viewer']['canEdit'], false, 'Detail edit denial changed');
    same($data['post']['comments'][0]['viewer']['canDelete'], false, 'Nested comment denial changed');
    same($data['post']['comments'][1]['viewer']['canEdit'], true, 'Nested moderator permission changed');
    same(array_key_exists('canCreate', $data), false, 'Detail reply fabricated feed create capability');
    $data = payload(['items' => [$ownerDenied], 'comments' => [$otherAllowed]], $comments, true);
    same($data['items'][0]['viewer']['canEdit'], false, 'Comment item denial changed');
    same($data['comments'][0]['viewer']['canEdit'], true, 'Comments collection permission changed');

    // Existing snake-case permission is authoritative when stale aliases conflict.
    $conflicting = $ownerDenied;
    $conflicting['viewer']['canEdit'] = true;
    $data = payload(['items' => [$conflicting], 'canCreate' => true, 'capabilities' => ['can_create' => false]], $feed);
    same($data['items'][0]['viewer']['canEdit'], false, 'Stale item alias bypassed denial');
    same($data['canCreate'], false, 'Stale top-level alias bypassed capability denial');
    $data = payload(['items' => [['viewer' => ['canEdit' => false, 'canDelete' => true]]], 'canCreate' => false], $feed);
    same($data['items'][0]['viewer']['can_edit'], false, 'Camel-case denial was lost');
    same($data['items'][0]['viewer']['can_delete'], true, 'Camel-case permission was lost');
    same($data['capabilities']['can_create'], false, 'Camel-case create denial was lost');

    // Decorating permissions must retain ignored-member filtering in every read wrapper.
    XF::$ignored = [8];
    $data = payload(['items' => [$otherAllowed, $ownerDenied]], $feed);
    same(array_column($data['items'], 'id'), ['12'], 'Feed exposed ignored author');
    $data = payload(['items' => [$otherAllowed, $ownerDenied]], $comments, true);
    same(array_column($data['items'], 'id'), ['12'], 'Comments exposed ignored author');
    $data = payload(['post' => $ownerDenied + ['comments' => [$otherAllowed, $ownerDenied]]], $detail, true);
    same(array_column($data['post']['comments'], 'id'), ['12'], 'Nested comments exposed ignored author');
    XF::$upstream = new AgendaReply(['post' => $otherAllowed]);
    same($detail->actionGet(new \XF\Mvc\ParameterBag()), ['error' => 'content_not_found', 'status' => 404], 'Ignored post detail was exposed');

    XF::$upstream = ['error' => 'no_permission', 'status' => 403];
    same($feed->actionGet(), XF::$upstream, 'Upstream error reply was altered');
    XF::$viewerId = 0;
    $guest = ['items' => [$ownerDenied], 'capabilities' => ['can_create' => false]];
    same(payload($guest, $feed), $guest, 'Guest permission payload was altered');
    echo "Book Agenda viewer permissions: {$checks} permission, alias, nested-comment, ignored-member and error checks passed.\n";
}
