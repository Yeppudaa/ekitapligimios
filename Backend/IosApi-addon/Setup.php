<?php

namespace Ekitapligim\IosApi;

use Ekitapligim\IosApi\Service\ReadingStats;
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
	}

	public function upgrade1000002Step1(): void
	{
		ReadingStats::ensureTables();
	}

	public function upgrade1000003Step1(): void
	{
		ReadingStats::ensureTables();
	}
}
