<?php

namespace Ekitapligim\MobileApi\Cli\Command;

use Ekitapligim\MobileApi\Service\AccountDeletionCompletion;
use Symfony\Component\Console\Input\InputArgument;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Input\InputOption;
use Symfony\Component\Console\Output\OutputInterface;
use XF\Cli\Command\AbstractCommand;
use XF\Cli\Command\JobRunnerTrait;

class CompleteAccountDeletion extends AbstractCommand
{
	use JobRunnerTrait;

	protected function configure(): void
	{
		$this->setName('ekitapligim-mobile:complete-account-deletion')
			->setDescription('Inspect or irreversibly complete one mobile account deletion request')
			->addArgument('request-id', InputArgument::REQUIRED, 'Deletion request ID')
			->addOption('execute', null, InputOption::VALUE_NONE, 'Perform irreversible deletion')
			->addOption('confirm', null, InputOption::VALUE_REQUIRED, 'Must equal DELETE-{request-id}');
	}

	protected function execute(InputInterface $input, OutputInterface $output): int
	{
		$requestId = (int) $input->getArgument('request-id');
		$request = AccountDeletionCompletion::inspect($requestId);
		if (!$request)
		{
			$output->writeln('<error>Deletion request not found.</error>');
			return 1;
		}

		$output->writeln(sprintf(
			'Request #%d | user_id=%d | state=%s | requested=%s UTC',
			$requestId,
			(int) $request['user_id'],
			(string) $request['request_state'],
			gmdate('Y-m-d H:i:s', (int) $request['requested_at'])
		));
		if (!$input->getOption('execute'))
		{
			$output->writeln('<comment>Inspection only. No data changed.</comment>');
			return 0;
		}
		if (!hash_equals('DELETE-' . $requestId, (string) $input->getOption('confirm')))
		{
			$output->writeln('<error>Confirmation mismatch. Use --confirm=DELETE-' . $requestId . '.</error>');
			return 2;
		}

		try
		{
			$result = AccountDeletionCompletion::complete($requestId);
			if (!empty($result['already_completed']))
			{
				$output->writeln('<info>Request was already completed.</info>');
				return 0;
			}
			$this->runJob('userRenameDelete' . (int) $result['user_id'], $output);
			$noticeSent = AccountDeletionCompletion::sendCompletionNotice(
				(string) $result['email'],
				$requestId
			);
			$output->writeln('<info>Deletion completed and request PII scrubbed.</info>');
			if (!$noticeSent)
			{
				$output->writeln('<comment>Completion email could not be sent; inspect XenForo error logs.</comment>');
			}
			return 0;
		}
		catch (\Throwable $e)
		{
			$output->writeln('<error>' . $e->getMessage() . '</error>');
			return 1;
		}
	}
}
