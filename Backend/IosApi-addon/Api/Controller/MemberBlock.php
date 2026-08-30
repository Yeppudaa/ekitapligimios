<?php

namespace Ekitapligim\IosApi\Api\Controller;

use Ekitapligim\IosApi\Service\UgcModeration;
use XF\Mvc\ParameterBag;

class MemberBlock extends \Ekitapligim\MobileApi\Api\Controller\AbstractMobileController
{
	public function actionBlock(ParameterBag $params)
	{
		$this->assertMobileWriteScope();
		$visitor = $this->assertRegisteredApiUser();
		$target = $this->assertViewableUser((int) $params->user_id);

		if ($target->user_id === $visitor->user_id)
		{
			return $this->apiError('You cannot block yourself.', 'invalid_target');
		}
		$contentType = strtolower(trim((string) $this->filter('source_type', 'str')));
		$contentId = (int) $this->filter('source_id', 'uint');
		$reason = strtolower(trim((string) $this->filter('reason_code', 'str'))) ?: 'harassment';
		$details = trim((string) $this->filter('details', 'str'));
		$reportCreated = false;
		try
		{
			if ($contentType !== '' && $contentId > 0)
			{
				if (UgcModeration::targetUserId($contentType, $contentId) !== (int) $target->user_id)
				{
					return $this->apiError('Engelleme hedefi içerik sahibiyle eşleşmiyor.', 'invalid_block_context', null, 422);
				}
				$report = UgcModeration::createReport($contentType, $contentId, $reason, $details);
				$reportCreated = true;
			}
			else
			{
				UgcModeration::recordBlock((int) $target->user_id, 'user_block', 0, $reason);
			}
		}
		catch (\Throwable $e)
		{
			\XF::logException($e, false, 'IosApi block moderation event failed: ');
			return $this->apiError('Engelleme bildirimi oluşturulamadı.', 'block_report_failed', null, 422);
		}

		\XF::db()->query(
			'INSERT IGNORE INTO xf_user_ignored (user_id, ignored_user_id) VALUES (?, ?)',
			[$visitor->user_id, $target->user_id]
		);

		return $this->apiResult([
			'success' => true,
			'blocked_user_id' => (int) $target->user_id,
			'blockedUserId' => (int) $target->user_id,
			'report_created' => $reportCreated,
			'reportCreated' => $reportCreated,
		]);
	}

	public function actionUnblock(ParameterBag $params)
	{
		$this->assertMobileWriteScope();
		$visitor = $this->assertRegisteredApiUser();
		$target = $this->assertViewableUser((int) $params->user_id);

		\XF::db()->delete('xf_user_ignored', 'user_id = ? AND ignored_user_id = ?', [$visitor->user_id, $target->user_id]);

		return $this->apiResult(['success' => true]);
	}

	protected function assertViewableUser(int $userId)
	{
		$user = $this->em()->find('XF:User', $userId);
		if (!$user)
		{
			throw $this->exception($this->notFound());
		}
		return $user;
	}
}

