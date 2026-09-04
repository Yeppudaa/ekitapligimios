<?php

namespace Ekitapligim\IosApi\Cli\Command;

use Ekitapligim\IosApi\Service\ApnsPush;
use Symfony\Component\Console\Input\InputArgument;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;
use XF\Cli\Command\AbstractCommand;

class PushTest extends AbstractCommand
{
	protected function configure(): void
	{
		$this->setName('ekitapligim-ios:push-test')
			->setDescription('Send a privacy-safe APNs diagnostic notification to an iOS user')
			->addArgument('user-id', InputArgument::REQUIRED, 'XenForo user ID')
			->addArgument('scenario', InputArgument::OPTIONAL, 'generic-alert, forum, profile, conversation, chat, book-agenda, reading, or system', 'generic-alert');
	}

	protected function execute(InputInterface $input, OutputInterface $output): int
	{
		$userId = (int) $input->getArgument('user-id');
		if ($userId <= 0 || !\XF::em()->find('XF:User', $userId))
		{
			$output->writeln('<error>User not found.</error>');
			return 1;
		}

		$scenario = strtolower(trim((string) $input->getArgument('scenario')));
		$scenarios = [
			'generic-alert' => ['Bildirim testi', 'notifications', 'diagnostic'],
			'forum' => ['Forum bildirimi testi', 'forum', 'post'],
			'profile' => ['Profil bildirimi testi', 'profile', 'user'],
			'conversation' => ['Özel mesaj bildirimi testi', 'messages', 'conversation_message'],
			'chat' => ['Sohbet bildirimi testi', 'chat', 'siropu_chat_room_message'],
			'book-agenda' => ['Kitap Gündemi bildirimi testi', 'book-agenda', 'ek_social_post'],
			'reading' => ['Okuma bildirimi testi', 'library/0', 'ek_reading_invitation'],
			'system' => ['Sistem bildirimi testi', 'notifications', 'system'],
		];
		if (!isset($scenarios[$scenario]))
		{
			$output->writeln('<error>Unknown scenario.</error>');
			return 4;
		}

		[$title, $route, $type] = $scenarios[$scenario];
		$payload = ApnsPush::buildPayload($title, 'APNs bağlantısı başarıyla sınanıyor.', 0, [
			'route' => $route,
			'type' => $type,
			'action' => 'diagnostic',
		]);
		$summary = ApnsPush::sendToUser($userId, $payload);

		$output->writeln(sprintf(
			'Attempted=%d Sent=%d Failed=%d Removed=%d',
			(int) $summary['attempted'],
			(int) $summary['sent'],
			(int) $summary['failed'],
			(int) $summary['removed']
		));

		if ((int) $summary['attempted'] === 0)
		{
			$output->writeln('<error>No registered iOS device exists for this user.</error>');
			return 2;
		}

		return (int) $summary['failed'] === 0 ? 0 : 3;
	}
}
