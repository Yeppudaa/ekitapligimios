<?php

namespace Ekitapligim\IosApi\Service;

use XF\Entity\User;

final class MobilePresence
{
	private const TOUCH_INTERVAL = 60;

	/** @var array<int, int> */
	private static array $lastTouch = [];

	public static function touch(User $user): void
	{
		$userId = (int) $user->user_id;
		if ($userId <= 0)
		{
			return;
		}

		$now = \XF::$time;
		if (isset(self::$lastTouch[$userId]) && ($now - self::$lastTouch[$userId]) < self::TOUCH_INTERVAL)
		{
			return;
		}
		self::$lastTouch[$userId] = $now;

		try
		{
			/** @var \XF\Repository\SessionActivityRepository $activityRepo */
			$activityRepo = \XF::repository('XF:SessionActivity');
			$activityRepo->updateSessionActivity(
				$userId,
				(string) \XF::app()->request()->getIp(),
				'Ekitapligim/IosApi',
				'MobileApi',
				[],
				'valid',
				''
			);

			if ((int) $user->last_activity < $now)
			{
				$user->fastUpdate('last_activity', $now);
			}
		}
		catch (\Throwable $e)
		{
			\XF::logException($e, false, 'IosApi mobile presence touch: ');
		}
	}

	public static function isUserOnline(int $userId): bool
	{
		if ($userId <= 0)
		{
			return false;
		}

		$user = \XF::em()->find('XF:User', $userId);
		if (!$user || !$user->activity_visible)
		{
			return false;
		}

		try
		{
			/** @var \XF\Repository\SessionActivityRepository $activityRepo */
			$activityRepo = \XF::repository('XF:SessionActivity');
			if (method_exists($activityRepo, 'isUserOnline'))
			{
				return $activityRepo->isUserOnline($userId);
			}

			$cutoff = \XF::$time - 900;
			return (bool) \XF::db()->fetchOne(
				'SELECT 1 FROM xf_session_activity WHERE user_id = ? AND view_date >= ? LIMIT 1',
				[$userId, $cutoff]
			);
		}
		catch (\Throwable $e)
		{
			\XF::logException($e, false, 'IosApi mobile presence online check: ');
			return false;
		}
	}

	public static function decorateMemberPayload(array $payload): array
	{
		$userId = (int) ($payload['user_id'] ?? $payload['userId'] ?? $payload['id'] ?? 0);
		if ($userId <= 0)
		{
			return $payload;
		}

		$online = self::isUserOnline($userId);
		$payload['is_online'] = $online;
		$payload['isOnline'] = $online;
		return $payload;
	}

	public static function decorateMembersResponse($value)
	{
		if (!is_array($value))
		{
			return $value;
		}

		if (isset($value['members']) && is_array($value['members']))
		{
			foreach ($value['members'] AS $key => $member)
			{
				if (is_array($member))
				{
					$value['members'][$key] = self::decorateMemberPayload($member);
				}
			}
			return $value;
		}

		if (isset($value['member']) && is_array($value['member']))
		{
			$value['member'] = self::decorateMemberPayload($value['member']);
			return $value;
		}

		if (isset($value['id']) || isset($value['user_id']) || isset($value['userId']))
		{
			return self::decorateMemberPayload($value);
		}

		return $value;
	}
}
