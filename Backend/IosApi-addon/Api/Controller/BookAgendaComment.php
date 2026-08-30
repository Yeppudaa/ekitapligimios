<?php

namespace Ekitapligim\IosApi\Api\Controller;

class BookAgendaComment extends \Ekitapligim\MobileApi\Api\Controller\BookAgendaComment
{
	use UgcControllerTrait;
	public function actionPatch(\XF\Mvc\ParameterBag $params)
	{
		if ($error = $this->validateUgcWrite([(string) $this->filter('message', 'str')])) return $error;
		return parent::actionPatch($params);
	}
}
