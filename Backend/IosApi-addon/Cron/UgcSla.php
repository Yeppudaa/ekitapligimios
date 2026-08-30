<?php

namespace Ekitapligim\IosApi\Cron;

use Ekitapligim\IosApi\Service\UgcModeration;

final class UgcSla
{
	public static function run(): void
	{
		UgcModeration::ensureTable();
		\XF::db()->query(
			"UPDATE xf_ekitapligim_ios_ugc_event e
			 INNER JOIN xf_report r ON (r.report_id = e.report_id)
			 SET e.actioned_at = IF(e.actioned_at = 0 AND r.report_state IN ('assigned', 'resolved', 'rejected'), r.last_modified_date, e.actioned_at),
			     e.closed_at = IF(e.closed_at = 0 AND r.report_state IN ('resolved', 'rejected'), r.last_modified_date, e.closed_at)"
		);
		$rows = \XF::db()->fetchAll(
			"SELECT e.* FROM xf_ekitapligim_ios_ugc_event e
			 LEFT JOIN xf_report r ON (r.report_id = e.report_id)
			 WHERE e.report_id = 0 OR r.report_state IN ('open', 'assigned')"
		);
		foreach ($rows AS $row)
		{
			$age = \XF::$time - (int) $row['created_at'];
			$level = null;
			if ($age >= 86400 && !(int) $row['escalated_at']) $level = 'escalation';
			else if ($age >= 72000 && !(int) $row['reminded_at']) $level = 'reminder';
			if ($level)
			{
				\XF::app()->jobManager()->enqueueUnique(
					'ekIosUgcSla' . $level . (int) $row['event_id'],
					'Ekitapligim\IosApi:UgcModerationMail',
					['event_id' => (int) $row['event_id'], 'escalation' => $level],
					false
				);
			}
		}
	}
}
