<?php
// Executes the real controller permission/validation paths with isolated XF services.
namespace XF\Mvc {
    class ParameterBag { public function __construct(public int $room_id = 7, public int $message_id = 10) {} }
}
namespace XF\Mvc\Reply {
    class Exception extends \RuntimeException {
        public function __construct(public array $reply) { parent::__construct($reply['error']); }
    }
}
namespace XF\Entity {
    class User {
        public bool $use = true, $muted = false, $sanctioned = false;
        public int $user_id = 1;
        public function canUseSiropuChat() { return $this->use; }
        public function isBannedSiropuChat() { return false; }
        public function isMutedSiropuChat() { return $this->muted; }
        public function isSanctionedSiropuChat() { return $this->sanctioned; }
        public function siropuChatGetRoomSanction($id) { return $this->sanctioned; }
    }
}
namespace Siropu\Chat\Entity {
    class Room {
        public int $room_id = 7;
        public bool $readOnly = false, $locked = false;
        public function isReadOnly() { return $this->readOnly; }
        public function isLocked(&$error = null) { return $this->locked; }
        public function isJoined() { return true; }
    }
    class Message {
        public int $message_id = 10, $message_room_id = 7, $message_user_id = 2;
        public string $message_type = 'chat';
        public bool $visible = true, $quote = true, $react = true, $ignored = false;
        public $User = null, $Room;
        public string $message_username = 'Test', $message_bot_name = '';
        public int $message_date = 1, $message_like_count = 0;
        public array $reactions = [];
        private ?int $cachedReaction = null;
        public function __construct() { $this->Room = new Room(); }
        public function getMessage() { return 'Fixture'; }
        public function isBot() { return false; }
        public function isAnnouncement() { return false; }
        public function isEdited() { return false; }
        public function isLiked() { return false; }
        public function getVisitorReactionId() {
            return $this->cachedReaction ??= (int) (\XF::$repository->selections[\XF::visitor()->user_id] ?? 0);
        }
        public function clearCache($relation) {
            if ($relation !== 'Reactions') throw new \RuntimeException('Unexpected cache cleared');
            $this->cachedReaction = null;
        }
        public function canView() { return $this->visible; }
        public function isPastJoinTime() { return $this->visible; }
        public function isIgnored() { return $this->ignored; }
        public function isIgnoredUser() { return false; }
        public function canViewContent() { return $this->visible; }
        public function canQuote() { return $this->quote; }
        public function canReact(&$error = null) { $this->getVisitorReactionId(); return $this->react; }
    }
}
namespace Ekitapligim\MobileApi\Api\Controller {
    class ChatMessages {
        public array $input = [];
        public bool $authenticated = true, $writeScope = true, $scopeChecked = false;
        public $room;
        public function __construct() { $this->room = new \Siropu\Chat\Entity\Room(); }
        protected function filter($key, $type) {
            $value = $this->input[$key] ?? '';
            return $type === 'uint' ? max((int) $value, 0) : (string) $value;
        }
        protected function assertMobileWriteScope() {
            $this->scopeChecked = true;
            if (!$this->writeScope) throw $this->exception($this->apiError('', 'no_permission', null, 403));
        }
        protected function assertRegisteredApiUser() {
            if (!$this->authenticated) throw $this->exception($this->apiError('', 'login_required', null, 401));
            return \XF::visitor();
        }
        protected function assertChatAvailable($writing = false) { return $this->assertRegisteredApiUser(); }
        protected function prepareChatUser() {}
        protected function assertChatRoom($id, $join = false) { return $this->room; }
        protected function apiError($message, $code, $params = null, $status = 400) { return ['error' => $code, 'status' => $status]; }
        protected function exception($reply) { return new \XF\Mvc\Reply\Exception($reply); }
        protected function em() { return \XF::em(); }
        protected function repository($type) { return \XF::repository($type); }
        protected function apiResult($result) { return $result; }
    }
}
namespace Ekitapligim\IosApi\Service {
    class TermsAcceptance {
        const CURRENT_VERSION = 'fixture';
        public static bool $accepted = true;
        public static function hasAccepted($id) { return self::$accepted; }
    }
    class UgcPolicy { public static function violation($fields) { return false; } }
}
namespace {
    // In-memory XF boundary; real iOS controller, desired-state helper and serializer run below.
    class SharedReactionRepository {
        public array $selections = [];
        public int $writes = 0;
        public function getReactionByContentAndReactionUser($type, $id, $userId) {
            if ($type !== 'siropu_chat_room_message' || $id !== 10) throw new \RuntimeException('Wrong shared content key');
            $reactionId = $this->selections[$userId] ?? 0;
            return $reactionId ? new class($reactionId, $userId, $this) {
                public function __construct(public int $reaction_id, public int $userId, public $repository) {}
                public function delete() { $this->repository->write($this->userId, 0); }
            } : null;
        }
        public function reactToContent($reactionId, $type, $id, $user, $checkPermissions) {
            $existing = $this->getReactionByContentAndReactionUser($type, $id, $user->user_id);
            // Model XF's toggle: retrying the same ID through this method would remove it.
            $this->write($user->user_id, $existing && $existing->reaction_id === $reactionId ? 0 : $reactionId);
            return $this->getReactionByContentAndReactionUser($type, $id, $user->user_id);
        }
        public function write($userId, $id) {
            if ($id) $this->selections[$userId] = $id; else unset($this->selections[$userId]);
            $this->writes++;
            XF::$message->reactions = array_count_values($this->selections);
        }
        public function findReactionsForList($active) { return $this; }
        public function fetch() { return [self::option(1), self::option(7)]; }
        public static function option($id) { return new class($id) {
            public bool $active = true, $sprite_mode = true;
            public string $title = 'Fixture', $image_url = 'https://example.com/reactions.png';
            public array $sprite_params = ['w' => 32, 'h' => 32, 'x' => -32, 'y' => 0, 'bs' => 'auto'];
            public function __construct(public int $reaction_id) {}
            public function getEmoji() { return ''; }
        }; }
    }
    class XF {
        public static $user, $message, $repository;
        public static int $transactions = 0;
        public static bool $reactions = true, $blocked = false;
        public static function visitor() { return self::$user; }
        public static function phrase($key) { return $key; }
        public static function options() { return (object) ['siropuChatReactions' => self::$reactions]; }
        public static function em() { return new class {
            public function find($type, $id) {
                if ($type === 'XF:Reaction' && in_array($id, [1, 7], true)) return SharedReactionRepository::option($id);
                return $type === 'Siropu\Chat:Message' && $id === 10 ? XF::$message : null;
            }
        }; }
        public static function db() { return new class {
            public function beginTransaction() { XF::$transactions++; }
            public function commit() { XF::$transactions--; }
            public function rollback() { XF::$transactions--; }
            public function fetchOne($sql, $args) { return str_contains($sql, 'FOR UPDATE') ? 10 : XF::$blocked; }
        }; }
        public static function repository($type) { return self::$repository; }
        public static function app() { return new class {
            public function stringFormatter() { return $this; }
            public function stripBbCode($value, $options) { return $value; }
        }; }
    }
    $root = dirname(__DIR__, 2) . '/Backend/IosApi-addon/';
    foreach (['Service/IgnoredUsers.php', 'Service/ChatInteraction.php', 'Service/ChatSerializer.php', 'Api/Controller/UgcControllerTrait.php',
        'Api/Controller/ChatMessages.php', 'Api/Controller/ChatReactions.php'] as $file) require_once $root . $file;
    class TestChatMessages extends \Ekitapligim\IosApi\Api\Controller\ChatMessages {
        protected function assertChatFlooding(\XF\Entity\User $visitor, \Siropu\Chat\Entity\Room $room): void {}
    }
    function check($value, $code, $status) {
        if (($value['error'] ?? null) !== $code || ($value['status'] ?? null) !== $status)
            throw new \RuntimeException("Expected $code/$status, got " . json_encode($value));
    }
    function result($controller, $params) {
        try { return $controller->actionPost($params); }
        catch (\XF\Mvc\Reply\Exception $e) { return $e->reply; }
    }
    XF::$user = new \XF\Entity\User(); XF::$message = new \Siropu\Chat\Entity\Message();
    XF::$repository = new SharedReactionRepository();
    $params = new \XF\Mvc\ParameterBag();
    $reaction = new \Ekitapligim\IosApi\Api\Controller\ChatReactions();
    $reaction->input = ['reaction_id' => '7'];
    $reaction->writeScope = false; check(result($reaction, $params), 'no_permission', 403);
    if (!$reaction->scopeChecked) throw new \RuntimeException('Write scope not enforced');
    $reaction->writeScope = true; $reaction->authenticated = false;
    check(result($reaction, $params), 'login_required', 401); $reaction->authenticated = true;
    \Ekitapligim\IosApi\Service\TermsAcceptance::$accepted = false;
    check(result($reaction, $params), 'terms_acceptance_required', 403);
    \Ekitapligim\IosApi\Service\TermsAcceptance::$accepted = true;
    XF::$message->message_room_id = 8; check(result($reaction, $params), 'message_not_found', 404); XF::$message->message_room_id = 7;
    XF::$message->visible = false; check(result($reaction, $params), 'message_not_found', 404); XF::$message->visible = true;
    XF::$blocked = true; check(result($reaction, $params), 'no_permission', 403); XF::$blocked = false;
    XF::$user->muted = true; check(result($reaction, $params), 'no_permission', 403); XF::$user->muted = false;
    $reaction->room->readOnly = true; check(result($reaction, $params), 'no_permission', 403); $reaction->room->readOnly = false;
    XF::$reactions = false; check(result($reaction, $params), 'no_permission', 403); XF::$reactions = true;
    XF::$message->react = false; check(result($reaction, $params), 'no_permission', 403); XF::$message->react = true;
    XF::$user->sanctioned = true; check(result($reaction, $params), 'chat_sanctioned', 403); XF::$user->sanctioned = false;
    foreach (['', '-1', '01', 'invalid', '1.5', '1000000000'] as $invalid) {
        $reaction->input = ['reaction_id' => $invalid]; check(result($reaction, $params), 'validation_error', 422);
    }
    $reaction->input = ['reaction_id' => '99']; check(result($reaction, $params), 'reaction_not_found', 404);
    foreach ([[1, true], [1, false], [7, true], [7, false], [0, true], [0, false]] as [$id, $changed]) {
        $reaction->input = ['reaction_id' => (string) $id];
        $response = result($reaction, $params);
        $serialized = $response['message'] ?? [];
        if (($response['success'] ?? false) !== true || ($response['changed'] ?? null) !== $changed
            || ($serialized['visitor_reaction_id'] ?? null) !== $id
            || ($serialized['reaction_count'] ?? null) !== ($id ? 1 : 0))
            throw new \RuntimeException('Persisted reaction and immediate API response differ: ' . json_encode($response));
        if ($id && ($serialized['reactions'][0]['sprite_params']['x'] ?? null) !== -32)
            throw new \RuntimeException('Configured sprite metadata lost');
        if (XF::$transactions !== 0) throw new \RuntimeException('Transaction left open');
    }
    if (XF::$repository->writes !== 3) throw new \RuntimeException('Retry toggled or rewrote reaction');
    // A web/Android write uses the same shared content key; a fresh iOS read sees it.
    XF::$repository->reactToContent(7, 'siropu_chat_room_message', 10, XF::$user, true);
    XF::$message->clearCache('Reactions');
    $crossClient = (new \Ekitapligim\IosApi\Service\ChatSerializer())->message(XF::$message);
    if ($crossClient['visitor_reaction_id'] !== 7 || $crossClient['reactions'][0]['count'] !== 1)
        throw new \RuntimeException('Shared repository write missing from iOS read');
    $quote = new TestChatMessages(); $quote->input = ['message' => 'Reply', 'quote_message_id' => '10'];
    $sendParams = new \XF\Mvc\ParameterBag(7, 0);
    XF::$message->quote = false; check(result($quote, $sendParams), 'no_permission', 403); XF::$message->quote = true;
    XF::$message->message_room_id = 8; check(result($quote, $sendParams), 'message_not_found', 404); XF::$message->message_room_id = 7;
    XF::$blocked = true; check(result($quote, $sendParams), 'no_permission', 403); XF::$blocked = false;
    $quote->input['message'] = ''; check(result($quote, $sendParams), 'validation_error', 422);
    check(result($quote, $params), 'method_not_allowed', 405);
    echo "Chat controllers: permissions, quote validation, shared reaction persistence, add/change/remove response cache, idempotent retries and sprite serialization passed.\n";
}
