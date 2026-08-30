<?php

namespace Ekitapligim\IosApi\Cli\Command;

use Ekitapligim\IosApi\Service\UgcPolicy;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;
use XF\Cli\Command\AbstractCommand;

class ReleaseAudit extends AbstractCommand
{
	protected function configure(): void
	{
		$this->setName('ekitapligim-ios:release-audit')
			->setDescription('Fail closed when Guideline 1.2 production moderation controls are incomplete');
	}

	protected function execute(InputInterface $input, OutputInterface $output): int
	{
		$errors = [];
		$emails = array_values(array_filter(array_map('trim', preg_split('/[,;\s]+/', (string) (\XF::options()->ekIosUgcModeratorEmails ?? '')) ?: [])));
		if (!$emails || array_filter($emails, static fn($email) => !filter_var($email, FILTER_VALIDATE_EMAIL)))
		{
			$errors[] = 'ekIosUgcModeratorEmails must contain at least one valid address.';
		}
		if (!UgcPolicy::isConfigured())
		{
			$errors[] = 'ekIosUgcBlockedTerms must contain at least one managed term.';
		}
		if (!\XF::db()->fetchOne("SHOW TABLES LIKE 'xf_ekitapligim_ios_ugc_event'"))
		{
			$errors[] = 'UGC event table is missing.';
		}
		if (!\XF::db()->fetchOne("SELECT 1 FROM xf_cron_entry WHERE entry_id = 'ekIosUgcSla' AND active = 1"))
		{
			$errors[] = '20/24-hour UGC SLA cron is missing or inactive.';
		}
		if (!\XF::db()->fetchOne("SELECT 1 FROM xf_content_type_field WHERE content_type = 'ek_social_comment' AND field_name = 'report_handler_class' AND field_value <> ''"))
		{
			$errors[] = 'Book Agenda comment report handler is missing.';
		}

		if ($errors)
		{
			foreach ($errors AS $error) $output->writeln('<error>' . $error . '</error>');
			return 1;
		}
		$output->writeln('<info>IosApi Guideline 1.2 release controls are configured.</info>');
		return 0;
	}
}
