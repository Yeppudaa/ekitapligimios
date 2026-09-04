<?php

namespace Ekitapligim\IosApi\Api\Controller;

use Ekitapligim\IosApi\Service\IgnoredUsers;
use Ekitapligim\IosApi\Service\NotificationCounts;

class Conversations extends \Ekitapligim\MobileApi\Api\Controller\Conversations
{
	use UgcControllerTrait;
	public function actionGet(\XF\Mvc\ParameterBag $params)
	{
		return $this->filterConversationReply(parent::actionGet($params));
	}
	public function actionMessages(\XF\Mvc\ParameterBag $params)
	{
		return $this->filterConversationReply(parent::actionMessages($params));
	}
	public function actionPost(\XF\Mvc\ParameterBag $params)
	{
		if ($error = $this->validateUgcWrite([(string) $this->filter('title', 'str'), (string) $this->filter('message', 'str')])) return $error;
		$visitorId = (int) \XF::visitor()->user_id;
		$recipientIds = $this->filter('recipient_ids', 'array-uint');
		$recipientId = (int) $this->filter('recipient_id', 'uint');
		if ($recipientId > 0) $recipientIds[] = $recipientId;
		$recipientName = trim((string) $this->filter('recipient', 'str'));
		if ($recipientName !== '')
		{
			$namedId = (int) \XF::db()->fetchOne('SELECT user_id FROM xf_user WHERE username = ?', [$recipientName]);
			if ($namedId > 0) $recipientIds[] = $namedId;
		}
		$recipientIds = array_values(array_unique(array_filter(array_map('intval', $recipientIds))));
		if (count($recipientIds) === 1 && IgnoredUsers::isEitherDirectionBlocked($visitorId, $recipientIds[0]))
		{
			return $this->apiError('Engellenen kullanıcıyla yeni konuşma başlatılamaz.', 'blocked_member', null, 403);
		}
		return $this->filterConversationReply(parent::actionPost($params));
	}
	public function actionReply(\XF\Mvc\ParameterBag $params)
	{
		if ($error = $this->validateUgcWrite([(string) $this->filter('message', 'str')])) return $error;
		$visitor = $this->assertRegisteredApiUser();
		$userConversation = $this->assertViewableConversation((int) $params->conversation_id, $visitor);
		$otherIds = [];
		foreach ($userConversation->Master->Recipients AS $recipient)
		{
			$id = (int) $recipient->user_id;
			if ($id > 0 && $id !== (int) $visitor->user_id) $otherIds[] = $id;
		}
		if (count(array_unique($otherIds)) === 1 && IgnoredUsers::isEitherDirectionBlocked((int) $visitor->user_id, $otherIds[0]))
		{
			return $this->apiError('Engellenen kullanıcıyla bire bir konuşmaya yanıt verilemez.', 'blocked_member', null, 403);
		}
		return $this->filterConversationReply(parent::actionReply($params));
	}

	public function actionRead(\XF\Mvc\ParameterBag $params)
	{
		$this->assertMobileWriteScope();
		$visitor = $this->assertRegisteredApiUser();
		$userId = (int) $visitor->user_id;
		$conversationId = (int) $params->conversation_id;
		$userConversation = $this->assertViewableConversation($conversationId, $visitor);

		$db = \XF::db();
		$db->beginTransaction();
		try
		{
			$db->update(
				'xf_conversation_recipient',
				['last_read_date' => \XF::$time],
				'conversation_id = ? AND user_id = ?',
				[$conversationId, $userId]
			);
			$db->update(
				'xf_conversation_user',
				['is_unread' => 0],
				'conversation_id = ? AND owner_user_id = ?',
				[$conversationId, $userId]
			);

			$unread = (int) $db->fetchOne(
				'SELECT COUNT(*) FROM xf_conversation_user WHERE owner_user_id = ? AND is_unread = 1',
				[$userId]
			);
			$db->update('xf_user', ['conversations_unread' => $unread], 'user_id = ?', [$userId]);
			$db->commit();
		}
		catch (\Throwable $e)
		{
			$db->rollback();
			throw $e;
		}

		return $this->apiResult(NotificationCounts::forUser($userId));
	}

	protected function filterConversationReply($reply)
	{
		$reply = $this->filterReplyCollections($reply, ['messages']);
		if (!is_object($reply) || !method_exists($reply, 'getApiResult')) return $reply;
		$result = $reply->getApiResult();
		if (!is_object($result) || !method_exists($result, 'getResult') || !method_exists($result, 'setResult')) return $reply;
		$payload = $result->getResult();
		$visitorId = (int) \XF::visitor()->user_id;
		$blocked = IgnoredUsers::ids($visitorId);
		$keepConversation = static function ($item) use ($blocked, $visitorId): bool
		{
			if (!is_array($item) || !$blocked) return true;
			$others = array_filter(array_map(static fn($participant) => (int) ($participant['user_id'] ?? $participant['userId'] ?? 0), $item['participants'] ?? []), static fn($id) => $id > 0 && $id !== $visitorId);
			return count($others) !== 1 || !isset($blocked[(int) reset($others)]);
		};
		foreach (['items', 'conversations'] AS $key)
		{
			if (isset($payload[$key]) && is_array($payload[$key])) $payload[$key] = array_values(array_filter($payload[$key], $keepConversation));
		}
		if (isset($payload['conversation']) && !$keepConversation($payload['conversation']))
		{
			return $this->apiError('Conversation not found.', 'conversation_not_found', null, 404);
		}
		$result->setResult($payload);
		return $reply;
	}
}
