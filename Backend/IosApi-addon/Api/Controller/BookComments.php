<?php

namespace Ekitapligim\IosApi\Api\Controller;

class BookComments extends \Ekitapligim\MobileApi\Api\Controller\BookComments
{
	use UgcControllerTrait;
	public function actionGet(\XF\Mvc\ParameterBag $params)
	{
		return $this->filterReplyCollections($this->addCommentUserIds(parent::actionGet($params)), ['comments', 'items']);
	}
	public function actionPost(\XF\Mvc\ParameterBag $params)
	{
		if ($error = $this->validateUgcWrite([(string) $this->filter('message', 'str')])) return $error;
		return $this->addCommentUserIds(parent::actionPost($params));
	}

	protected function addCommentUserIds($reply)
	{
		if (!is_object($reply) || !method_exists($reply, 'getApiResult')) return $reply;
		$result = $reply->getApiResult();
		if (!is_object($result) || !method_exists($result, 'getResult') || !method_exists($result, 'setResult')) return $reply;
		$payload = $result->getResult();
		$ids = [];
		foreach (['comments', 'items'] AS $key)
		{
			foreach (($payload[$key] ?? []) AS $item)
			{
				$id = (int) ($item['post_id'] ?? $item['id'] ?? 0);
				if ($id > 0) $ids[] = $id;
			}
		}
		if (isset($payload['comment']) && is_array($payload['comment']))
		{
			$id = (int) ($payload['comment']['post_id'] ?? $payload['comment']['id'] ?? 0);
			if ($id > 0) $ids[] = $id;
		}
		$userIds = $ids ? \XF::db()->fetchPairs('SELECT post_id, user_id FROM xf_post WHERE post_id IN (' . \XF::db()->quote($ids) . ')') : [];
		$decorate = static function (array $item) use ($userIds): array
		{
			$id = (int) ($item['post_id'] ?? $item['id'] ?? 0);
			$userId = (int) ($userIds[$id] ?? 0);
			$item['user_id'] = $userId;
			$item['userId'] = $userId;
			$item['post_id'] = $id;
			return $item;
		};
		foreach (['comments', 'items'] AS $key)
		{
			if (isset($payload[$key]) && is_array($payload[$key])) $payload[$key] = array_map($decorate, $payload[$key]);
		}
		if (isset($payload['comment']) && is_array($payload['comment'])) $payload['comment'] = $decorate($payload['comment']);
		$result->setResult($payload);
		return $reply;
	}
}
