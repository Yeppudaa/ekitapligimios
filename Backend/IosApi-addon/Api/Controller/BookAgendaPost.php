<?php

namespace Ekitapligim\IosApi\Api\Controller;

use Ekitapligim\IosApi\Service\IgnoredUsers;

class BookAgendaPost extends \Ekitapligim\MobileApi\Api\Controller\BookAgendaPost
{
	use UgcControllerTrait;
	public function actionGet(\XF\Mvc\ParameterBag $params)
	{
		$reply = $this->filterReplyCollections(parent::actionGet($params), []);
		if (!is_object($reply) || !method_exists($reply, 'getApiResult')) return $reply;
		$result = $reply->getApiResult();
		if (!is_object($result) || !method_exists($result, 'getResult')) return $reply;
		$payload = $result->getResult();
		$post = $payload['post'] ?? null;
		$userId = is_array($post) ? (int) ($post['user_id'] ?? $post['userId'] ?? $post['actor']['id'] ?? 0) : 0;
		$blocked = IgnoredUsers::ids((int) \XF::visitor()->user_id);
		if ($userId > 0 && isset($blocked[$userId]))
		{
			return $this->apiError('Post not found.', 'content_not_found', null, 404);
		}
		return $reply;
	}
	public function actionPatch(\XF\Mvc\ParameterBag $params)
	{
		if ($error = $this->validateUgcWrite([(string) $this->filter('message', 'str')])) return $error;
		return parent::actionPatch($params);
	}
}
