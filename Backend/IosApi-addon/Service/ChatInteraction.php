<?php

namespace Ekitapligim\IosApi\Service;

/** Uses Siropu's quote BBCode and XenForo's existing Reaction repository. */
final class ChatInteraction
{
	public const CONTENT_TYPE = 'siropu_chat_room_message';

	public static function canUseMessage($message): bool
	{
		return (int) $message->message_user_id > 0
			&& in_array((string) $message->message_type, ['chat', 'me'], true)
			&& !$message->isIgnored() && !$message->isIgnoredUser()
			&& $message->canView() && $message->isPastJoinTime() && $message->canViewContent();
	}

	public static function canInteract($message): bool
	{
		return self::canUseMessage($message) && !IgnoredUsers::isEitherDirectionBlocked(
			(int) \XF::visitor()->user_id, (int) $message->message_user_id
		);
	}

	public static function quoteBbCode(\Siropu\Chat\Entity\Message $message): string
	{
		$inner = \XF::app()->stringFormatter()->getBbCodeForQuote(
			(string) $message->message_text, self::CONTENT_TYPE
		);
		$quote = (string) $message->getQuoteWrapper($inner);
		// XF's quote renderer accepts named attributes. Put member first so it does
		// not interpret our message reference as an unsupported public source link.
		return self::withMessageReference($quote, $message);
	}

	public static function withMessageReference(string $quote, $message): string
	{
		if (preg_match('/^\[QUOTE="[^"\r\n]*,\s*ek_message\s*:/i', $quote)) return $quote;
		return (string) preg_replace('/^(\[QUOTE="[^"\r\n]*)"\]/i',
			'$1, member: ' . (int) $message->message_user_id . ', ek_message: ' . (int) $message->message_id . '"]', $quote, 1);
	}

	/** Returns a leading quote separately while respecting nested quote tags. */
	public static function splitQuote(string $text): ?array
	{
		if (!preg_match('/^\s*\[QUOTE(?:="([^"\r\n]*)"|=([^\]\r\n]*))?\]/i', $text, $opening)) return null;
		$start = strlen($opening[0]);
		preg_match_all('/\[(?:QUOTE(?:="[^"\r\n]*"|=[^\]\r\n]*)?|\/QUOTE)\]/i', $text, $tags, PREG_OFFSET_CAPTURE, $start);
		$depth = 1;
		foreach ($tags[0] AS [$tag, $offset])
		{
			$depth += stripos($tag, '[/QUOTE') === 0 ? -1 : 1;
			if ($depth !== 0) continue;
			$option = (string) (!empty($opening[1]) ? $opening[1] : ($opening[2] ?? ''));
			$parts = explode(',', $option);
			$name = trim((string) array_shift($parts));
			$attributes = [];
			foreach ($parts AS $part)
			{
				if (preg_match('/^\s*(member|ek_message)\s*:\s*([1-9][0-9]*)\s*$/i', $part, $attribute))
					$attributes[strtolower($attribute[1])] = (int) $attribute[2];
			}
			return ['username' => $name, 'message_id' => $attributes['ek_message'] ?? 0,
				'user_id' => $attributes['member'] ?? 0, 'inner' => substr($text, $start, $offset - $start),
				'remainder' => trim(substr($text, $offset + strlen($tag))),
				'has_reference' => (bool) preg_match('/(?:^|,)\s*ek_message\b/i', $option)];
		}
		return null;
	}

	/** Check every quote, including nested/inline quotes, before rendering its body. */
	public static function filterQuotes(string $text, callable $isVisible): string
	{
		preg_match_all('/\[(?:QUOTE(?:="[^"\r\n]*"|=[^\]\r\n]*)?|\/QUOTE)\]/i', $text, $tags, PREG_OFFSET_CAPTURE);
		$frames = [['opening' => '', 'text' => '', 'visible' => true]];
		$cursor = 0;
		foreach ($tags[0] AS [$tag, $offset])
		{
			$index = count($frames) - 1;
			$frames[$index]['text'] .= substr($text, $cursor, $offset - $cursor);
			if (stripos($tag, '[/QUOTE') === 0)
			{
				if ($index > 0)
				{
					$frame = array_pop($frames);
					if ($frame['visible']) $frames[$index - 1]['text'] .= $frame['opening'] . $frame['text'] . $tag;
				}
				else $frames[0]['text'] .= $tag;
			}
			else
			{
				$quote = self::splitQuote($tag . '[/QUOTE]');
				$frames[] = ['opening' => $tag, 'text' => '', 'visible' => $quote && (bool) $isVisible($quote)];
			}
			$cursor = $offset + strlen($tag);
		}
		$frames[count($frames) - 1]['text'] .= substr($text, $cursor);
		// An unclosed unavailable reference must not fall back to readable raw text.
		while (count($frames) > 1)
		{
			$frame = array_pop($frames);
			if ($frame['visible']) $frames[count($frames) - 1]['text'] .= $frame['opening'] . $frame['text'];
		}
		return $frames[0]['text'];
	}

	/** Desired state: repeating the same request must never toggle a reaction off. */
	public static function setReaction($repository, $message, $visitor, int $reactionId): array
	{
		$existing = $repository->getReactionByContentAndReactionUser(
			self::CONTENT_TYPE, (int) $message->message_id, (int) $visitor->user_id
		);
		$previousId = $existing ? (int) $existing->reaction_id : 0;
		if ($previousId === $reactionId) return ['changed' => false, 'reaction' => $existing];
		if ($reactionId === 0)
		{
			if ($existing) $existing->delete();
			return ['changed' => $previousId > 0, 'reaction' => null];
		}
		$reaction = $repository->reactToContent($reactionId, self::CONTENT_TYPE,
			(int) $message->message_id, $visitor, true);
		return ['changed' => $reaction && (int) $reaction->reaction_id === $reactionId, 'reaction' => $reaction];
	}
}
