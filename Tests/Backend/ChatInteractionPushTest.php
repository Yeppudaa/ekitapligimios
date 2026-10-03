<?php
namespace XF\Entity {
    class User {
        public string $user_state = 'valid'; public bool $is_banned = false;
        public bool $view = true, $use = true, $muted = false, $banned = false, $sanctioned = false;
        public int $alerts_unread = 3; public string $username = 'PRIVATE USER';
        public function __construct(public int $user_id) {}
        public function canViewSiropuChat() { return $this->view; }
        public function canUseSiropuChat() { return $this->use; }
        public function isBannedSiropuChat() { return $this->banned; }
        public function isMutedSiropuChat() { return $this->muted; }
        public function isSanctionedSiropuChat() { return $this->sanctioned; }
        public function siropuChatGetRoomSanction($id) { return $this->sanctioned; }
    }
    class UserAlert {
        public int $alert_id = 8, $alerted_user_id = 2, $content_id = 10, $user_id = 1;
        public string $content_type = 'post', $action = 'insert';
        public function isInsert() { return true; }
    }
}
namespace XF\Job {
    class JobResult {}
    class AbstractJob {
        protected $app; protected $data;
        public function __construct($app, array $data) { $this->app = $app; $this->data = $data; }
        public function complete(): JobResult { return new JobResult(); }
    }
}
namespace Siropu\Chat\Entity {
    class Room {
        public string $room_state = 'visible'; public int $room_id = 7;
        public array $allowed = [1, 2]; public bool $readOnly = false, $locked = false;
        public function isJoined() { return in_array(\XF::visitor()->user_id, $this->allowed, true); }
        public function canJoin() { return $this->isJoined(); }
        public function isReadOnly() { return $this->readOnly; }
        public function isLocked() { return $this->locked; }
    }
    class Message {
        public int $message_room_id = 7, $message_is_ignored = 0;
        public string $message_type = 'chat', $message_username = 'PRIVATE USER', $message_text = 'PRIVATE TEXT';
        public array $visible = [1, 2]; public bool $contentVisible = true, $quote = true, $react = true, $insert = true;
        public $Room;
        public function __construct(public int $message_id = 10, public int $message_user_id = 2) { $this->Room = new Room(); }
        public function isInsert() { return $this->insert; }
        public function isIgnored() { return (bool) $this->message_is_ignored; }
        public function isIgnoredUser() { return false; }
        public function canView() { return in_array(\XF::visitor()->user_id, $this->visible, true); }
        public function isPastJoinTime() { return $this->canView(); }
        public function canViewContent() { return $this->contentVisible; }
        public function canQuote() { return $this->quote; }
        public function canReact() { return $this->react; }
        public function getQuoteWrapper($inner) { return '[QUOTE="' . $this->message_username . '"]' . $inner . '[/QUOTE]'; }
    }
}
namespace Ekitapligim\IosApi\Service {
    class ApnsPush {
        public static array $sent = [];
        public static function buildPayload($title, $body, $badge, $data) { return compact('title', 'body', 'badge', 'data'); }
        public static function sendToUser($id, $payload) { self::$sent[] = [$id, $payload]; }
    }
}
namespace Ekitapligim\IosApi\XF\Siropu\Chat\Entity {
    class XFCP_Message extends \Siropu\Chat\Entity\Message {}
}
namespace {
    class MemoryApp {
        public array $entities = [], $queued = []; public array $blocked = [];
        public function em() { return $this; } public function jobManager() { return $this; }
        public function find($type, $id) { return $this->entities[$type][$id] ?? null; }
        public function enqueueUnique($key, $type, $data, $manual) { $this->queued[$key] = compact('type', 'data'); }
        public function fetchOne($sql, $args) { return isset($this->blocked[$args[0] . ':' . $args[1]]) || isset($this->blocked[$args[2] . ':' . $args[3]]); }
    }
    class XF {
        public static $app, $visitor;
        public static function app() { return self::$app; } public static function em() { return self::$app; }
        public static function db() { return self::$app; } public static function visitor() { return self::$visitor; }
        public static function options() { return (object) ['siropuChatEnabled' => true, 'siropuChatReactions' => true]; }
        public static function phrase($key) { return $key; }
        public static function asVisitor($user, $callback) { $old = self::$visitor; self::$visitor = $user; try { return $callback(); } finally { self::$visitor = $old; } }
        public static function logException($error, ...$args) { throw $error; }
    }
    $root = dirname(__DIR__, 2) . '/Backend/IosApi-addon/';
    foreach (['Service/ChatInteraction.php', 'Service/IgnoredUsers.php', 'Service/ChatPushProducer.php',
        'Listener/ChatInteractionCreated.php', 'Job/SendChatInteractionPush.php', 'Listener/AlertCreated.php',
        'XF/Siropu/Chat/Entity/Message.php'] as $path) require_once $root . $path;
    function check($condition, $message) { if (!$condition) throw new \RuntimeException($message); }
    function react($type = 'siropu_chat_room_message', $actorId = 1, $contentId = 10, $id = 5) {
        return new class($type, $actorId, $contentId, $id) {
            public bool $insert = true;
            public function __construct(public string $content_type, public int $reaction_user_id, public int $content_id,
                public int $reaction_id, public int $reaction_content_id = 30) {}
            public function isInsert() { return $this->insert; }
        };
    }
    use Ekitapligim\IosApi\Service\ChatInteraction as Interaction;
    use Ekitapligim\IosApi\Service\ChatPushProducer as Push;
    use Ekitapligim\IosApi\Listener\ChatInteractionCreated as Listener;
    use Ekitapligim\IosApi\Service\ApnsPush;
    XF::$app = $app = new MemoryApp(); XF::$visitor = $actor = new \XF\Entity\User(1);
    $recipient = new \XF\Entity\User(2);
    $app->entities['XF:User'] = [1 => $actor, 2 => $recipient];
    $target = new \Siropu\Chat\Entity\Message(); $reply = new \Siropu\Chat\Entity\Message(11, 1);
    $app->entities['Siropu\Chat:Message'] = [10 => $target, 11 => $reply];
    $reply->message_text = '[QUOTE="PRIVATE USER, member: 2, ek_message: 10"]PRIVATE TEXT[/QUOTE]' . "\nAnswer";
    $nested = Interaction::splitQuote('[QUOTE="Outer, member: 2, ek_message: 10"][QUOTE="Inner"]nested[/QUOTE]text[/QUOTE]reply');
    check($nested['message_id'] === 10 && $nested['inner'] === '[QUOTE="Inner"]nested[/QUOTE]text' && $nested['remainder'] === 'reply', 'Nested quote split failed');
    check(Interaction::splitQuote('[QUOTE="x"]unclosed') === null, 'Malformed quote accepted');
    $wrapped = Interaction::withMessageReference($target->getQuoteWrapper('text'), $target);
    check(Interaction::withMessageReference($wrapped, $target) === $wrapped, 'Quote metadata duplicated');
    $webMessage = new \Ekitapligim\IosApi\XF\Siropu\Chat\Entity\Message();
    check(str_contains($webMessage->getQuoteWrapper('text'), 'member: 2, ek_message: 10'), 'Website room quote lacks target metadata');
    $webMessage->message_type = 'whisper';
    check(!str_contains($webMessage->getQuoteWrapper('text'), 'ek_message:'), 'Private quote was modified');

    foreach (['chat', 'me', 'whisper', 'bot', 'thread', 'post'] as $type) {
        $plain = new \Siropu\Chat\Entity\Message(12, 1); $plain->message_type = $type;
        Listener::onRoomMessage($plain);
    }
    check(count($app->queued) === 0, 'Plain/private/announcement messages queued push');
    Listener::onRoomMessage($reply);
    check(count($app->queued) === 1, 'Valid website/mobile quote not queued');
    $quoteJob = current($app->queued)['data'];
    (new \Ekitapligim\IosApi\Job\SendChatInteractionPush($app, $quoteJob))->run(1);
    check(count(ApnsPush::$sent) === 1 && ApnsPush::$sent[0][0] === 2, 'Quote target push recipient incorrect');
    check(ApnsPush::$sent[0][1]['data']['route'] === 'chat/7', 'Quote push route incorrect');
    check(!str_contains(json_encode(ApnsPush::$sent), 'PRIVATE'), 'Lock-screen push contains message text or username');
    check(XF::visitor() === $actor, 'Actor/recipient visitor not restored');
    ApnsPush::$sent = []; $app->queued = [];

    foreach (['1:2', '2:1'] as $block) {
        $app->blocked = [$block => true]; Listener::onRoomMessage($reply);
        check(!$app->queued, 'Blocked quote queued');
    }
    $app->blocked = [];
    $target->Room->allowed = [1]; Listener::onRoomMessage($reply); check(!$app->queued, 'Inaccessible recipient room queued');
    $target->Room->allowed = [1, 2]; $target->visible = [1];
    Listener::onRoomMessage($reply); check(!$app->queued, 'Actor visibility reused for recipient');
    $target->visible = [1, 2]; $actor->muted = true;
    Listener::onRoomMessage($reply); check(!$app->queued, 'Muted actor queued'); $actor->muted = false;
    $target->quote = false; Listener::onRoomMessage($reply); check(!$app->queued, 'Quote permission ignored'); $target->quote = true;
    $reply->insert = false; Listener::onRoomMessage($reply); check(!$app->queued, 'Edited quote queued again'); $reply->insert = true;
    $target->contentVisible = false; Listener::onRoomMessage($reply); check(!$app->queued, 'Hidden content queued'); $target->contentVisible = true;
    $originalText = $reply->message_text;
    foreach (['[QUOTE="PRIVATE USER"]PRIVATE TEXT[/QUOTE]Answer', '[QUOTE="x, member: 3, ek_message: 10"]text[/QUOTE]Answer'] as $text) {
        $reply->message_text = $text; Listener::onRoomMessage($reply); check(!$app->queued, 'Unproven quote recipient queued');
    }
    $reply->message_text = $originalText;
    $reply->message_room_id = 8; Listener::onRoomMessage($reply); check(!$app->queued, 'Cross-room quote queued'); $reply->message_room_id = 7;

    foreach (['siropu_chat_conv_message', 'conversation_message', 'post', 'chat_message'] as $type) Listener::onReaction(react($type));
    check(!$app->queued, 'External/private/non-room reaction queued');
    $reaction = react(); $app->entities['XF:ReactionContent'][30] = $reaction;
    Listener::onReaction($reaction); check(count($app->queued) === 1, 'Live-room reaction not queued');
    $reactionJob = current($app->queued)['data'];
    (new \Ekitapligim\IosApi\Job\SendChatInteractionPush($app, $reactionJob))->run(1);
    check(count(ApnsPush::$sent) === 1 && ApnsPush::$sent[0][0] === 2, 'Reaction target incorrect');
    $reaction->insert = false; Listener::onReaction($reaction);
    check(count($app->queued) === 1, 'Reaction update duplicated push');
    ApnsPush::$sent = []; unset($app->entities['XF:ReactionContent'][30]);
    (new \Ekitapligim\IosApi\Job\SendChatInteractionPush($app, $reactionJob))->run(1);
    check(!ApnsPush::$sent, 'Removed reaction generated stale push');
    $app->entities['XF:ReactionContent'][30] = $reaction; $reaction->reaction_id = 4;
    (new \Ekitapligim\IosApi\Job\SendChatInteractionPush($app, $reactionJob))->run(1);
    check(!ApnsPush::$sent, 'Changed reaction generated stale push');
    $reaction->reaction_id = 5; $app->blocked['2:1'] = true;
    (new \Ekitapligim\IosApi\Job\SendChatInteractionPush($app, $reactionJob))->run(1);
    check(!ApnsPush::$sent, 'Queued push ignored later block'); $app->blocked = [];
    $reply->visible = [1];
    (new \Ekitapligim\IosApi\Job\SendChatInteractionPush($app, $quoteJob))->run(1);
    check(!ApnsPush::$sent, 'Queued quote revealed a recipient-hidden reply'); $reply->visible = [1, 2];
    $app->queued = []; Listener::onReaction(react('siropu_chat_room_message', 2));
    check(!$app->queued, 'Self reaction queued');
    $target->message_type = 'bot'; Listener::onReaction($reaction); check(!$app->queued, 'Announcement/bot reaction queued'); $target->message_type = 'chat';

    $alert = new \XF\Entity\UserAlert();
    foreach (['siropu_chat_room_message', 'siropu_chat_conv_message', 'chat_message', 'external_chat_message'] as $type) {
        $alert->content_type = $type; \Ekitapligim\IosApi\Listener\AlertCreated::onUserAlert($alert);
        check(\Ekitapligim\IosApi\Listener\AlertCreated::deliver($alert)['attempted'] === 0, 'Queued generic chat alert delivered APNs');
    }
    check(!$app->queued, 'Generic chat alert queued APNs');
    foreach (['post', 'conversation_message'] as $type) {
        $alert->content_type = $type; $alert->alert_id++;
        \Ekitapligim\IosApi\Listener\AlertCreated::onUserAlert($alert);
    }
    check(count($app->queued) === 2, 'Non-chat notifications no longer enqueue');
    echo "Chat pushes: proven web/mobile room replies/reactions, target-only routing, fresh privacy/permissions, stale-state suppression and external chat isolation passed.\n";
}
