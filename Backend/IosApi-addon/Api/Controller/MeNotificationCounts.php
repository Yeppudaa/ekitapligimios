<?php

namespace Ekitapligim\IosApi\Api\Controller;

class MeNotificationCounts extends \Ekitapligim\MobileApi\Api\Controller\AbstractMobileController
{
	public function actionGet()
	{
		$this->assertMobileScope('alert:read');
		$visitor = $this->assertRegisteredApiUser();

		return $this->apiResult([
			'unread' => (int) $visitor->alerts_unread,
			'unviewed' => (int) $visitor->alerts_unviewed,
			'conversations_unread' => (int) $visitor->conversations_unread,
			'conversationsUnread' => (int) $visitor->conversations_unread,
		]);
	}
}
