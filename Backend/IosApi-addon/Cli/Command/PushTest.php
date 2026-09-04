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
			->addArgument('user-id', InputArgument::REQUIRED, 'XenForo user ID');
	}

	protected function execute(InputInterface $input, OutputInterface $output): int
	{
		$userId = (int) $input->getArgument('user-id');
		if ($userId <= 0 || !\XF::em()->find('XF:User', $userId))
		{
			$output->writeln('<error>User not found.</error>');
			return 1;
		}

		$payload = ApnsPush::buildPayload(
			'Ekitaplığım test bildirimi',
			'APNs bağlantısı başarıyla sınanıyor.',
			0,
			['route' => 'notifications', 'type' => 'diagnostic']
		);
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
