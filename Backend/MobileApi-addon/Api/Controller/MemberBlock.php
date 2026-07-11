<?php

namespace Ekitapligim\MobileApi\Api\Controller;

use XF\Mvc\ParameterBag;

class MemberBlock extends AbstractMobileController
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

		\XF::db()->query(
			'INSERT IGNORE INTO xf_user_ignored (user_id, ignored_user_id) VALUES (?, ?)',
			[$visitor->user_id, $target->user_id]
		);

		return $this->apiResult(['success' => true]);
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
