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
}
