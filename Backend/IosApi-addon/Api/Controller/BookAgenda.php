<?php

namespace Ekitapligim\IosApi\Api\Controller;

class BookAgenda extends \Ekitapligim\MobileApi\Api\Controller\BookAgenda
{
	use UgcControllerTrait;
	public function actionGet()
	{
		return $this->applyAgendaViewerFlags($this->filterReplyCollections(parent::actionGet(), ['items']), ['items']);
	}
	public function actionPost(\XF\Mvc\ParameterBag $params)
	{
		if ($error = $this->validateUgcWrite([
			(string) $this->filter('message', 'str'),
			(string) $this->filter('review_title', 'str'),
		])) return $error;
		return parent::actionPost($params);
	}
}
