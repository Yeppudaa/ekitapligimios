<?php

namespace Ekitapligim\IosApi\Api\Controller;

use Ekitapligim\IosApi\Service\MobilePresence;

class MePresence extends \Ekitapligim\MobileApi\Api\Controller\AbstractMobileController
{
	public function actionPost()
	{
		$this->assertMobileWriteScope();
		$visitor = $this->assertRegisteredApiUser();
		MobilePresence::touch($visitor);

		return $this->apiResult(['success' => true]);
	}
}
