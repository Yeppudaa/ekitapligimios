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
		foreach (['xf_ekitapligim_mobile_appstore_entitlement', 'xf_ekitapligim_ios_appstore_state', 'xf_ekitapligim_ios_appstore_account'] AS $table)
		{
			if (!\XF::db()->getSchemaManager()->tableExists($table)) { $errors[] = 'App Store storage is missing: ' . $table; }
		}
		$premiumGroup = \Ekitapligim\IosApi\Service\IosMembershipSynchronizer::premiumGroupId();
		if ($premiumGroup <= 0 || !\XF::em()->find('XF:UserGroup', $premiumGroup))
		{
			$errors[] = 'The shared Premium user group must be configured for purchase delivery.';
		}
		if (!\XF::db()->fetchOne("SELECT 1 FROM xf_cron_entry WHERE entry_id = 'ekIosAppStoreReconcile' AND active = 1"))
		{
			$errors[] = 'App Store membership reconciliation cron is missing or inactive.';
		}

		if ($errors)
		{
			foreach ($errors AS $error) $output->writeln('<error>' . $error . '</error>');
			return 1;
		}
		$output->writeln('<info>IosApi moderation and purchase storage/delivery controls are configured. Native and Apple Sandbox validation still required.</info>');
		return 0;
	}
}
