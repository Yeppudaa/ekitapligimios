<?php

namespace Ekitapligim\IosApi\Service;

use XF\Entity\User;

final class ProfileVisit
{
	private const VISIT_INTERVAL = 900;

	public static function record(User $visitor, User $profileUser): bool
	{
		$visitorId = (int) $visitor->user_id;
		$profileUserId = (int) $profileUser->user_id;
		if ($visitorId <= 0 || $profileUserId <= 0 || $visitorId === $profileUserId)
		{
			return false;
		}

		if ($profileUser->is_banned || $profileUser->user_state !== 'valid')
		{
			return false;
		}

		if (!$profileUser->canViewFullProfile())
		{
			return false;
		}

		if (IgnoredUsers::isEitherDirectionBlocked($visitorId, $profileUserId))
		{
			return false;
		}

		if (!self::canReceiveVisitAlert($profileUser, $visitor))
		{
			return false;
		}

		if (self::wasRecentlyRecorded($visitorId, $profileUserId))
		{
			return false;
		}

		try
		{
			/** @var \XF\Repository\UserAlertRepository $alertRepo */
			$alertRepo = \XF::repository('XF:UserAlert');
			$alertRepo->alert($profileUser, $visitorId, 'user', 'profile_visit');
		}
		catch (\Throwable $e)
		{
			\XF::logException($e, false, 'IosApi profile visit alert: ');
			return false;
		}

		return true;
	}

	private static function canReceiveVisitAlert(User $profileUser, User $visitor): bool
	{
		/** @var \XF\Repository\UserAlertRepository $alertRepo */
		$alertRepo = \XF::repository('XF:UserAlert');
		if (method_exists($alertRepo, 'userReceivesAlert'))
		{
			return $alertRepo->userReceivesAlert($profileUser, 'user', 'profile_visit', $visitor);
		}

		return true;
	}

	private static function wasRecentlyRecorded(int $visitorId, int $profileUserId): bool
	{
		$cutoff = \XF::$time - self::VISIT_INTERVAL;
		return (bool) \XF::db()->fetchOne(
			'SELECT 1
			 FROM xf_user_alert
			 WHERE alerted_user_id = ?
			   AND user_id = ?
			   AND content_type = ?
			   AND action = ?
			   AND event_date >= ?
			 LIMIT 1',
			[$profileUserId, $visitorId, 'user', 'profile_visit', $cutoff]
		);
	}
}
