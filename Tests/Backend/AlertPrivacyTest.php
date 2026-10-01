<?php
namespace XF\Entity {
    class UserAlert {
        public string $action = 'insert';
        public string $content_type = '';
        public string $username = 'Private participant';
        public $User = null;
        public function render(): string { throw new \LogicException('Private alerts must never be rendered for push previews.'); }
    }
}
namespace XF\Job {
    class JobResult {}
    class AbstractJob {
        protected $data;
        protected $app;
        public function __construct($app, array $data) { $this->app = $app; $this->data = $data; }
        public function complete(): JobResult { return new JobResult(); }
    }
}
namespace Ekitapligim\IosApi\Service {
    class ApnsPush {
        public static array $sent = [];
        public static function buildPayload($title, $body, $badge, $custom) { return ['title' => $title, 'body' => $body]; }
        public static function sendToUser($id, $payload) { self::$sent[$id] = $payload; }
    }
}
namespace {
    class XF {
        public static function db() { return new class { public function fetchOne($sql, $args) { return 1; } }; }
    }
    require __DIR__ . '/../../Backend/IosApi-addon/Listener/AlertCreated.php';
    $method = new ReflectionMethod(\Ekitapligim\IosApi\Listener\AlertCreated::class, 'bodyFromAlert');
    foreach (['conversation', 'conversation_message', 'siropu_chat_conv_message', 'chat_message'] as $type) {
        $alert = new \XF\Entity\UserAlert();
        $alert->content_type = $type;
        if ($method->invoke(null, $alert) !== 'Yeni bir özel mesajınız var.') {
            throw new RuntimeException('Private notification preview contains unexpected content.');
        }
    }
    require __DIR__ . '/../../Backend/IosApi-addon/Job/SendConversationPush.php';
    $app = new class {
        public function em() { return $this; }
        public function find($type, $id) { return (object) ['conversation_id' => 42, 'username' => 'Private participant']; }
    };
    $job = new \Ekitapligim\IosApi\Job\SendConversationPush($app, [
        'message_id' => 9, 'conversation_id' => 42, 'sender_user_id' => 1, 'recipient_user_ids' => [2]
    ]);
    $job->run(1);
    if ((\Ekitapligim\IosApi\Service\ApnsPush::$sent[2]['body'] ?? '') !== 'Yeni bir özel mesajınız var.') {
        throw new RuntimeException('Conversation job revealed private participant information.');
    }
    echo "APNs privacy: 4 alert types and the conversation job omit private text and participant names.\n";
}
