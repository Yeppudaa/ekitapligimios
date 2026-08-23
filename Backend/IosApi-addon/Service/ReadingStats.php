<?php

namespace Ekitapligim\IosApi\Service;

class ReadingStats
{
	public static function ensureTables(): void
	{
		$db = \XF::db();
		$db->query("CREATE TABLE IF NOT EXISTS xf_ekitapligim_mobile_reading_stats (
			user_id INT UNSIGNED NOT NULL,
			daily_goal_minutes SMALLINT UNSIGNED NOT NULL DEFAULT 30,
			total_seconds BIGINT UNSIGNED NOT NULL DEFAULT 0,
			total_pages INT UNSIGNED NOT NULL DEFAULT 0,
			streak_count INT UNSIGNED NOT NULL DEFAULT 0,
			last_read_date DATE DEFAULT NULL,
			updated_at INT UNSIGNED NOT NULL DEFAULT 0,
			PRIMARY KEY (user_id)
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
		$db->query("CREATE TABLE IF NOT EXISTS xf_ekitapligim_mobile_reading_day (
			user_id INT UNSIGNED NOT NULL,
			reading_date DATE NOT NULL,
			seconds INT UNSIGNED NOT NULL DEFAULT 0,
			pages INT UNSIGNED NOT NULL DEFAULT 0,
			goal_completed TINYINT UNSIGNED NOT NULL DEFAULT 0,
			PRIMARY KEY (user_id, reading_date),
			KEY reading_date (reading_date)
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
		$db->query("CREATE TABLE IF NOT EXISTS xf_ekitapligim_mobile_reading_session (
			session_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
			user_id INT UNSIGNED NOT NULL,
			client_session_id VARBINARY(100) NOT NULL,
			book_id INT UNSIGNED NOT NULL DEFAULT 0,
			reading_date DATE NOT NULL,
			seconds INT UNSIGNED NOT NULL DEFAULT 0,
			pages INT UNSIGNED NOT NULL DEFAULT 0,
			created_at INT UNSIGNED NOT NULL DEFAULT 0,
			PRIMARY KEY (session_id),
			UNIQUE KEY user_session (user_id, client_session_id),
			KEY user_date (user_id, reading_date)
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
		$db->query("CREATE TABLE IF NOT EXISTS xf_ekitapligim_mobile_badge (
			user_id INT UNSIGNED NOT NULL,
			badge_key VARBINARY(50) NOT NULL,
			award_date INT UNSIGNED NOT NULL DEFAULT 0,
			PRIMARY KEY (user_id, badge_key)
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
	}

	public function get(int $userId): array
	{
		self::ensureTables();
		$this->ensureUser($userId);
		$db = \XF::db();
		$stats = $db->fetchRow('SELECT * FROM xf_ekitapligim_mobile_reading_stats WHERE user_id = ?', $userId) ?: [];
		$today = date('Y-m-d', \XF::$time);
		$day = $db->fetchRow(
			'SELECT seconds, pages, goal_completed FROM xf_ekitapligim_mobile_reading_day WHERE user_id = ? AND reading_date = ?',
			[$userId, $today]
		) ?: ['seconds' => 0, 'pages' => 0, 'goal_completed' => 0];
		$goal = max(10, (int) ($stats['daily_goal_minutes'] ?? 30));
		$todaySeconds = (int) $day['seconds'];

		return [
			'daily_goal_minutes' => $goal,
			'dailyGoalMinutes' => $goal,
			'total_seconds' => (int) ($stats['total_seconds'] ?? 0),
			'totalSeconds' => (int) ($stats['total_seconds'] ?? 0),
			'total_pages' => (int) ($stats['total_pages'] ?? 0),
			'totalPages' => (int) ($stats['total_pages'] ?? 0),
			'streak_count' => (int) ($stats['streak_count'] ?? 0),
			'streakCount' => (int) ($stats['streak_count'] ?? 0),
			'today_seconds' => $todaySeconds,
			'todaySeconds' => $todaySeconds,
			'today_pages' => (int) $day['pages'],
			'todayPages' => (int) $day['pages'],
			'goal_completed' => (bool) $day['goal_completed'],
			'goalCompleted' => (bool) $day['goal_completed'],
			'goal_progress_percent' => min(100, (int) floor(($todaySeconds / ($goal * 60)) * 100)),
			'badges' => $this->badges($userId),
		];
	}

	public function setGoal(int $userId, int $minutes): array
	{
		self::ensureTables();
		$this->ensureUser($userId);
		$minutes = max(10, min(240, $minutes));
		\XF::db()->update('xf_ekitapligim_mobile_reading_stats', [
			'daily_goal_minutes' => $minutes,
			'updated_at' => \XF::$time,
		], 'user_id = ?', $userId);
		$this->refreshGoalAndBadge($userId, date('Y-m-d', \XF::$time));
		return $this->get($userId);
	}

	public function recordSession(int $userId, string $clientId, int $bookId, string $date, int $seconds, int $pages): array
	{
		self::ensureTables();
		$this->ensureUser($userId);
		$clientId = substr(trim($clientId), 0, 100);
		$seconds = max(1, min(86400, $seconds));
		$pages = max(0, min(10000, $pages));
		$dateObject = \DateTimeImmutable::createFromFormat('!Y-m-d', $date);
		$dateIsExact = $dateObject && $dateObject->format('Y-m-d') === $date;
		if (!$clientId || !$dateIsExact || $date > date('Y-m-d', \XF::$time))
		{
			throw new \InvalidArgumentException('Invalid reading session.');
		}
		$db = \XF::db();
		$db->beginTransaction();
		try
		{
			$inserted = $db->insert('xf_ekitapligim_mobile_reading_session', [
				'user_id' => $userId,
				'client_session_id' => $clientId,
				'book_id' => max(0, $bookId),
				'reading_date' => $date,
				'seconds' => $seconds,
				'pages' => $pages,
				'created_at' => \XF::$time,
			], false, false, 'IGNORE');
			if ($inserted)
			{
				$db->query(
					'INSERT INTO xf_ekitapligim_mobile_reading_day (user_id, reading_date, seconds, pages)
					 VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE seconds = seconds + VALUES(seconds), pages = pages + VALUES(pages)',
					[$userId, $date, $seconds, $pages]
				);
				$db->query(
					'UPDATE xf_ekitapligim_mobile_reading_stats SET total_seconds = total_seconds + ?, total_pages = total_pages + ?, last_read_date = ?, updated_at = ? WHERE user_id = ?',
					[$seconds, $pages, $date, \XF::$time, $userId]
				);
				$this->recalculateStreak($userId);
				$this->refreshGoalAndBadge($userId, $date);
			}
			$db->commit();
		}
		catch (\Throwable $e)
		{
			$db->rollback();
			throw $e;
		}
		return $this->get($userId);
	}

	public function badges(int $userId): array
	{
		self::ensureTables();
		$rows = \XF::db()->fetchAll('SELECT badge_key, award_date FROM xf_ekitapligim_mobile_badge WHERE user_id = ? ORDER BY award_date DESC', $userId);
		return array_map(static function (array $row): array
		{
			return [
				'id' => 'reading_' . (string) $row['badge_key'],
				'title' => 'Günlük Hedef Rozeti',
				'description' => 'Günlük okuma hedefini tamamladın.',
				'points' => 10,
				'award_date' => (int) $row['award_date'],
			];
		}, $rows);
	}

	protected function ensureUser(int $userId): void
	{
		\XF::db()->insert('xf_ekitapligim_mobile_reading_stats', [
			'user_id' => $userId,
			'daily_goal_minutes' => 30,
			'updated_at' => \XF::$time,
		], false, false, 'IGNORE');
	}

	protected function refreshGoalAndBadge(int $userId, string $date): void
	{
		$db = \XF::db();
		$goal = (int) $db->fetchOne('SELECT daily_goal_minutes FROM xf_ekitapligim_mobile_reading_stats WHERE user_id = ?', $userId);
		$seconds = (int) $db->fetchOne('SELECT seconds FROM xf_ekitapligim_mobile_reading_day WHERE user_id = ? AND reading_date = ?', [$userId, $date]);
		$completed = $seconds >= max(10, $goal) * 60;
		$db->update(
			'xf_ekitapligim_mobile_reading_day',
			['goal_completed' => $completed ? 1 : 0],
			'user_id = ? AND reading_date = ?',
			[$userId, $date]
		);
		if ($completed)
		{
			$db->insert('xf_ekitapligim_mobile_badge', [
				'user_id' => $userId,
				'badge_key' => 'daily_goal',
				'award_date' => \XF::$time,
			], false, false, 'IGNORE');
		}
	}

	protected function recalculateStreak(int $userId): void
	{
		$dates = \XF::db()->fetchAllColumn('SELECT reading_date FROM xf_ekitapligim_mobile_reading_day WHERE user_id = ? AND seconds > 0 ORDER BY reading_date DESC', $userId);
		$expected = new \DateTimeImmutable(date('Y-m-d', \XF::$time));
		$streak = 0;
		if ($dates)
		{
			$latest = new \DateTimeImmutable((string) reset($dates));
			if ($latest == $expected->modify('-1 day'))
			{
				$expected = $latest;
			}
		}
		foreach ($dates AS $date)
		{
			$current = new \DateTimeImmutable((string) $date);
			if ($current > $expected) continue;
			if ($current < $expected) break;
			$streak++;
			$expected = $expected->modify('-1 day');
		}
		\XF::db()->update('xf_ekitapligim_mobile_reading_stats', ['streak_count' => $streak], 'user_id = ?', $userId);
	}
}
