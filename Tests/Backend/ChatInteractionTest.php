<?php
require_once __DIR__ . '/../../Backend/IosApi-addon/Service/ChatInteraction.php';
use Ekitapligim\IosApi\Service\ChatInteraction;

class DesiredReactionRepository {
    public $current = null; public int $writes = 0, $deletes = 0;
    public function getReactionByContentAndReactionUser(...$args) { return $this->current; }
    public function reactToContent($id, ...$args) {
        $this->writes++;
        return $this->current = new class($id, $this) {
            public function __construct(public int $reaction_id, public $repo) {}
            public function delete() { $this->repo->current = null; $this->repo->deletes++; }
        };
    }
}
function check($condition, $message) { if (!$condition) throw new \RuntimeException($message); }
$repository = new DesiredReactionRepository();
$message = (object) ['message_id' => 12]; $visitor = (object) ['user_id' => 1];
check(!ChatInteraction::setReaction($repository, $message, $visitor, 0)['changed'], 'Empty removal changed state');
check(ChatInteraction::setReaction($repository, $message, $visitor, 1)['changed'], 'Like did not apply');
check(!ChatInteraction::setReaction($repository, $message, $visitor, 1)['changed'], 'Repeated like toggled off');
check($repository->current->reaction_id === 1 && $repository->writes === 1, 'Repeated request wrote a second reaction');
check(ChatInteraction::setReaction($repository, $message, $visitor, 5)['changed'], 'Reaction change failed');
check($repository->current->reaction_id === 5 && $repository->writes === 2, 'Desired reaction not persisted');
check(ChatInteraction::setReaction($repository, $message, $visitor, 0)['changed'], 'Explicit removal failed');
check(!ChatInteraction::setReaction($repository, $message, $visitor, 0)['changed'], 'Repeated removal changed state');
check($repository->current === null && $repository->deletes === 1, 'Reaction removal not idempotent');
echo "Chat interaction: desired-state reactions retain repeated selections and remove explicitly/idempotently.\n";
