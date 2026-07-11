<?php

namespace Ekitapligim\MobileApi\Api\Controller;

class BlockedMembers extends AbstractMobileController
{
	public function actionGet()
	{
		$this->assertMobileScope();
		$visitor = $this->assertRegisteredApiUser();

		$rows = \XF::db()->fetchAll(
			'SELECT ignored.ignored_user_id, user.username, user.avatar_date
			 FROM xf_user_ignored AS ignored
			 INNER JOIN xf_user AS user ON (user.user_id = ignored.ignored_user_id)
			 WHERE ignored.user_id = ?
			 ORDER BY user.username',
			[$visitor->user_id]
		);

		$members = [];
		foreach ($rows AS $row)
		{
			$members[] = [
				'id' => (string) $row['ignored_user_id'],
				'user_id' => (int) $row['ignored_user_id'],
				'username' => (string) $row['username'],
				'avatar_url' => '',
				'avatarUrl' => '',
				'blocked_at' => null,
				'blockedAt' => null,
			];
		}

		return $this->apiResult(['members' => $members]);
	}
}
