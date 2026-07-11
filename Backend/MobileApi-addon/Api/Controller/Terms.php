<?php

namespace Ekitapligim\MobileApi\Api\Controller;

class Terms extends AbstractMobileController
{
	public const CURRENT_VERSION = '2026-07';

	public function actionGet()
	{
		$this->assertMobileScope();
		$visitor = $this->assertRegisteredApiUser();
		$accepted = $this->getAcceptedVersion((int) $visitor->user_id);

		return $this->apiResult([
			'required_version' => self::CURRENT_VERSION,
			'requiredVersion' => self::CURRENT_VERSION,
			'accepted_version' => $accepted['version'],
			'acceptedVersion' => $accepted['version'],
			'accepted_at' => $accepted['date'],
			'acceptedAt' => $accepted['date'],
			'requires_acceptance' => $accepted['version'] !== self::CURRENT_VERSION,
			'requiresAcceptance' => $accepted['version'] !== self::CURRENT_VERSION,
		]);
	}

	public function actionAccept()
	{
		$this->assertMobileWriteScope();
		$visitor = $this->assertRegisteredApiUser();
		$version = trim($this->filter('version', 'str')) ?: self::CURRENT_VERSION;

		if ($version !== self::CURRENT_VERSION)
		{
			return $this->apiError('Terms version is not current.', 'terms_version_mismatch');
		}

		$this->ensureTable();
		\XF::db()->query(
			'INSERT INTO xf_ekitapligim_mobile_terms_acceptance
				(user_id, terms_version, accept_date)
			 VALUES (?, ?, ?)
			 ON DUPLICATE KEY UPDATE terms_version = VALUES(terms_version), accept_date = VALUES(accept_date)',
			[(int) $visitor->user_id, $version, \XF::$time]
		);

		return $this->apiResult(['success' => true]);
	}

	protected function getAcceptedVersion(int $userId): array
	{
		$this->ensureTable();
		$row = \XF::db()->fetchRow(
			'SELECT terms_version, accept_date
			 FROM xf_ekitapligim_mobile_terms_acceptance
			 WHERE user_id = ?',
			[$userId]
		);

		return [
			'version' => $row ? (string) $row['terms_version'] : null,
			'date' => $row ? (int) $row['accept_date'] : null,
		];
	}

	protected function ensureTable(): void
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
}
