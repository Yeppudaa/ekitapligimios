<?php

namespace Ekitapligim\IosApi\Api\Controller;

use Ekitapligim\IosApi\Service\ChatInteraction;
use Ekitapligim\IosApi\Service\ChatSerializer;
use XF\Mvc\ParameterBag;

class ChatReactions extends ChatMessages
{
	public function actionPost(ParameterBag $params)
	{
		$this->assertMobileWriteScope();
		if ($error = $this->validateUgcWrite([])) return $error;
		$visitor = $this->assertChatAvailable(true);
		$this->prepareChatUser();
		$room = $this->assertChatRoom((int) $params->room_id, true);
		$message = $this->assertChatMessage((int) $params->message_id, $room);
		if (!$visitor->canUseSiropuChat() || !\XF::options()->siropuChatReactions
			|| !ChatInteraction::canInteract($message) || !$message->canReact($error)
			|| $room->isReadOnly() || $room->isLocked() || $visitor->isMutedSiropuChat())
            return $this->apiError((string) \XF::phrase('ek_ios_chat_reaction_denied'), 'no_permission', null, 403);
		if ($visitor->isSanctionedSiropuChat() && $visitor->siropuChatGetRoomSanction((int) $room->room_id))
            return $this->apiError((string) \XF::phrase('ek_ios_chat_room_reaction_denied'), 'chat_sanctioned', null, 403);

		// Zero explicitly removes; absence or malformed values are never treated as removal.
		$rawId = trim($this->filter('reaction_id', 'str'));
		if (!preg_match('/^(0|[1-9][0-9]{0,8})$/', $rawId))
            return $this->apiError((string) \XF::phrase('ek_ios_chat_reaction_invalid'), 'validation_error', null, 422);
		$reactionId = (int) $rawId;
		if ($reactionId > 0)
		{
			$reaction = $this->em()->find('XF:Reaction', $reactionId);
			if (!$reaction || !$reaction->active)
                return $this->apiError((string) \XF::phrase('ek_ios_chat_reaction_not_found'), 'reaction_not_found', null, 404);
		}

		$db = \XF::db();
		$db->beginTransaction();
		try
		{
			// Serialize mobile desired-state requests without inventing Siropu columns.
			$db->fetchOne('SELECT message_id FROM xf_siropu_chat_message WHERE message_id = ? FOR UPDATE', (int) $message->message_id);
			$state = ChatInteraction::setReaction($this->repository('XF:Reaction'), $message, $visitor, $reactionId);
			$db->commit();
		}
		catch (\Throwable $error) { $db->rollback(); throw $error; }

		// XenForo caches the visitor's Reactions relation during permission checks.
		// Return the saved selection after add/change/remove, not that earlier snapshot.
		if ($state['changed']) $message->clearCache('Reactions');

		// ReactionContent insert listeners produce notifications for both website
		// and app requests; idempotent requests do not insert or enqueue again.
		return $this->apiResult(['success' => true, 'changed' => (bool) $state['changed'],
			'message' => (new ChatSerializer())->message($message)]);
	}
}
