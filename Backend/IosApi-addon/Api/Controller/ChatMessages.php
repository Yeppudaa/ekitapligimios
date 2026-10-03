<?php

namespace Ekitapligim\IosApi\Api\Controller;

use Ekitapligim\IosApi\Service\ChatSerializer;
use Ekitapligim\IosApi\Service\ChatInteraction;
use XF\Mvc\ParameterBag;

class ChatMessages extends \Ekitapligim\MobileApi\Api\Controller\ChatMessages
{
	use UgcControllerTrait;

	public function actionGet(ParameterBag $params)
	{
		$this->assertMobileScope();
		$this->assertChatAvailable();
		$this->prepareChatUser();
		$room = $this->assertChatRoom((int) $params->room_id, (bool) \XF::visitor()->user_id);
		$serializer = new ChatSerializer();
		if ((int) ($params->message_id ?? 0) > 0)
		{
			return $this->apiResult(['message' => $serializer->message($this->assertChatMessage((int) $params->message_id, $room)),
				'available_reactions' => $serializer->reactionOptions(), 'reaction_options' => $serializer->reactionOptions()]);
		}

		$limit = max(10, min(60, (int) ($this->filter('limit', 'uint') ?: 40)));
		$beforeId = (int) $this->filter('before_id', 'uint');
		$afterId = (int) $this->filter('after_id', 'uint');
		$finder = $this->finder('Siropu\Chat:Message')
			->fromRoom((int) $room->room_id)
			->notIgnored()
			->notFromIgnoredUsers();

		if ($afterId > 0)
		{
			$finder->idBiggerThan($afterId)->order('message_id', 'ASC');
		}
		else
		{
			if ($beforeId > 0) $finder->idSmallerThan($beforeId);
			$finder->order('message_id', 'DESC');
		}

		$messages = $finder->limit($limit)->fetch();
		if ($afterId <= 0)
		{
			$messages = $messages->reverse();
		}

		$items = [];
		foreach ($messages AS $message)
		{
			if ($message->canView() && $message->isPastJoinTime() && !$message->isIgnored()
				&& !$message->isIgnoredUser() && $message->canViewContent())
			{
				$items[] = $serializer->message($message);
			}
		}
		$oldestId = $items ? (int) $items[0]['message_id'] : 0;
		$newestId = $items ? (int) $items[count($items) - 1]['message_id'] : $afterId;
		$hasMore = false;
		if ($afterId <= 0 && $oldestId > 0)
		{
			$hasMore = (bool) \XF::db()->fetchOne(
				'SELECT 1 FROM xf_siropu_chat_message WHERE message_room_id = ? AND message_id < ? LIMIT 1',
				[(int) $room->room_id, $oldestId]
			);
		}

		return $this->apiResult([
			'room' => $serializer->room($room),
			'items' => $items,
			'messages' => $items,
			'available_reactions' => $serializer->reactionOptions(),
			'reaction_options' => $serializer->reactionOptions(),
			'pagination' => [
				'oldest_id' => $oldestId,
				'newest_id' => $newestId,
				'has_more' => $hasMore,
			],
		]);
	}

	public function actionPost(ParameterBag $params)
	{
		$this->assertMobileWriteScope();
		if ((int) ($params->message_id ?? 0) > 0)
            return $this->apiError((string) \XF::phrase('ek_ios_chat_read_only_endpoint'), 'method_not_allowed', null, 405);
		if ($error = $this->validateUgcWrite([(string) $this->filter('message', 'str')])) return $error;
		$visitor = $this->assertChatAvailable(true);
		if (!$visitor->canUseSiropuChat())
		{
			return $this->apiError('You cannot send chat messages.', 'no_permission', null, 403);
		}
		$this->prepareChatUser();
		$room = $this->assertChatRoom((int) $params->room_id, true);
		if ($room->isLocked($lockError))
		{
			return $this->apiError((string) $lockError, 'room_locked', null, 403);
		}
		if ($room->isReadOnly())
		{
			return $this->apiError('This chat room is read only.', 'room_read_only', null, 403);
		}

		$this->assertChatFlooding($visitor, $room);
		$rawMessage = trim($this->filter('message', 'str'));
		$quotedMessage = null;
		$quoteId = (int) $this->filter('quote_message_id', 'uint');
		if ($quoteId > 0)
		{
            if ($rawMessage === '') return $this->apiError((string) \XF::phrase('ek_ios_chat_reply_required'), 'validation_error', null, 422);
			$quotedMessage = $this->assertChatMessage($quoteId, $room);
			if (!ChatInteraction::canInteract($quotedMessage) || !$quotedMessage->canQuote())
                return $this->apiError((string) \XF::phrase('ek_ios_chat_quote_denied'), 'no_permission', null, 403);
			$rawMessage = ChatInteraction::quoteBbCode($quotedMessage) . "\n" . $rawMessage;
		}
		$preparer = $this->service('Siropu\Chat:Message\Preparer');
		$preparer->prepare($rawMessage);
		if (!$preparer->isValid())
		{
			return $this->apiError(implode(' ', array_map('strval', $preparer->getErrors())), 'validation_error', null, 422);
		}

		/** @var \Siropu\Chat\Entity\Message $message */
		$message = $this->em()->create('Siropu\Chat:Message');
		$message->message_room_id = (int) $room->room_id;
		$message->message_text = $preparer->getMessage();
		$message->setOption('room_child_ids', $room->room_child_ids);

		if ($visitor->isSanctionedSiropuChat())
		{
			if ($visitor->isMutedSiropuChat())
			{
				$message->ignoreMe();
			}
			else if ($sanction = $visitor->siropuChatGetRoomSanction((int) $room->room_id))
			{
				if ($sanction->sanction_type === 'mute') $message->ignoreMe();
				else return $this->apiError((string) $sanction->getNotice(), 'chat_sanctioned', null, 403);
			}
		}

		$mentionedUsers = $this->applyMentions($preparer, $message, $visitor);
		$message->save();
		$this->alertMentions($mentionedUsers, $message, $visitor);

		$visitor->siropuChatIncrementMessageCount();
		$visitor->siropuChatSetLastActivity();
		$visitor->siropuChatUpdateRooms((int) $room->room_id);
		$visitor->siropuChatSetActiveRoom((int) $room->room_id);
		$visitor->saveIfChanged();

		// The room-message entity listener is the sole notification producer for
		// web and mobile quotes, so one persisted reply queues one APNs job.

		return $this->apiResult([
			'success' => true,
			'message' => (new ChatSerializer())->message($message),
		]);
	}

	protected function assertChatMessage(int $messageId, \Siropu\Chat\Entity\Room $room): \Siropu\Chat\Entity\Message
	{
		$message = $this->em()->find('Siropu\Chat:Message', $messageId);
		if (!$message || (int) $message->message_room_id !== (int) $room->room_id
			|| !$message->canView() || !$message->isPastJoinTime()
			|| $message->isIgnored() || $message->isIgnoredUser() || !$message->canViewContent())
		{
            throw $this->exception($this->apiError((string) \XF::phrase('ek_ios_chat_message_not_found'), 'message_not_found', null, 404));
		}
		return $message;
	}

	protected function assertChatFlooding(\XF\Entity\User $visitor, \Siropu\Chat\Entity\Room $room): void
	{
		$floodLength = (int) ($room->room_flood ?: \XF::options()->siropuChatFloodCheckLength);
		if (!$floodLength || $visitor->canBypassSiropuChatFloodCheck())
		{
			return;
		}
		$lastDate = (int) \XF::db()->fetchOne(
			"SELECT MAX(message_date) FROM xf_siropu_chat_message WHERE message_user_id = ? AND message_type IN ('chat', 'me')",
			[(int) $visitor->user_id]
		);
		$remaining = $floodLength - (\XF::$time - $lastDate);
		if ($remaining > 0)
		{
			throw $this->exception($this->apiError('Please wait before sending another message.', 'chat_flooding', ['retry_after' => $remaining], 429));
		}
	}

	protected function applyMentions($preparer, \Siropu\Chat\Entity\Message $message, \XF\Entity\User $visitor): array
	{
		$mentions = $preparer->getUserMentions();
		if (!$mentions)
		{
			return [];
		}
		$users = $this->finder('XF:User')
			->where('user_id', array_keys($mentions))
			->isValidUser()
			->fetch();
		$result = [];
		foreach ($users AS $user)
		{
			if ($user->user_id !== $visitor->user_id && $user->canUseSiropuChat())
			{
				$message->mentionUser($user);
				$result[] = $user;
			}
		}

		return $result;
	}

	protected function alertMentions(array $users, \Siropu\Chat\Entity\Message $message, \XF\Entity\User $visitor): void
	{
		if (!$users || !\XF::options()->siropuChatUserMentionAlert || !$message->isChat())
		{
			return;
		}
		$repo = $this->repository('XF:UserAlert');
		foreach ($users AS $user)
		{
			if ($visitor->canAlertMentionSiropuChatUser($user))
			{
				$repo->alert($user, $visitor->user_id, $visitor->username, 'siropu_chat_room_message', $message->message_id, 'mention');
			}
		}
	}
}
