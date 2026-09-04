<?php

namespace Ekitapligim\IosApi\Job;

use Ekitapligim\IosApi\Service\ApnsPush;
use XF\Job\AbstractJob;

class SendConversationPush extends AbstractJob
{
	protected $defaultData = [
		'message_id' => 0,
		'conversation_id' => 0,
		'sender_user_id' => 0,
		'recipient_user_ids' => [],
	];

	public function run($maxRunTime): \XF\Job\JobResult
	{
		$messageId = (int) $this->data['message_id'];
		$conversationId = (int) $this->data['conversation_id'];
		$senderId = (int) $this->data['sender_user_id'];
		if ($messageId <= 0 || $conversationId <= 0)
		{
			return $this->complete();
		}

		$message = $this->app->em()->find('XF:ConversationMessage', $messageId);
		if (!$message || (int) $message->conversation_id !== $conversationId)
		{
			return $this->complete();
		}

		$sender = $senderId > 0 ? $this->app->em()->find('XF:User', $senderId) : null;
		$senderName = trim((string) ($sender ? $sender->username : $message->username));
		$body = ($senderName !== '' ? $senderName : 'Bir üye') . ' size özel mesaj gönderdi.';

		foreach (array_unique(array_map('intval', (array) $this->data['recipient_user_ids'])) AS $recipientId)
		{
			if ($recipientId <= 0 || $recipientId === $senderId)
			{
				continue;
			}

			$isActiveRecipient = (bool) \XF::db()->fetchOne(
				'SELECT 1 FROM xf_conversation_recipient WHERE conversation_id = ? AND user_id = ? AND recipient_state = ?',
				[$conversationId, $recipientId, 'active']
			);
			if (!$isActiveRecipient)
			{
				continue;
			}

			$badge = (int) \XF::db()->fetchOne('SELECT conversations_unread FROM xf_user WHERE user_id = ?', [$recipientId]);
			$payload = ApnsPush::buildPayload('Yeni özel mesaj', $body, max(0, $badge), [
				'type' => 'conversation_message',
				'action' => 'insert',
				'content_id' => $messageId,
				'message_id' => $messageId,
				'conversation_id' => $conversationId,
				'actor_user_id' => $senderId,
				'route' => 'conversation/' . $conversationId,
			]);
			ApnsPush::sendToUser($recipientId, $payload);
		}

		return $this->complete();
	}

	public function getStatusMessage(): string { return 'iOS özel mesaj bildirimi gönderiliyor…'; }
	public function canCancel(): bool { return false; }
	public function canTriggerByChoice(): bool { return false; }
}
