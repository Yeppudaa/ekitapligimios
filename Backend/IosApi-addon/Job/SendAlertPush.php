<?php

namespace Ekitapligim\IosApi\Job;

use EKitapligim\BookNotifications\Repository\Campaign;
use EKitapligim\BookNotifications\Service\Guard;
use Ekitapligim\IosApi\Listener\AlertCreated;
use XF\Entity\UserAlert;
use XF\Job\AbstractJob;
use XF\Job\JobResult;

class SendAlertPush extends AbstractJob
{
	protected $defaultData = ['alert_id' => 0];

	public function run($maxRunTime): JobResult
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

		if ($alert->depends_on_addon_id === 'EKitapligim/BookNotifications'
			&& method_exists(Campaign::class, 'findIosDeliveryRecipient')
			&& in_array($alert->action, [Guard::ACTION, Guard::PREMIUM_ACTION], true))
		{
			$noticeId = (int) ($alert->extra_data['notice_id'] ?? 0);
			if ($noticeId > 0)
			{
				return $this->deliverCampaignAlert($alert, $noticeId);
			}
		}

		AlertCreated::deliver($alert);
		return $this->complete();
	}

	private function deliverCampaignAlert(UserAlert $alert, int $noticeId): JobResult
	{
		/** @var Campaign $campaigns */
		$campaigns = $this->app->repository(Campaign::class);
		$userId = (int) $alert->alerted_user_id;
		$recipient = $campaigns->findIosDeliveryRecipient($noticeId, $userId);
		if ($recipient === null)
		{
			if (!isset($this->data['campaign_apns_accepted']))
			{
				AlertCreated::deliver($alert);
			}
			return $this->complete();
		}
		if ($recipient['ios_accepted_count'] !== null)
		{
			return $this->complete();
		}

		$accepted = $this->data['campaign_apns_accepted'] ?? AlertCreated::deliver($alert)['sent'];
		try
		{
			$campaigns->recordIosAcceptedCount($noticeId, $userId, $accepted);
		}
		catch (\Exception $e)
		{
			// Retry writing the result without sending the notification again.
			$this->data['campaign_apns_accepted'] = $accepted;
			if ($this->previousAttempts >= 3)
			{
				return $this->fail($e);
			}
			return JobResult::newReattempt($this->jobId, time() + 30, $this->data);
		}

		return $this->complete();
	}

	public function getStatusMessage(): string { return 'iOS bildirimi APNs üzerinden gönderiliyor…'; }
	public function canCancel(): bool { return false; }
	public function canTriggerByChoice(): bool { return false; }
}
