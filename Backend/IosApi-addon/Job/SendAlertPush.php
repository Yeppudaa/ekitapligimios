<?php

namespace Ekitapligim\IosApi\Job;

use Ekitapligim\IosApi\Listener\AlertCreated;
use XF\Job\AbstractJob;

class SendAlertPush extends AbstractJob
{
	protected $defaultData = ['alert_id' => 0];

	public function run($maxRunTime): \XF\Job\JobResult
	{
		$alertId = (int) $this->data['alert_id'];
		if ($alertId <= 0)
		{
			return $this->complete();
		}

		$alert = $this->app->em()->find('XF:UserAlert', $alertId);
		if (!$alert)
		{
			return $this->complete();
		}

		AlertCreated::deliver($alert);
		return $this->complete();
	}

	public function getStatusMessage(): string { return 'iOS bildirimi APNs üzerinden gönderiliyor…'; }
	public function canCancel(): bool { return false; }
	public function canTriggerByChoice(): bool { return false; }
}
