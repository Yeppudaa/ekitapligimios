<?php

namespace Ekitapligim\IosApi\Service;

final class TermsAcceptance
{
	public const CURRENT_VERSION = '2026-08';

	public static function ensureTable(): void
	{
		\XF::db()->query(
			'CREATE TABLE IF NOT EXISTS xf_ekitapligim_mobile_terms_acceptance (
				user_id INT UNSIGNED NOT NULL,
				terms_version VARCHAR(32) NOT NULL,
				accept_date INT UNSIGNED NOT NULL,
				PRIMARY KEY (user_id)
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
		);
	}

	public static function isCurrent(?string $version): bool
	{
		return trim((string) $version) === self::CURRENT_VERSION;
	}

	public static function hasAccepted(int $userId): bool
	{
		if ($userId <= 0)
		{
			return false;
		}
		self::ensureTable();
		return (bool) \XF::db()->fetchOne(
			'SELECT 1 FROM xf_ekitapligim_mobile_terms_acceptance WHERE user_id = ? AND terms_version = ? LIMIT 1',
			[$userId, self::CURRENT_VERSION]
		);
	}

	public static function record(int $userId, string $version): bool
	{
		if ($userId <= 0 || !self::isCurrent($version))
		{
			return false;
		}
		self::ensureTable();
		\XF::db()->query(
			'INSERT INTO xf_ekitapligim_mobile_terms_acceptance (user_id, terms_version, accept_date)
			 VALUES (?, ?, ?)
			 ON DUPLICATE KEY UPDATE terms_version = VALUES(terms_version), accept_date = VALUES(accept_date)',
			[$userId, self::CURRENT_VERSION, \XF::$time]
		);
		return true;
	}

	public static function status(int $userId): array
	{
		self::ensureTable();
		$row = \XF::db()->fetchRow(
			'SELECT terms_version, accept_date FROM xf_ekitapligim_mobile_terms_acceptance WHERE user_id = ?',
			[$userId]
		);
		$accepted = $row ? (string) $row['terms_version'] : null;
		$date = $row ? (int) $row['accept_date'] : null;
		return [
			'required_version' => self::CURRENT_VERSION,
			'requiredVersion' => self::CURRENT_VERSION,
			'accepted_version' => $accepted,
			'acceptedVersion' => $accepted,
			'accepted_at' => $date,
			'acceptedAt' => $date,
			'requires_acceptance' => $accepted !== self::CURRENT_VERSION,
			'requiresAcceptance' => $accepted !== self::CURRENT_VERSION,
		];
	}
}
