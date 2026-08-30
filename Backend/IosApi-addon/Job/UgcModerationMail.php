<?php

namespace Ekitapligim\IosApi\Job;

use XF\Job\AbstractJob;

class UgcModerationMail extends AbstractJob
{
	protected $defaultData = ['event_id' => 0, 'escalation' => 'new'];

	public function run($maxRunTime): \XF\Job\JobResult
	{
		$eventId = (int) $this->data['event_id'];
		$event = \XF::db()->fetchRow('SELECT * FROM xf_ekitapligim_ios_ugc_event WHERE event_id = ?', [$eventId]);
		if (!$event) return $this->complete();
		$emails = array_values(array_unique(array_filter(array_map('trim', preg_split('/[,;\s]+/', (string) (\XF::options()->ekIosUgcModeratorEmails ?? '')) ?: []))));
		if (!$emails)
		{
			// Misconfiguration must not crash the XenForo job queue repeatedly.
			// Moderators still see reports in ACP; configure ekIosUgcModeratorEmails for email alerts.
			\XF::logError('IosApi UGC moderator email list is empty (option ekIosUgcModeratorEmails). Skipping mail for event ' . $eventId . '.');
			return $this->complete();
		}
		$level = (string) $this->data['escalation'];
		$subject = $level === 'new' ? 'Yeni iOS UGC güvenlik raporu' : 'iOS UGC raporu SLA uyarısı: ' . strtoupper($level);
		$body = sprintf(
			"Event ID: %d\nReport ID: %d\nContent: %s #%d\nReporter user ID: %d\nTarget user ID: %d\nReason: %s\nCreated: %s UTC\n\nİçeriği XenForo rapor kuyruğunda inceleyin. Özel içerik bu e-postaya eklenmemiştir.",
			$eventId, (int) $event['report_id'], (string) $event['content_type'], (int) $event['content_id'],
			(int) $event['reporter_user_id'], (int) $event['target_user_id'], (string) $event['reason_code'], gmdate('Y-m-d H:i:s', (int) $event['created_at'])
		);
		// Send one message per configured moderator so addresses are never exposed
		// to one another and setTo() cannot overwrite an earlier recipient.
		foreach ($emails AS $email)
		{
			$mail = \XF::app()->mailer()->newMail();
			$mail->setTo($email);
			$mail->setContent($subject, '', $body);
			$mail->send();
		}
		$field = $level === 'new' ? 'notified_at' : ($level === 'reminder' ? 'reminded_at' : 'escalated_at');
		\XF::db()->update('xf_ekitapligim_ios_ugc_event', [$field => \XF::$time], 'event_id = ?', [$eventId]);
		return $this->complete();
	}

	public function getStatusMessage(): string { return 'UGC moderasyon bildirimi gönderiliyor…'; }
	public function canCancel(): bool { return false; }
	public function canTriggerByChoice(): bool { return false; }
}
