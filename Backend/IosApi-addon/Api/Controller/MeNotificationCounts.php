<?php

namespace Ekitapligim\IosApi\Api\Controller;

use Ekitapligim\IosApi\Service\NotificationCounts;

class MeNotificationCounts extends \Ekitapligim\MobileApi\Api\Controller\AbstractMobileController
{
	public function actionGet()
	{
		$this->assertMobileScope('alert:read');
		$visitor = $this->assertRegisteredApiUser();

		return $this->apiResult(NotificationCounts::forUser((int) $visitor->user_id));
	}
}
