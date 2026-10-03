<?php

namespace Ekitapligim\IosApi\Service;

class ChatSerializer
{
	protected ?array $reactionOptions = null;
	public function room(\Siropu\Chat\Entity\Room $room): array
	{
		return [
			'id' => (string) $room->room_id,
			'room_id' => (int) $room->room_id,
			'name' => (string) $room->room_name,
			'description' => $this->plainText((string) $room->room_description),
			'user_count' => (int) $room->room_user_count,
			'last_activity' => (int) $room->room_last_activity,
			'is_read_only' => (bool) $room->isReadOnly(),
			'is_locked' => (bool) $room->isLocked(),
			'is_private' => (bool) $room->isPrivate(),
			'is_joined' => (bool) (\XF::visitor()->user_id && $room->isJoined()),
			'can_send' => (bool) $this->canSend($room),
			'app_route' => 'chat/' . (int) $room->room_id,
			'target_url' => $this->absolute((string) \XF::app()->router('public')->buildLink('canonical:chat/room', $room)),
		];
	}

	public function message(\Siropu\Chat\Entity\Message $message): array
	{
		$user = $message->User;
		$visitor = \XF::visitor();
		$username = (string) ($message->message_username ?: $message->message_bot_name ?: 'E-Kitaplığım');
		$rawText = ChatInteraction::filterQuotes((string) $message->getMessage(),
			fn(array $quote) => $this->quoteIsVisible($quote, (int) $message->message_room_id));
		$split = ChatInteraction::splitQuote($rawText);
		$quoted = $this->quotedMessage($split, (int) $message->message_room_id);
		$reactions = [];
		$options = array_column($this->reactionOptions(), null, 'reaction_id');
		foreach ((array) $message->reactions AS $reactionId => $count)
		{
			if ((int) $count > 0 && isset($options[(int) $reactionId]))
				$reactions[] = $options[(int) $reactionId] + ['count' => (int) $count];
		}
		$canInteract = (bool) ($visitor->user_id && ChatInteraction::canInteract($message)
			&& $message->Room && $this->canSend($message->Room) && !$visitor->isMutedSiropuChat()
			&& !($visitor->isSanctionedSiropuChat() && $visitor->siropuChatGetRoomSanction((int) $message->message_room_id)));

		return [
			'id' => (string) $message->message_id,
			'message_id' => (int) $message->message_id,
			'room_id' => (int) $message->message_room_id,
			'user_id' => (int) $message->message_user_id,
			'username' => $username,
			// Preserve the displayed field for existing clients; new clients render the
			// quote separately and use message_body to avoid showing it twice.
			'message' => $this->plainText($rawText),
			'message_body' => $this->plainText($split ? $split['remainder'] : $rawText),
			'message_type' => (string) $message->message_type,
			'message_date' => (int) $message->message_date,
			'avatar_url' => $user && $user->user_id
				? $this->absolute((string) $user->getAvatarUrl('m', null, true))
				: '',
			'is_mine' => (bool) ($visitor->user_id && $message->message_user_id === $visitor->user_id),
			'is_bot' => (bool) $message->isBot(),
			'is_announcement' => (bool) $message->isAnnouncement(),
			'is_edited' => (bool) $message->isEdited(),
			'is_admin' => (bool) ($user && $user->is_admin),
			'is_moderator' => (bool) ($user && $user->is_moderator),
			'is_staff' => (bool) ($user && $user->is_staff),
			'like_count' => (int) $message->message_like_count,
			'is_liked' => (bool) ($visitor->user_id && $message->isLiked()),
			'can_quote' => (bool) ($canInteract && $message->canQuote()),
			'can_react' => (bool) ($canInteract && \XF::options()->siropuChatReactions && $message->canReact()),
			'visitor_reaction_id' => (int) ($visitor->user_id ? $message->getVisitorReactionId() : 0),
			'reaction_count' => array_sum(array_column($reactions, 'count')),
			'reactions' => $reactions,
			'quoted_message' => $quoted,
		];
	}

	public function reactionOptions(): array
	{
		if ($this->reactionOptions !== null) return $this->reactionOptions;
		$this->reactionOptions = [];
		if (!\XF::options()->siropuChatReactions) return [];
		foreach (\XF::repository('XF:Reaction')->findReactionsForList(true)->fetch() AS $reaction)
		{
			$this->reactionOptions[] = ['reaction_id' => (int) $reaction->reaction_id,
				'title' => (string) $reaction->title,
				'emoji' => method_exists($reaction, 'getEmoji') ? (string) $reaction->getEmoji() : '',
				'image_url' => $this->absolute((string) $reaction->image_url),
				'sprite_mode' => (bool) $reaction->sprite_mode,
				'sprite_params' => (array) $reaction->sprite_params];
		}
		return $this->reactionOptions;
	}

	protected function quoteIsVisible(array $quote, int $roomId): bool
	{
		if (!$quote['has_reference']) return true;
		if ($quote['message_id'] <= 0) return false;
		$target = \XF::em()->find('Siropu\Chat:Message', $quote['message_id']);
		return $target && (int) $target->message_room_id === $roomId
			&& ($quote['user_id'] === 0 || (int) $target->message_user_id === $quote['user_id'])
			&& ChatInteraction::canInteract($target);
	}

	protected function quotedMessage(?array $split, int $roomId): ?array
	{
		if (!$split) return null;
		if ($split['message_id'] > 0)
		{
			$target = \XF::em()->find('Siropu\Chat:Message', $split['message_id']);
			if (!$this->quoteIsVisible($split, $roomId)) return null;
			return ['message_id' => (int) $target->message_id, 'user_id' => (int) $target->message_user_id,
				'username' => (string) $target->message_username, 'message' => $this->plainText($split['inner'])];
		}
		// Existing Siropu web quotes contain only a name, so no invented identity.
		return ['message_id' => 0, 'user_id' => 0, 'username' => $this->plainText($split['username']),
			'message' => $this->plainText($split['inner'])];
	}

	public function plainText(string $value): string
	{
		$value = \XF::app()->stringFormatter()->stripBbCode($value, ['stripQuote' => false]);
		$value = html_entity_decode(strip_tags($value), ENT_QUOTES | ENT_HTML5, 'UTF-8');
		$value = preg_replace('/[\t ]+/u', ' ', $value);
		$value = preg_replace('/\R{3,}/u', "\n\n", $value);

		return trim((string) $value);
	}

	protected function canSend(\Siropu\Chat\Entity\Room $room): bool
	{
		$visitor = \XF::visitor();
		return (bool) (
			$visitor->user_id
			&& method_exists($visitor, 'canUseSiropuChat')
			&& $visitor->canUseSiropuChat()
			&& !$visitor->isBannedSiropuChat()
			&& !$room->isReadOnly()
			&& !$room->isLocked()
			&& ($room->isJoined() || $room->canJoin())
		);
	}

	protected function absolute(string $url): string
	{
		if ($url === '' || preg_match('#^https?://#i', $url))
		{
			return $url;
		}

		return rtrim((string) \XF::options()->boardUrl, '/') . '/' . ltrim($url, '/');
	}
}
