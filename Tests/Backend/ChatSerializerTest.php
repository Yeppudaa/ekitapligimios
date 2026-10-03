<?php
namespace Siropu\Chat\Entity {
    class Message {
        public int $message_room_id = 4, $message_user_id = 9, $message_date = 100, $message_like_count = 0;
        public string $message_username = 'Ada', $message_bot_name = '', $message_type = 'chat', $message_text = '';
        public $User = null, $Room = null;
        public array $reactions = [];
        public bool $visible = true;
        public function __construct(public int $message_id = 81, string $text = '') { $this->message_text = $text; }
        public function getMessage() { return $this->message_text; }
        public function isIgnored() { return false; }
        public function isIgnoredUser() { return false; }
        public function canView() { return $this->visible; }
        public function isPastJoinTime() { return true; }
        public function canViewContent() { return $this->visible; }
        public function isBot() { return false; }
        public function isAnnouncement() { return false; }
        public function isEdited() { return false; }
        public function isLiked() { return false; }
        public function getVisitorReactionId() { return 0; }
    }
}
namespace {
    class SerializerApp {
        public array $messages = [], $blocked = [];
        public function find($type, $id) { return $this->messages[$id] ?? null; }
        public function fetchOne($sql, $args) { return isset($this->blocked[$args[0] . ':' . $args[1]]) || isset($this->blocked[$args[2] . ':' . $args[3]]); }
        public function stringFormatter() { return $this; }
        public function stripBbCode($text, $options) { return preg_replace('/\[(?:\/?QUOTE|\/?B)(?:=[^\]]*)?\]/i', '', $text); }
    }
    class XF {
        public static $app;
        public static function app() { return self::$app; }
        public static function em() { return self::$app; }
        public static function db() { return self::$app; }
        public static function visitor() { return (object) ['user_id' => 1]; }
        public static function options() { return (object) ['siropuChatReactions' => false]; }
    }
    $root = dirname(__DIR__, 2) . '/Backend/IosApi-addon/Service/';
    foreach (['IgnoredUsers.php', 'ChatInteraction.php', 'ChatSerializer.php'] as $file) require_once $root . $file;
    function check($condition, $message) { if (!$condition) throw new \RuntimeException($message); }
    function quote($id, $user = 9, $body = 'Original') { return '[QUOTE="Ada, member: ' . $user . ', ek_message: ' . $id . '"]' . $body . '[/QUOTE]'; }
    function serializeMessage($text) { return (new \Ekitapligim\IosApi\Service\ChatSerializer())->message(new \Siropu\Chat\Entity\Message(82, $text)); }
    XF::$app = $app = new SerializerApp();
    $app->messages[81] = new \Siropu\Chat\Entity\Message(81, 'Original');
    $plain = serializeMessage('Hello');
    check($plain['message'] === 'Hello' && $plain['message_body'] === 'Hello' && $plain['quoted_message'] === null, 'Plain messages changed');
    $reply = serializeMessage(quote(81) . "\nReply");
    check($reply['message'] === "Original\nReply", 'Old client lost visible quote');
    check($reply['message_body'] === 'Reply' && $reply['quoted_message']['message'] === 'Original', 'New client duplicates or loses quote');
    $only = serializeMessage(quote(81));
    check($only['message'] === 'Original' && $only['message_body'] === '' && $only['quoted_message'] !== null, 'Quote-only message looks blank on old client');
    $historical = serializeMessage('[QUOTE="Historical"]Old quote[/QUOTE] Reply');
    check($historical['message'] === 'Old quote Reply' && $historical['quoted_message']['message_id'] === 0, 'Historical quote readability changed');

    foreach (['missing', 'hidden', 'other_room', 'blocked_forward', 'blocked_reverse', 'mismatched_user', 'invalid_id'] as $case) {
        $app->blocked = []; $target = $app->messages[81]; $target->visible = true; $target->message_room_id = 4;
        $id = $case === 'missing' ? 99 : 81; $user = $case === 'mismatched_user' ? 8 : 9;
        if ($case === 'hidden') $target->visible = false;
        if ($case === 'other_room') $target->message_room_id = 5;
        if ($case === 'blocked_forward') $app->blocked['1:9'] = true;
        if ($case === 'blocked_reverse') $app->blocked['9:1'] = true;
        $quoted = $case === 'invalid_id' ? '[QUOTE="Ada, ek_message: invalid"]SECRET[/QUOTE]' : quote($id, $user, 'SECRET');
        $result = serializeMessage($quoted . ' Visible reply');
        check(!str_contains(json_encode($result), 'SECRET') && $result['quoted_message'] === null && $result['message'] === 'Visible reply', 'Unsafe quote exposed: ' . $case);
    }
    $app->blocked = []; $app->messages[81]->visible = true; $app->messages[81]->message_room_id = 4;
    $nested = serializeMessage(quote(81, 9, 'Visible ' . quote(99, 8, 'NESTED SECRET')) . ' Reply');
    check(!str_contains(json_encode($nested), 'NESTED SECRET') && $nested['quoted_message']['message'] === 'Visible', 'Nested unavailable quote leaked');
    $inline = serializeMessage('Before ' . quote(99, 8, 'INLINE SECRET') . ' After');
    check($inline['message'] === 'Before After' && !str_contains(json_encode($inline), 'INLINE SECRET'), 'Inline unavailable quote leaked');
    $unclosed = serializeMessage('Before [QUOTE="Ada, ek_message: 99"]UNCLOSED SECRET');
    check($unclosed['message'] === 'Before' && !str_contains(json_encode($unclosed), 'UNCLOSED SECRET'), 'Unclosed unavailable quote leaked');
    echo "Chat serializer: old/new clients retain safe quotes; nested, inline, blocked, missing and malformed references stay private.\n";
}
