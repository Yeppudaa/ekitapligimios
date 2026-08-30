<?php

namespace Ekitapligim\IosApi\Service;

use XF\Mvc\Entity\Entity;

final class UgcModeration
{
	public const REASONS = ['spam', 'harassment', 'hate', 'sexual', 'violence', 'privacy', 'copyright', 'other'];
	public const TYPES = ['forum_post', 'book_comment', 'agenda_post', 'agenda_comment', 'chat_message', 'conversation_message'];

	public static function ensureTable(): void
	{
		$db = \XF::db();
		$db->query(
			'CREATE TABLE IF NOT EXISTS xf_ekitapligim_ios_ugc_event (
				event_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
				event_hash VARBINARY(64) NOT NULL,
				report_id INT UNSIGNED NOT NULL DEFAULT 0,
				reporter_user_id INT UNSIGNED NOT NULL,
				target_user_id INT UNSIGNED NOT NULL DEFAULT 0,
				content_type VARCHAR(32) NOT NULL,
				content_id INT UNSIGNED NOT NULL DEFAULT 0,
				reason_code VARCHAR(32) NOT NULL,
				created_at INT UNSIGNED NOT NULL,
				notified_at INT UNSIGNED NOT NULL DEFAULT 0,
				reminded_at INT UNSIGNED NOT NULL DEFAULT 0,
				escalated_at INT UNSIGNED NOT NULL DEFAULT 0,
				actioned_at INT UNSIGNED NOT NULL DEFAULT 0,
				closed_at INT UNSIGNED NOT NULL DEFAULT 0,
				PRIMARY KEY (event_id),
				UNIQUE KEY event_hash (event_hash),
				KEY report_created (report_id, created_at)
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
		);

		// Keep an interrupted/older additive upgrade recoverable. The normal
		// install path creates these columns above; this only adds missing columns.
		$schema = $db->getSchemaManager();
		if ($schema->tableExists('xf_ekitapligim_ios_ugc_event'))
		{
			foreach (['actioned_at', 'closed_at'] AS $column)
			{
				if (!$schema->columnExists('xf_ekitapligim_ios_ugc_event', $column))
				{
					$schema->alterTable('xf_ekitapligim_ios_ugc_event', function(\XF\Db\Schema\Alter $table) use ($column)
					{
						$table->addColumn($column, 'int')->unsigned()->setDefault(0);
					});
				}
			}
		}
	}

	public static function createReport(string $type, int $contentId, string $reason, string $details): array
	{
		if (!in_array($type, self::TYPES, true) || $contentId <= 0)
		{
			throw new \InvalidArgumentException('Invalid report content.');
		}
		if (!in_array($reason, self::REASONS, true))
		{
			throw new \InvalidArgumentException('Invalid report reason.');
		}
		if ($reason === 'other' && mb_strlen(trim($details)) < 8)
		{
			throw new \LengthException('Report details are required.');
		}

		[$xfType, $entity] = self::resolveContent($type, $contentId);
		self::assertReportable($type, $entity);
		$creator = \XF::service('XF:Report\Creator', $xfType, $entity);
		$message = '[' . $reason . ']';
		if (trim($details) !== '')
		{
			$message .= ' ' . trim($details);
		}
		$creator->setMessage($message);
		if (!$creator->validate($errors))
		{
			throw new \RuntimeException(implode(' ', array_map('strval', $errors)));
		}
		$report = $creator->save();
		$creator->sendNotifications();
		$reportId = isset($report->report_id) ? (int) $report->report_id : 0;
		$targetUserId = self::entityUserId($entity);
		$eventId = self::recordEvent($reportId, $targetUserId, $type, $contentId, $reason);
		return ['report_id' => $reportId, 'target_user_id' => $targetUserId, 'event_id' => $eventId];
	}

	public static function targetUserId(string $type, int $contentId): int
	{
		if (!in_array($type, self::TYPES, true) || $contentId <= 0)
		{
			throw new \InvalidArgumentException('Invalid report content.');
		}
		[, $entity] = self::resolveContent($type, $contentId);
		return self::entityUserId($entity);
	}

	public static function recordBlock(int $targetUserId, string $type = 'user_block', int $contentId = 0, string $reason = 'harassment'): int
	{
		return self::recordEvent(0, $targetUserId, $type, $contentId, $reason);
	}

	protected static function recordEvent(int $reportId, int $targetUserId, string $type, int $contentId, string $reason): int
	{
		self::ensureTable();
		$reporterId = (int) \XF::visitor()->user_id;
		$hash = hash('sha256', implode(':', [$reporterId, $targetUserId, $type, $contentId, $reason]));
		\XF::db()->query(
			'INSERT IGNORE INTO xf_ekitapligim_ios_ugc_event
			 (event_hash, report_id, reporter_user_id, target_user_id, content_type, content_id, reason_code, created_at)
			 VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
			[$hash, $reportId, $reporterId, $targetUserId, $type, $contentId, $reason, \XF::$time]
		);
		$eventId = (int) \XF::db()->fetchOne('SELECT event_id FROM xf_ekitapligim_ios_ugc_event WHERE event_hash = ?', [$hash]);
		if ($eventId > 0)
		{
			\XF::app()->jobManager()->enqueueUnique(
				'ekIosUgcMail' . $eventId,
				'Ekitapligim\IosApi:UgcModerationMail',
				['event_id' => $eventId],
				false
			);
		}
		return $eventId;
	}

	protected static function resolveContent(string $type, int $contentId): array
	{
		$map = [
			'forum_post' => ['post', 'XF:Post', ['Thread']],
			'book_comment' => ['post', 'XF:Post', ['Thread']],
			'agenda_post' => ['ek_social_post', 'Ekitapligim\Social:Post', ['User']],
			'agenda_comment' => ['ek_social_comment', 'Ekitapligim\Social:Comment', ['Post', 'User']],
			'chat_message' => ['siropu_chat_room_message', 'Siropu\Chat:Message', ['User', 'Room']],
			'conversation_message' => ['conversation_message', 'XF:ConversationMessage', ['Conversation', 'User']],
		];
		[$xfType, $shortName, $with] = $map[$type];
		$entity = \XF::em()->find($shortName, $contentId, $with);
		if (!$entity instanceof Entity)
		{
			throw new \OutOfBoundsException('Report content not found.');
		}
		return [$xfType, $entity];
	}

	protected static function assertReportable(string $type, Entity $entity): void
	{
		$visitorId = (int) \XF::visitor()->user_id;
		if (!$visitorId || self::entityUserId($entity) === $visitorId)
		{
			throw new \DomainException('Content cannot be reported.');
		}
		$error = null;
		if ($type === 'chat_message')
		{
			$allowed = $entity->canReport();
		}
		else if (method_exists($entity, 'canReport'))
		{
			$allowed = $entity->canReport($error);
		}
		else
		{
			$allowed = method_exists($entity, 'canView') ? $entity->canView($error) : true;
		}
		if (!$allowed)
		{
			throw new \DomainException((string) ($error ?: 'Content cannot be reported.'));
		}
	}

	protected static function entityUserId(Entity $entity): int
	{
		foreach (['user_id', 'message_user_id'] AS $key)
		{
			try
			{
				$value = (int) $entity->get($key);
				if ($value > 0) return $value;
			}
			catch (\Throwable $e) {}
		}
		return 0;
	}
}
