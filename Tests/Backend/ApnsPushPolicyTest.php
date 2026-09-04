<?php

require_once __DIR__ . '/../../Backend/IosApi-addon/Service/ApnsPush.php';

use Ekitapligim\IosApi\Service\ApnsPush;

$cases = [
	[410, 'Unregistered', true],
	[400, 'BadDeviceToken', true],
	[400, 'DeviceTokenNotForTopic', false],
	[403, 'InvalidProviderToken', false],
	[500, 'InternalServerError', false],
];

foreach ($cases as [$status, $reason, $expected])
{
	if (ApnsPush::shouldRemoveToken($status, $reason) !== $expected)
	{
		fwrite(STDERR, "Unexpected APNs token removal policy for HTTP {$status} {$reason}.\n");
		exit(1);
	}
}

fwrite(STDOUT, "APNs token removal policy tests passed.\n");
