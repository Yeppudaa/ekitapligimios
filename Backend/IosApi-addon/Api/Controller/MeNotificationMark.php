<?php

namespace Ekitapligim\IosApi\Api\Controller;

use XF\Entity\UserAlert;
use XF\Mvc\ParameterBag;
use XF\Repository\UserAlertRepository;

class MeNotificationMark extends \Ekitapligim\MobileApi\Api\Controller\AbstractMobileController
{
	public function actionPost(ParameterBag $params)
	{
		$this->assertMobileWriteScope();
		$visitor = $this->assertRegisteredApiUser();
		$alert = $this->assertOwnedAlert((int) $params->alert_id, (int) $visitor->user_id);

		if ($this->filter('unread', 'bool'))
		{
			$this->getAlertRepo()->markUserAlertUnread($alert);
		}
		else if ($this->filter('viewed', 'bool'))
		{
			$this->getAlertRepo()->markUserAlertViewed($alert);
		}
		else
		{
			$this->getAlertRepo()->markUserAlertRead($alert);
		}

		return $this->apiSuccess();
	}

	protected function assertOwnedAlert(int $alertId, int $userId): UserAlert
	{
		/** @var UserAlert|null $alert */
		$alert = $this->em()->find(UserAlert::class, $alertId, 'api');
		if (!$alert || (int) $alert->alerted_user_id !== $userId)
		{
			throw $this->exception($this->apiError('Notification not found.', 'notification_not_found'));
		}

		return $alert;
	}

	protected function getAlertRepo(): UserAlertRepository
	{
		return $this->repository(UserAlertRepository::class);
	}
}
