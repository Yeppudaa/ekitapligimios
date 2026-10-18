<?php
// Execute the real read-only endpoint against isolated authentication, catalog and entity boundaries.
namespace XF\Mvc { class ParameterBag {} }
namespace XF\Entity {
    class User {
        public function __construct(public int $user_id = 7, public string $username = 'Reader') {}
    }
    class Thread {
        public string $discussion_state = 'visible';
        public bool $viewable = true;
        public bool $replyable = true;
        public function __construct(public int $thread_id, public string $title = 'Audio book') {}
        public function canView() { return $this->viewable; }
        public function canReply() { return $this->replyable; }
    }
    class Post {
        public int $user_id = 7;
        public int $position = 1;
        public string $message_state = 'visible';
        public string $message = 'My audio comment';
        public bool $viewable = true;
        public bool $editable = false;
        public bool $deletable = false;
        public ?User $User;
        public function __construct(public int $post_id, public int $post_date, public ?Thread $Thread) {
            $this->User = new User();
        }
        public function canView() { return $this->viewable; }
        public function canEdit() { return $this->editable; }
        public function canDelete($mode) {
            if ($mode !== 'soft') throw new \RuntimeException('Unexpected delete mode');
            return $this->deletable;
        }
    }
}
namespace EKitapligim\AudioBooks\Repository {
    if (!in_array('--without-catalog', $argv, true)) { class Catalog {} }
    if (!in_array('--without-profile-library', $argv, true)) {
        class ProfileLibrary {
            public function comments($visitor): array {
                \XF::$events[] = 'comments:' . $visitor->user_id;
                \XF::$profileCalls++;
                // Model the canonical repository boundary: only published, permitted audio thread IDs.
                $rows = [];
                foreach (\XF::$sourcePosts AS $post) {
                    if ($post->Thread && in_array($post->Thread->thread_id, \XF::$permittedAudioIds, true)
                        && $post->user_id === $visitor->user_id && $post->position > 0
                        && $post->message_state === 'visible' && $post->canView()) {
                        $rows[] = ['kind' => 'comment', 'date' => $post->post_date, 'content' => $post];
                    }
                }
                return array_merge($rows, \XF::$extraRows);
            }
        }
    }
}
namespace Ekitapligim\MobileApi\Api\Controller {
    class AbstractMobileController {
        public object $request;
        public function __construct() {
            $this->request = new class {
                public function getRequestMethod() { return \XF::$requestMethod; }
            };
        }
        protected function assertMobileScope($scope = 'thread:read'): void {
            \XF::$events[] = 'scope:' . $scope;
            if (!\XF::$scopeAllowed) throw new \RuntimeException('no_permission', 403);
        }
        protected function assertRegisteredApiUser(): \XF\Entity\User {
            \XF::$events[] = 'authentication';
            if (!\XF::$visitor->user_id) throw new \RuntimeException('login_required', 401);
            return \XF::$visitor;
        }
        protected function app() {
            return new class {
                public function addOnManager() { return $this; }
                public function getById($id) {
                    if ($id !== 'EKitapligim/AudioBooks') throw new \RuntimeException('Wrong add-on');
                    \XF::$events[] = 'addon';
                    if (!\XF::$addonInstalled) return null;
                    return new class { public function isActive() { return \XF::$addonActive; } };
                }
            };
        }
        protected function repository($name) {
            if ($name !== 'EKitapligim\\AudioBooks:ProfileLibrary') throw new \RuntimeException('Generic comment history was used');
            return new \EKitapligim\AudioBooks\Repository\ProfileLibrary();
        }
        protected function filter($key, $type) { return max(0, (int) (\XF::$query[$key] ?? 0)); }
        protected function mobileUserRolePayload($user) { return ['is_premium' => true, 'role_type' => 'premium']; }
        protected function apiResult($data) { return $data; }
        protected function apiError($message, $code, $params, $status) { return ['error' => $code, 'status' => $status]; }
        protected function paginationMeta($page, $perPage, $total) {
            return ['page' => $page, 'per_page' => $perPage, 'perPage' => $perPage,
                'total' => $total, 'pages' => (int) ceil($total / $perPage)];
        }
        protected function notFound() { return ['status' => 404]; }
    }
}
namespace {
    class XF {
        public static \XF\Entity\User $visitor;
        public static bool $scopeAllowed = true;
        public static bool $addonInstalled = true;
        public static bool $addonActive = true;
        public static int $profileCalls = 0;
        public static array $events = [];
        public static array $query = [];
        public static array $sourcePosts = [];
        public static array $extraRows = [];
        public static array $permittedAudioIds = [100];
        public static string $requestMethod = 'GET';
    }
    $root = dirname(__DIR__, 2) . '/Backend/IosApi-addon/';
    require $root . 'Api/Controller/MeAudioComments.php';
    require $root . 'Pub/Controller/PublicEndpointTrait.php';
    require $root . 'Pub/Controller/MeAudioComments.php';
    $checks = 0;
    function same($actual, $expected, string $message): void {
        global $checks;
        $checks++;
        if ($actual !== $expected) throw new \RuntimeException($message . ': ' . json_encode($actual));
    }
    function post(int $id, int $date = 100, int $threadId = 100): \XF\Entity\Post {
        return new \XF\Entity\Post($id, $date, new \XF\Entity\Thread($threadId));
    }
    function rejects(callable $action, int $code, string $message): void {
        try { $action(); } catch (\RuntimeException $error) {
            same($error->getCode(), $code, $message);
            return;
        }
        throw new \RuntimeException($message);
    }
    XF::$visitor = new \XF\Entity\User();
    $endpoint = new \Ekitapligim\IosApi\Pub\Controller\MeAudioComments();

    if (in_array('--without-catalog', $argv, true) || in_array('--without-profile-library', $argv, true)) {
        same($endpoint->actionGet(), ['error' => 'audio_unavailable', 'status' => 503], 'Missing dependency must fail explicitly');
        same(XF::$profileCalls, 0, 'Unavailable repository was called');
        echo "Audio comment missing-dependency checks: {$checks} passed.\n";
        exit;
    }

    XF::$visitor = new \XF\Entity\User(0);
    rejects(fn () => $endpoint->actionGet(), 401, 'Guest request must require authentication');
    same(XF::$events, ['scope:user:read', 'authentication'], 'Catalog touched before authentication');
    same(XF::$profileCalls, 0, 'Guest accessed personal comments');
    XF::$visitor = new \XF\Entity\User();
    XF::$events = [];
    XF::$scopeAllowed = false;
    rejects(fn () => $endpoint->actionGet(), 403, 'Scope denial was ignored');
    same(XF::$events, ['scope:user:read'], 'Denied scope accessed user or catalog');
    XF::$scopeAllowed = true;

    foreach (['addonInstalled', 'addonActive'] AS $flag) {
        XF::${$flag} = false;
        same($endpoint->actionGet(), ['error' => 'audio_unavailable', 'status' => 503], 'Inactive/missing add-on must fail explicitly');
        same(XF::$profileCalls, 0, 'Unavailable add-on accessed comments');
        XF::${$flag} = true;
    }

    XF::$events = [];
    $empty = $endpoint->actionGet();
    same(XF::$events, ['scope:user:read', 'authentication', 'addon', 'comments:7'], 'Incorrect boundary or identity');
    same($empty['scope'], 'audio', 'Audio scope marker is required');
    same($empty['comments'], [], 'Empty history contains fabricated data');
    same($empty['items'], [], 'Empty item alias contains fabricated data');
    same($empty['pagination']['total'], 0, 'Empty total is wrong');
    same($empty['pagination']['page'], 1, 'Empty history must retain the requested first page');
    same($empty['pagination']['pages'], 1, 'Empty history must satisfy the native page contract');
    same($empty['pagination']['per_page'], 30, 'Default page size changed');

    $first = post(11, 300); $first->position = 0;
    $other = post(12, 300); $other->user_id = 8;
    $deleted = post(13, 300); $deleted->message_state = 'deleted';
    $postHidden = post(14, 300); $postHidden->viewable = false;
    $threadHidden = post(15, 300); $threadHidden->Thread->viewable = false;
    $threadDeleted = post(16, 300); $threadDeleted->Thread->discussion_state = 'deleted';
    $threadMissing = post(17, 300); $threadMissing->Thread = null;
    $valid = post(10, 100); $valid->editable = true; $valid->Thread->replyable = false;
    XF::$sourcePosts = [$valid, post(20, 200), post(21, 200), post(30, 400, 200), post(31, 400, 300),
        $first, $other, $deleted, $postHidden, $threadHidden, $threadDeleted];
    // Stale/invalid canonical results cannot bypass per-request ownership and entity checks.
    XF::$extraRows = array_map(fn ($p) => ['content' => $p],
        [$first, $other, $deleted, $postHidden, $threadHidden, $threadDeleted, $threadMissing, $valid]);
    XF::$extraRows[] = ['content' => null];
    XF::$query = ['page' => 1, 'per_page' => 2];
    $page1 = $endpoint->actionGet();
    same(array_column($page1['comments'], 'id'), ['21', '20'], 'Mixed book, ownership, visibility or stable ordering failed');
    same($page1['items'], $page1['comments'], 'Collection aliases diverged');
    same($page1['pagination'], ['page' => 1, 'per_page' => 2, 'perPage' => 2, 'total' => 3, 'pages' => 2], 'Hidden posts affected pagination');
    XF::$query['page'] = 2;
    $page2 = $endpoint->actionGet();
    same(array_column($page2['comments'], 'id'), ['10'], 'Second page lost or repeated entries');
    $item = $page2['comments'][0];
    same($item['thread_id'], 100, 'Native audio destination ID changed');
    same($item['thread_title'], 'Audio book', 'Thread title missing');
    same($item['threadTitle'], 'Audio book', 'Title alias missing');
    same($item['user_id'], 7, 'Author ID wrong');
    same($item['username'], 'Reader', 'Author name wrong');
    same($item['post_id'], 10, 'Post ID wrong');
    same($item['post_date'], 100, 'Date wrong');
    same($item['message'], 'My audio comment', 'Comment text changed');
    same($item['message_parsed'], $item['message'], 'Message alias diverged');
    same($item['can_edit'], true, 'Entity edit grant lost');
    same($item['can_delete'], false, 'Ownership fabricated delete permission');
    same($item['can_reply'], false, 'Entity reply denial lost');
    same($item['is_premium_author'], true, 'Premium author metadata lost');
    same($item['role_type'], 'premium', 'Role metadata lost');
    XF::$query = ['page' => 99, 'per_page' => 2];
    $pastEnd = $endpoint->actionGet();
    same($pastEnd['comments'], [], 'Out-of-range page repeats history');
    same($pastEnd['pagination']['total'], 3, 'Out-of-range page changed total');
    XF::$query = ['page' => 0, 'per_page' => 500];
    $bounded = $endpoint->actionGet();
    same($bounded['pagination']['page'], 1, 'Page lower bound failed');
    same($bounded['pagination']['per_page'], 50, 'Page size cap failed');
    XF::$query = ['per_page' => 1];
    same(count($endpoint->actionGet()['comments']), 1, 'Minimum page size failed');
    XF::$query = [];
    XF::$sourcePosts = []; XF::$extraRows = [];
    $fallbackAuthor = post(40); $fallbackAuthor->User = null;
    XF::$sourcePosts = [$fallbackAuthor];
    same($endpoint->actionGet()['comments'][0]['username'], 'Reader', 'Missing relation must use authenticated owner');

    foreach (['POST', 'PUT', 'PATCH', 'DELETE'] AS $method) {
        XF::$requestMethod = $method;
        $before = XF::$profileCalls;
        same($endpoint->actionIndex(new \XF\Mvc\ParameterBag()), ['status' => 404], 'Mutation method was accepted');
        same(XF::$profileCalls, $before, 'Mutation method accessed personal data');
    }
    XF::$requestMethod = 'HEAD';
    same($endpoint->actionIndex(new \XF\Mvc\ParameterBag())['scope'], 'audio', 'HEAD should use the read-only action');
    $routes = simplexml_load_file($root . '_data/routes.xml');
    $matches = $routes->xpath('/routes/route[@format="v1/me/audio-comments"]');
    same(count($matches), 1, 'New route missing or duplicated');
    same((string) $matches[0]['controller'], 'Ekitapligim\\IosApi:MeAudioComments', 'Route points outside iOS controller');
    echo "Audio comment endpoint: {$checks} authentication, audio boundary, ownership, visibility, pagination and read-only checks passed.\n";
}
