<?php

namespace Ekitapligim\IosApi\XF\Service\Conversation;

use XF\Entity\ConversationMessage;
use XF\Entity\User;

class Notifier extends XFCP_Notifier
{
	protected function _sendNotifications(
		$actionType,
		array $notifyUsers,
		?ConversationMessage $message = null,
		?User $sender = null
	)
	{
		$result = parent::_sendNotifications($actionType, $notifyUsers, $message, $sender);

		if (!$message)
		{
			return $result;
		}
		if (!$sender)
		{
			$sender = $message->User;
		}

		$messageId = (int) $message->message_id;
		$conversationId = (int) $message->conversation_id;
		$senderId = (int) ($sender ? $sender->user_id : $message->user_id);
		if ($messageId <= 0 || $conversationId <= 0) { return $result; }

		$recipientIds = [];
		foreach ($notifyUsers AS $user)
		{
			$userId = (int) ($user->user_id ?? 0);
			if ($userId > 0 && $userId !== $senderId && $this->_canUserReceiveNotification($user, $sender))
			{
				$recipientIds[$userId] = $userId;
			}
		}

		if ($recipientIds)
		{
			\XF::app()->jobManager()->enqueueUnique(
				'ekitapligimIosConversation' . $messageId,
				'Ekitapligim\IosApi:SendConversationPush',
				[
					'message_id' => $messageId,
					'conversation_id' => $conversationId,
					'sender_user_id' => $senderId,
					'recipient_user_ids' => array_values($recipientIds),
				],
				false
			);
		}

		return $result;
	}
}
