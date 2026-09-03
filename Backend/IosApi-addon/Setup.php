<?php

namespace Ekitapligim\IosApi;

use Ekitapligim\IosApi\Service\ReadingStats;
use Ekitapligim\IosApi\Service\TermsAcceptance;
use Ekitapligim\IosApi\Service\UgcModeration;
use XF\AddOn\AbstractSetup;
use XF\AddOn\StepRunnerInstallTrait;
use XF\AddOn\StepRunnerUninstallTrait;
use XF\AddOn\StepRunnerUpgradeTrait;

class Setup extends AbstractSetup
{
	use StepRunnerInstallTrait;
	use StepRunnerUpgradeTrait;
	use StepRunnerUninstallTrait;

	public function installStep1(): void
	{
		ReadingStats::ensureTables();
		TermsAcceptance::ensureTable();
		UgcModeration::ensureTable();
	}

	public function upgrade1000002Step1(): void
	{
		ReadingStats::ensureTables();
	}

	public function upgrade1000003Step1(): void
	{
		ReadingStats::ensureTables();
	}

	public function upgrade1000010Step1(): void
	{
		ReadingStats::ensureTables();
		TermsAcceptance::ensureTable();
		UgcModeration::ensureTable();
	}

	public function upgrade1000012Step1(): void
	{
		// Servers already on 1.0.11 need a monotonic, additive upgrade.
		ReadingStats::ensureTables();
		TermsAcceptance::ensureTable();
		UgcModeration::ensureTable();
	}

	public function upgrade1000013Step1(): void
	{
		UgcModeration::ensureTable();
	}

	public function upgrade1000014Step1(): void
	{
		// Rebuilds ios-api forum post edit/delete public routes (POST /posts/{id}/edit|delete).
	}

	public function upgrade1000015Step1(): void
	{
		// Rebuilds ios-api notification routes onto IosApi-owned XenForo alert controllers.
	}

	public function upgrade1000016Step1(): void
	{
		// Rebuilds ios-api presence, member-visit, and IosApi-owned Members routes.
	}

	public function upgrade1000017Step1(): void
	{
		// Fixes XenForo session activity parameter order in MobilePresence.
	}

	public function upgrade1000018Step1(): void
	{
		// Owns Google authentication so expected invalid-token responses are not logged as server errors.
	}

	public function upgrade1000019Step1(): void
	{
		// Accepts the iOS Google client ID as a valid ID-token audience in addition to web clients.
	}

	public function upgrade1000020Step1(): void
	{
		self::ensureDeviceTokensTable();
	}

	public static function ensureDeviceTokensTable(): void
	{
		$db = \XF::db();
		$db->query("
			CREATE TABLE IF NOT EXISTS `xf_ios_device_tokens` (
				`token_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
				`user_id` INT UNSIGNED NOT NULL,
				`device_token` VARCHAR(255) NOT NULL,
				`platform` VARCHAR(20) NOT NULL DEFAULT 'ios',
				`created_at` INT UNSIGNED NOT NULL DEFAULT 0,
				PRIMARY KEY (`token_id`),
				UNIQUE KEY `uk_device_token` (`device_token`),
				KEY `idx_user_id` (`user_id`)
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
		");
	}
}
