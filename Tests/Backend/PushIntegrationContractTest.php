<?php

$root = dirname(__DIR__, 2);
$alertSource = file_get_contents($root . '/Backend/IosApi-addon/Listener/AlertCreated.php');
$conversationSource = file_get_contents($root . '/Backend/IosApi-addon/XF/Service/Conversation/Notifier.php');
$jobSource = file_get_contents($root . '/Backend/IosApi-addon/Job/SendConversationPush.php');
$routes = simplexml_load_file($root . '/Backend/IosApi-addon/_data/routes.xml');
$extensions = simplexml_load_file($root . '/Backend/IosApi-addon/_data/class_extensions.xml');

$assert = static function (bool $condition, string $message): void
{
	if (!$condition)
	{
		fwrite(STDERR, $message . "\n");
		exit(1);
	}
};

$assert(strpos($alertSource, "'alert_id' => (int) \$alert->alert_id") !== false, 'Alert pushes must carry alert_id.');
$assert(strpos($conversationSource, '_canUserReceiveNotification') !== false, 'Conversation pushes must honor XenForo recipient eligibility.');
$assert(strpos($jobSource, "'conversation_id' => \$conversationId") !== false, 'Conversation pushes must carry conversation_id.');
$assert(!preg_match('/message->message(?!_id)/', $jobSource), 'Conversation message bodies must not enter push payloads.');

$routeFound = false;
foreach ($routes->route AS $route)
{
	if ((string) $route['sub_name'] === 'conversation-read') { $routeFound = true; }
}
$assert($routeFound, 'Conversation read route is missing.');

$extensionFound = false;
foreach ($extensions->extension AS $extension)
{
	if ((string) $extension['from_class'] === 'XF\\Service\\Conversation\\Notifier') { $extensionFound = true; }
}
$assert($extensionFound, 'Conversation notifier extension is missing.');

fwrite(STDOUT, "Push integration contract tests passed.\n");
