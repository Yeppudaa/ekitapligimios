<?php

namespace Ekitapligim\IosApi\Service;

final class NotificationCounts
{
	public static function forUser(int $userId): array
	{
		if ($userId <= 0)
		{
			return [
				'unread' => 0,
				'unviewed' => 0,
				'conversations_unread' => 0,
				'conversationsUnread' => 0,
			];
		}

		$row = \XF::db()->fetchRow(
			'SELECT alerts_unread, alerts_unviewed, conversations_unread FROM xf_user WHERE user_id = ?',
			[$userId]
		) ?: [];

		$conversationsUnread = max(0, (int) ($row['conversations_unread'] ?? 0));
		return [
			'unread' => max(0, (int) ($row['alerts_unread'] ?? 0)),
			'unviewed' => max(0, (int) ($row['alerts_unviewed'] ?? 0)),
			'conversations_unread' => $conversationsUnread,
			'conversationsUnread' => $conversationsUnread,
		];
	}
}
