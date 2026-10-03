<?php

namespace Ekitapligim\IosApi\Job;

use Ekitapligim\IosApi\Service\ApnsPush;
use Ekitapligim\IosApi\Service\ChatInteraction;
use Ekitapligim\IosApi\Service\ChatPushProducer;
use XF\Job\AbstractJob;

class SendChatInteractionPush extends AbstractJob
{
	protected $defaultData = ['kind' => '', 'message_id' => 0, 'room_id' => 0, 'reply_message_id' => 0,
		'reaction_content_id' => 0, 'reaction_id' => 0, 'actor_user_id' => 0, 'recipient_user_id' => 0];

	public function run($maxRunTime): \XF\Job\JobResult
	{
		$target = $this->app->em()->find('Siropu\Chat:Message', (int) $this->data['message_id']);
		$actor = $this->app->em()->find('XF:User', (int) $this->data['actor_user_id']);
		if (!$target || (int) $target->message_room_id !== (int) $this->data['room_id']
			|| (int) $target->message_user_id !== (int) $this->data['recipient_user_id']
			|| !ChatPushProducer::eligible($target, $actor)) return $this->complete();

		$kind = (string) $this->data['kind'];
		if (!ChatPushProducer::canActAs($actor, $target, $kind)) return $this->complete();
		if ($kind === 'quote')
		{
			$reply = $this->app->em()->find('Siropu\Chat:Message', (int) $this->data['reply_message_id']);
			if (!ChatPushProducer::isPublicMessage($reply)
				|| (int) $reply->message_user_id !== (int) $actor->user_id
				|| (int) $reply->message_room_id !== (int) $target->message_room_id) return $this->complete();
			$split = ChatInteraction::splitQuote((string) $reply->message_text);
			$recipient = $this->app->em()->find('XF:User', (int) $target->message_user_id);
			if (!$split || (int) $split['message_id'] !== (int) $target->message_id
				|| (int) $split['user_id'] !== (int) $target->message_user_id
				|| !ChatPushProducer::canViewAs($recipient, $reply)) return $this->complete();
			$title = (string) \XF::phrase('ek_ios_chat_quote_push_title');
			$body = (string) \XF::phrase('ek_ios_chat_quote_push_body');
		}
		elseif ($kind === 'reaction')
		{
			$reaction = $this->app->em()->find('XF:ReactionContent', (int) $this->data['reaction_content_id']);
			if (!$reaction || (string) $reaction->content_type !== ChatInteraction::CONTENT_TYPE
				|| (int) $reaction->content_id !== (int) $target->message_id
				|| (int) $reaction->reaction_user_id !== (int) $actor->user_id
				|| (int) $reaction->reaction_id !== (int) $this->data['reaction_id']) return $this->complete();
			$title = (string) \XF::phrase('ek_ios_chat_reaction_push_title');
			$body = (string) \XF::phrase('ek_ios_chat_reaction_push_body');
		}
		else return $this->complete();

		$recipientId = (int) $target->message_user_id;
		$recipient = $this->app->em()->find('XF:User', $recipientId);
		$payload = ApnsPush::buildPayload($title, $body, $recipient ? (int) $recipient->alerts_unread : 0, [
			'type' => 'chat_interaction', 'action' => $kind, 'room_id' => (int) $target->message_room_id,
			'message_id' => (int) $target->message_id, 'actor_user_id' => (int) $actor->user_id,
			'route' => 'chat/' . (int) $target->message_room_id,
		]);
		ApnsPush::sendToUser($recipientId, $payload);
		return $this->complete();
	}

	public function getStatusMessage(): string { return (string) \XF::phrase('ek_ios_chat_push_job_status'); }
	public function canCancel(): bool { return false; }
	public function canTriggerByChoice(): bool { return false; }
}
