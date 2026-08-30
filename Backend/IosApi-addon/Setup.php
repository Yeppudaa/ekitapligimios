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
}
