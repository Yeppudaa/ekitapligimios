<?php

namespace Ekitapligim\IosApi\Api\Controller;

class BookAgenda extends \Ekitapligim\MobileApi\Api\Controller\BookAgenda
{
	use UgcControllerTrait;
	use AgendaMediaUploadTrait;
	public function actionGet()
	{
		if ($this->filter('media_capabilities', 'bool')) return $this->mediaCapabilities();
		$reply = $this->applyAgendaViewerFlags($this->filterReplyCollections(parent::actionGet(), ['items']), ['items']);
		return (new \Ekitapligim\IosApi\Service\AgendaMediaSerializer())->decorateReply($reply);
	}
	public function actionPost(\XF\Mvc\ParameterBag $params)
	{
		if ($error = $this->validateUgcWrite([
			(string) $this->filter('message', 'str'),
			(string) $this->filter('review_title', 'str'),
		])) return $error;
		if ($this->filter('image_upload', 'bool')) return $this->applyAgendaViewerFlags($this->createPostWithImage(), []);
		return parent::actionPost($params);
	}
}
