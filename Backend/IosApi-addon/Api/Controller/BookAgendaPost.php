<?php

namespace Ekitapligim\IosApi\Api\Controller;

use Ekitapligim\IosApi\Service\IgnoredUsers;

class BookAgendaPost extends \Ekitapligim\MobileApi\Api\Controller\BookAgendaPost
{
	use UgcControllerTrait;
	public function actionGet(\XF\Mvc\ParameterBag $params)
	{
		if ($imageId = $this->filter('image_id', 'uint')) return $this->agendaImage($params, $imageId);
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
		$reply = $this->applyAgendaViewerFlags($reply, []);
		return (new \Ekitapligim\IosApi\Service\AgendaMediaSerializer())->decorateReply($reply);
	}

	protected function agendaImage(\XF\Mvc\ParameterBag $params, int $imageId)
	{
		$this->assertMobileScope();
		if (!\XF::visitor()->hasPermission('ekSocial', 'view'))
			return $this->apiError('Image not found.', 'content_not_found', null, 404);
		$post = $this->repository('Ekitapligim\Social:Feed')->getPost((int) $params->post_id);
		$blocked = IgnoredUsers::ids((int) \XF::visitor()->user_id);
		if (!$post || !$post->canView() || isset($blocked[(int) $post->user_id]))
			return $this->apiError('Image not found.', 'content_not_found', null, 404);
		$attachment = $post->Attachments[$imageId] ?? null;
		if (!$attachment || $attachment->content_type !== 'ek_social_post'
			|| (int) $attachment->content_id !== (int) $post->post_id || $attachment->temp_hash
			|| !$attachment->Data || !$attachment->width || !$attachment->height || !$attachment->Data->isDataAvailable())
			return $this->apiError('Image not found.', 'content_not_found', null, 404);
		$this->setResponseType('raw');
		return $this->view(\Ekitapligim\IosApi\Pub\View\AgendaImage::class, '', ['attachment' => $attachment]);
	}
	public function actionPatch(\XF\Mvc\ParameterBag $params)
	{
		if ($error = $this->validateUgcWrite([(string) $this->filter('message', 'str')])) return $error;
		return parent::actionPatch($params);
	}

	public function actionPost(\XF\Mvc\ParameterBag $params)
	{
		return $this->actionPatch($params);
	}
}
