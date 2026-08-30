<?php

namespace Ekitapligim\IosApi\Service;

final class IgnoredUsers
{
	public static function ids(int $userId): array
	{
		if ($userId <= 0)
		{
			return [];
		}
		$ids = array_map('intval', \XF::db()->fetchAllColumn(
			'SELECT ignored_user_id FROM xf_user_ignored WHERE user_id = ?',
			[$userId]
		));
		return array_fill_keys(array_filter($ids), true);
	}

	public static function filterItems(array $items, array $blocked): array
	{
		if (!$blocked)
		{
			return array_values($items);
		}
		return array_values(array_filter($items, static function ($item) use ($blocked)
		{
			if (!is_array($item))
			{
				return true;
			}
			$userId = (int) ($item['user_id'] ?? $item['userId'] ?? $item['actor']['id'] ?? 0);
			return !$userId || !isset($blocked[$userId]);
		}));
	}

	public static function isEitherDirectionBlocked(int $firstUserId, int $secondUserId): bool
	{
		if ($firstUserId <= 0 || $secondUserId <= 0)
		{
			return false;
		}
		return (bool) \XF::db()->fetchOne(
			'SELECT 1 FROM xf_user_ignored WHERE (user_id = ? AND ignored_user_id = ?) OR (user_id = ? AND ignored_user_id = ?) LIMIT 1',
			[$firstUserId, $secondUserId, $secondUserId, $firstUserId]
		);
	}
}
