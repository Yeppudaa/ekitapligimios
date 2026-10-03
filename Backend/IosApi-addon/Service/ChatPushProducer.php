<?php

namespace Ekitapligim\IosApi\Service;

/** APNs is created only for a proven interaction with a live room message. */
final class ChatPushProducer
{
	public static function isChatAlertType(string $type): bool
	{
		return strpos(strtolower($type), 'chat') !== false;
	}

	public static function enqueueQuote($target, $reply, $actor): bool
	{
		$split = ChatInteraction::splitQuote((string) $reply->message_text);
		if (!$split || (int) $split['message_id'] !== (int) $target->message_id
			|| (int) $split['user_id'] !== (int) $target->message_user_id
			|| (int) $reply->message_room_id !== (int) $target->message_room_id
			|| (int) $reply->message_user_id !== (int) $actor->user_id
			|| !self::isPublicMessage($reply) || !self::eligible($target, $actor)
			|| !self::canActAs($actor, $target, 'quote')) return false;
		self::enqueue('quote:' . (int) $reply->message_id, [
			'kind' => 'quote', 'message_id' => (int) $target->message_id,
			'reply_message_id' => (int) $reply->message_id, 'actor_user_id' => (int) $actor->user_id,
			'recipient_user_id' => (int) $target->message_user_id, 'room_id' => (int) $target->message_room_id,
		]);
		return true;
	}

	public static function enqueueReaction($target, $actor, $reaction, int $reactionId): bool
	{
		if ((string) $reaction->content_type !== ChatInteraction::CONTENT_TYPE
			|| (int) $reaction->content_id !== (int) $target->message_id
			|| (int) $reaction->reaction_user_id !== (int) $actor->user_id
			|| (int) $reaction->reaction_id !== $reactionId || $reactionId <= 0
			|| !self::eligible($target, $actor) || !self::canActAs($actor, $target, 'reaction')) return false;
		self::enqueue('reaction:' . (int) $reaction->reaction_content_id . ':' . $reactionId, [
			'kind' => 'reaction', 'message_id' => (int) $target->message_id,
			'reaction_content_id' => (int) $reaction->reaction_content_id, 'reaction_id' => $reactionId,
			'actor_user_id' => (int) $actor->user_id, 'recipient_user_id' => (int) $target->message_user_id,
			'room_id' => (int) $target->message_room_id,
		]);
		return true;
	}

	public static function isPublicMessage($message): bool
	{
		return $message && (int) $message->message_id > 0 && (int) $message->message_user_id > 0
			&& (int) $message->message_room_id > 0 && !(int) $message->message_is_ignored
			&& in_array((string) $message->message_type, ['chat', 'me'], true);
	}

	public static function eligible($target, $actor): bool
	{
		if (!self::isPublicMessage($target) || !$actor || (int) $actor->user_id <= 0
			|| (int) $actor->user_id === (int) $target->message_user_id
			|| IgnoredUsers::isEitherDirectionBlocked((int) $actor->user_id, (int) $target->message_user_id)) return false;
		$recipient = \XF::em()->find('XF:User', (int) $target->message_user_id);
		return $recipient && self::canViewAs($actor, $target, true) && self::canViewAs($recipient, $target);
	}

	public static function canViewAs($user, $message, bool $writing = false): bool
	{
		if (!$user || $user->user_state !== 'valid' || $user->is_banned || !$message->Room
			|| $message->Room->room_state !== 'visible' || !\XF::options()->siropuChatEnabled) return false;
		return (bool) \XF::asVisitor($user, static function () use ($user, $message, $writing)
		{
			$room = $message->Room;
			if (!method_exists($user, 'canViewSiropuChat') || !$user->canViewSiropuChat()
				|| $user->isBannedSiropuChat() || !($room->isJoined() || $room->canJoin())
				|| !ChatInteraction::canUseMessage($message)) return false;
			if (!$writing) return true;
			return $user->canUseSiropuChat() && !$user->isMutedSiropuChat()
				&& !$room->isReadOnly() && !$room->isLocked()
				&& !($user->isSanctionedSiropuChat() && $user->siropuChatGetRoomSanction((int) $room->room_id));
		});
	}

	private static function enqueue(string $key, array $data): void
	{
		\XF::app()->jobManager()->enqueueUnique('ekitapligimIosChat:' . $key,
			'Ekitapligim\IosApi:SendChatInteractionPush', $data, false);
	}

	public static function canActAs($actor, $message, string $kind): bool
	{
		return (bool) \XF::asVisitor($actor, static function () use ($message, $kind)
		{
			return $kind === 'quote' ? (bool) $message->canQuote()
				: ($kind === 'reaction' && \XF::options()->siropuChatReactions && $message->canReact());
		});
	}
}
