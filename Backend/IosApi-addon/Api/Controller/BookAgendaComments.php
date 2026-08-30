<?php

namespace Ekitapligim\IosApi\Api\Controller;

class BookAgendaComments extends \Ekitapligim\MobileApi\Api\Controller\BookAgendaComments
{
	use UgcControllerTrait;
	public function actionGet(\XF\Mvc\ParameterBag $params)
	{
		return $this->filterReplyCollections(parent::actionGet($params), ['items', 'comments']);
	}
	public function actionPost(\XF\Mvc\ParameterBag $params)
	{
		if ($error = $this->validateUgcWrite([(string) $this->filter('message', 'str')])) return $error;
		return parent::actionPost($params);
	}
}
