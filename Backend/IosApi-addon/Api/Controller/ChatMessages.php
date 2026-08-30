<?php

namespace Ekitapligim\IosApi\Api\Controller;

class ChatMessages extends \Ekitapligim\MobileApi\Api\Controller\ChatMessages
{
	use UgcControllerTrait;
	public function actionGet(\XF\Mvc\ParameterBag $params)
	{
		return $this->filterReplyCollections(parent::actionGet($params), ['items', 'messages']);
	}
	public function actionPost(\XF\Mvc\ParameterBag $params)
	{
		if ($error = $this->validateUgcWrite([(string) $this->filter('message', 'str')])) return $error;
		return parent::actionPost($params);
	}
}
