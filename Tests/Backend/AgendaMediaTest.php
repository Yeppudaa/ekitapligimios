<?php
// Runs the shipping upload trait, serializer and protected image guard against isolated XF boundaries.
namespace XF\Mvc { class ParameterBag { public function __construct(public int $post_id = 9) {} } }
namespace XF\Attachment {
    class Manipulator {
        public function __construct($handler, $repo, $context, $hash) { \State::$hash = $hash; }
        public function canUpload(&$error) { $error = 'limit'; return !\State::$limit; }
        public function insertAttachmentFromUpload($upload, &$error) {
            \State::$inserts++;
            $error = 'upload failed';
            return \State::$uploadFails ? null : \State::$attachment;
        }
    }
}
namespace Ekitapligim\MobileApi\Service {
    class BookAgendaSerializer {
        public function post($post, $state = []) { return ['id' => (string) $post->post_id, 'message' => $post->message]; }
        public function viewerState(...$args) { return []; }
        protected function absolute(string $url): string { return $url; }
        protected function plainText(string $text): string { return trim(preg_replace('/\[\/?[^\]]+\]/', '', $text)); }
    }
}
namespace Ekitapligim\MobileApi\Api\Controller {
    class BookAgendaPost {
        protected function apiError($message, $code, $params, $status) { return ['error' => $code, 'status' => $status]; }
        protected function assertMobileScope() { \State::$scopeChecks++; }
        protected function repository($name) { return new \Repo(); }
        protected function setResponseType($type) { \State::$responseType = $type; }
        protected function view($class, $template, $params) { return ['view' => $class, 'image' => $params['attachment']->attachment_id]; }
    }
}
namespace {
    class XF {
        public static function visitor() { return new Visitor(); }
        public static function extendClass($class) { return $class; }
        public static function repository($name) { return new Repo(); }
        public static function db() { return new class { public function fetchAllColumn($sql, $params) { return State::$blocked; } }; }
        public static function em() { return new class {
            public function findByIds($type, $ids, $with = null) {
                same($with, null, 'TO_MANY attachments must not be joined by XF finder');
                return [9 => State::$post];
            }
        }; }
    }
    class Visitor {
        public int $user_id = 7;
        public function hasPermission($group, $name) { return !in_array($name, State::$denied, true); }
    }
    class Attachment {
        public int $attachment_id = 21, $content_id = 9, $width = 800, $height = 1200;
        public string $content_type = 'ek_social_post', $temp_hash = '';
        public object $Data;
        public function __construct() { $this->Data = new class { public function isDataAvailable() { return true; } }; }
        public function getDirectUrl() { return 'https://example.com/full.jpg'; }
        public function getThumbnailUrl() { return ''; }
        public function delete() { State::$deletes++; }
    }
    class Post {
        public int $post_id = 9, $user_id = 7;
        public string $message = 'A reading moment';
        public array $Attachments = [];
        public function canView() { return State::$visible; }
    }
    class Repo {
        public function getAttachmentHandler($type) { return new class {
            public function canManageAttachments($context) { return State::$manage; }
            public function getConstraints($context) { return ['size' => 1048576, 'extensions' => ['jpg', 'png'], 'count' => 4]; }
        }; }
        public function addAttachmentsToContent($posts, $type) { State::$hydrates++; }
        public function getPost($id) { return State::$visible ? State::$post : null; }
    }
    class Upload {
        public function isImage() { return !State::$invalidImage; }
        public function getImageType() { return IMAGETYPE_JPEG; }
        public function getFileSize() { return State::$bytes; }
    }
    class Creator {
        public function setMessage($message) { State::$post->message = $message; }
        public function setData($data) { State::$postData = $data; }
        public function setAttachmentHash($hash) { same($hash, State::$hash, 'Creator must receive server-owned upload hash'); }
        public function validate(&$errors) { $errors = ['invalid post']; return State::$valid; }
        public function save() {
            State::$saves++;
            if (State::$saveFails) throw new \RuntimeException('storage failure');
            State::$post->Attachments = [21 => State::$attachment];
            return State::$post;
        }
    }
    class State {
        public static array $denied = [], $blocked = [], $postData = [];
        public static bool $manage = true, $visible = true, $invalidImage = false, $limit = false,
            $valid = true, $uploadFails = false, $saveFails = false;
        public static int $bytes = 100, $inserts = 0, $saves = 0, $deletes = 0, $scopeChecks = 0, $hydrates = 0;
        public static string $hash = '', $responseType = '';
        public static Attachment $attachment;
        public static Post $post;
        public static function reset(): void {
            self::$denied = self::$blocked = self::$postData = [];
            self::$manage = self::$visible = self::$valid = true;
            self::$invalidImage = self::$limit = self::$uploadFails = self::$saveFails = false;
            self::$bytes = 100;
            self::$inserts = self::$saves = self::$deletes = self::$scopeChecks = self::$hydrates = 0;
            self::$hash = self::$responseType = '';
            self::$attachment = new Attachment(); self::$post = new Post();
        }
    }
    $root = dirname(__DIR__, 2) . '/Backend/IosApi-addon/';
    foreach (['Service/IgnoredUsers.php', 'Service/AgendaMediaSerializer.php', 'Api/Controller/UgcControllerTrait.php',
        'Api/Controller/AgendaMediaUploadTrait.php', 'Api/Controller/BookAgendaPost.php'] as $file) require_once $root . $file;
    class UploadHarness {
        use \Ekitapligim\IosApi\Api\Controller\AgendaMediaUploadTrait;
        public array $fields = ['message' => '', 'post_type' => 'standard', 'visibility' => 'public'];
        public object $request;
        public function __construct() { $this->request = new class { public function getFile(...$args) { return new Upload(); } }; }
        public function create() { return $this->createPostWithImage(); }
        public function capabilities() { return $this->mediaCapabilities(); }
        protected function filter($key, $type) { return $this->fields[$key] ?? ($type === 'uint' ? 0 : ''); }
        protected function assertMobileWriteScope() { State::$scopeChecks++; }
        protected function assertMobileScope() { State::$scopeChecks++; }
        protected function assertRegisteredApiUser() { return new Visitor(); }
        protected function assertPostFlooding($visitor) {}
        protected function assertBook($id) { return (object) ['author_canonical_id' => 4]; }
        protected function repository($name) { return new Repo(); }
        protected function service($name) { return new Creator(); }
        protected function apiResult($data) { return $data; }
        protected function apiError($message, $code, $params, $status) { return ['error' => $code, 'status' => $status]; }
    }
    class ImageHarness extends \Ekitapligim\IosApi\Api\Controller\BookAgendaPost {
        public function read(int $id = 21) { return $this->agendaImage(new \XF\Mvc\ParameterBag(), $id); }
    }
    $checks = 0;
    function same($actual, $expected, $message): void {
        global $checks; $checks++;
        if ($actual !== $expected) throw new \RuntimeException($message . ': ' . var_export($actual, true));
    }
    $upload = new UploadHarness();
    foreach (['view', 'create', 'upload'] as $permission) {
        State::reset(); State::$denied = [$permission];
        same($upload->create()['status'], 403, 'Denied permission must stop upload');
        same(State::$inserts, 0, 'Permission denial must not store a file');
        same(State::$saves, 0, 'Permission denial must not publish text');
    }
    State::reset(); State::$manage = false;
    same($upload->create()['status'], 403, 'Attachment handler permission must be enforced');
    State::reset(); State::$invalidImage = true;
    same($upload->create()['error'], 'invalid_image', 'Fake image must fail');
    same(State::$inserts, 0, 'Invalid image must not reach storage');
    State::reset(); State::$bytes = 8388609;
    same($upload->create()['error'], 'invalid_image', 'Oversized image must fail');
    State::reset(); State::$valid = false;
    same($upload->create()['error'], 'validation_error', 'Invalid post must fail before storing image');
    same(State::$inserts, 0, 'Validation failure leaked a file');
    State::reset(); State::$uploadFails = true;
    same($upload->create()['error'], 'upload_failed', 'Storage failure must be explicit');
    same(State::$saves, 0, 'Failed image must not publish text alone');
    State::reset(); State::$saveFails = true;
    try { $upload->create(); throw new \LogicException('Save should fail'); } catch (\RuntimeException $e) {}
    same(State::$deletes, 1, 'Failed post must delete its pending attachment');
    State::reset();
    $result = $upload->create();
    same($result['success'], true, 'Photo-only standard post should publish');
    same(State::$saves, 1, 'Photo must create exactly one post');
    same(State::$deletes, 0, 'Successful attachment must be retained');
    same(strlen(State::$hash), 32, 'Server hash must use cryptographic random bytes');
    same($result['post']['attachments'][0]['protected_image'], true, 'Created photo must support bearer reads');
    same($result['post']['attachments'][0]['height'], 1200, 'Portrait dimensions must survive');
    same(State::$hydrates, 1, 'Fresh attachment relation must be hydrated');
    $upload->fields['post_type'] = 'review';
    State::reset(); same($upload->create()['error'], 'book_required', 'Existing book requirement must remain');
    $upload->fields['book_thread_id'] = 10;
    State::reset(); $upload->create();
    same(State::$postData['author_id'], 4, 'Book author derivation must remain');
    State::reset(); $caps = $upload->capabilities();
    same($caps['image_upload_version'], 1, 'Upload support must be versioned');
    same($caps['maximum_bytes'], 1048576, 'Server attachment size restriction must survive');
    State::$denied = ['upload']; same($upload->capabilities()['can_upload_images'], false, 'Capabilities must not invent permissions');

    State::reset(); State::$post->Attachments = [21 => State::$attachment];
    $read = new ImageHarness();
    same($read->read()['image'], 21, 'Authorized image should use raw renderer');
    same(State::$responseType, 'raw', 'Image response must not use JSON');
    same($read->read(22)['status'], 404, 'Cannot read another post attachment ID');
    State::$attachment->content_id = 10; same($read->read()['status'], 404, 'Mismatched content association must fail');
    State::$attachment->content_id = 9; State::$attachment->temp_hash = 'pending';
    same($read->read()['status'], 404, 'Unassociated attachment must not be readable');
    State::$attachment->temp_hash = ''; State::$blocked = [7];
    same($read->read()['status'], 404, 'Blocked author image must not be readable');
    State::$blocked = []; State::$visible = false;
    same($read->read()['status'], 404, 'Private or deleted post image must not be readable');
    State::$visible = true; State::$denied = ['view'];
    same($read->read()['status'], 404, 'Agenda view permission must also govern image reads');

    State::reset();
    State::$post->message = 'Hello [IMG]https://example.com/a.jpg[/IMG] [IMG]https://example.com/a.jpg[/IMG] [IMG]http://unsafe.example/a[/IMG] [ATTACH]21[/ATTACH]';
    $serializer = new \Ekitapligim\IosApi\Service\AgendaMediaSerializer();
    $result = $serializer->withMedia(State::$post, ['id' => '9']);
    same(count($result['attachments']), 1, 'Inline images must be secure and deduplicated');
    same($result['message'], 'Hello', 'Image and attachment markup must not leak into text');
    same($result['attachments'][0]['protected_image'], false, 'External images must not receive bearer');
    State::$post->Attachments = [21 => State::$attachment];
    $reply = new class {
        public array $payload = ['items' => [['id' => '9', 'viewer' => ['can_edit' => false]]], 'post' => ['id' => '9']];
        public function getApiResult() { return $this; }
        public function getResult() { return $this->payload; }
        public function setResult($payload) { $this->payload = $payload; }
    };
    $serializer->decorateReply($reply);
    same($reply->payload['items'][0]['attachments'][0]['protected_image'], true, 'Feed reply must contain protected image metadata');
    same($reply->payload['post']['attachments'][0]['id'], '21', 'Detail reply must contain the same attachment');
    same($reply->payload['items'][0]['viewer']['can_edit'], false, 'Media decorator must preserve existing viewer denial');
    same($serializer->decorateReply(['error' => 'no_permission']), ['error' => 'no_permission'], 'Error reply must pass through unchanged');
    echo "Agenda media backend: $checks checks passed.\n";
}
