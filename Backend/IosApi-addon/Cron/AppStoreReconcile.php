<?php

namespace Ekitapligim\IosApi\Cron;

use Ekitapligim\IosApi\Service\IosMembershipSynchronizer;

class AppStoreReconcile
{
	public static function run(): void
	{
		IosMembershipSynchronizer::syncAll();
	}
}
