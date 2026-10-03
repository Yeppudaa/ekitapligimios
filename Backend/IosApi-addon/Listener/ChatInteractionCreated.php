<?php

namespace Ekitapligim\IosApi\Listener;

use Ekitapligim\IosApi\Service\ChatInteraction;
use Ekitapligim\IosApi\Service\ChatPushProducer;

final class ChatInteractionCreated
{
	public static function onRoomMessage($message): void
	{
		if (!$message->isInsert() || !ChatPushProducer::isPublicMessage($message)) return;
		try
		{
			$quote = ChatInteraction::splitQuote((string) $message->message_text);
			if (!$quote || (int) $quote['message_id'] <= 0 || (int) $quote['user_id'] <= 0) return;
			$target = \XF::em()->find('Siropu\Chat:Message', (int) $quote['message_id']);
			$actor = \XF::em()->find('XF:User', (int) $message->message_user_id);
			if ($target && $actor) ChatPushProducer::enqueueQuote($target, $message, $actor);
		}
		catch (\Throwable $error) { \XF::logException($error, false, 'IosApi room quote notification: '); }
	}

	public static function onReaction($reaction): void
	{
		if (!$reaction->isInsert() || (string) $reaction->content_type !== ChatInteraction::CONTENT_TYPE) return;
		try
		{
			$target = \XF::em()->find('Siropu\Chat:Message', (int) $reaction->content_id);
			$actor = \XF::em()->find('XF:User', (int) $reaction->reaction_user_id);
			if ($target && $actor) ChatPushProducer::enqueueReaction($target, $actor, $reaction, (int) $reaction->reaction_id);
		}
		catch (\Throwable $error) { \XF::logException($error, false, 'IosApi room reaction notification: '); }
	}
}
