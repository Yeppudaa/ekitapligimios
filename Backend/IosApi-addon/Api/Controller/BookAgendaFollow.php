<?php

namespace Ekitapligim\IosApi\Api\Controller;

use XF\Mvc\ParameterBag;

class BookAgendaFollow extends \Ekitapligim\MobileApi\Api\Controller\AbstractMobileController
{
	public function actionPost(ParameterBag $params)
	{
		$this->assertMobileWriteScope();
		$visitor = $this->assertRegisteredApiUser();
		$targetId = (int) $params->user_id;
		if (!$targetId || $targetId === (int) $visitor->user_id)
		{
			return $this->apiError('You cannot follow this member.', 'invalid_follow_target', null, 422);
		}
		$target = $this->em()->find('XF:User', $targetId);
		if (!$target) return $this->apiError('Member not found.', 'member_not_found', null, 404);

		$follow = (bool) $this->filter('follow', 'bool');
		$existing = $this->finder('Ekitapligim\Social:Follow')
			->where('user_id', $visitor->user_id)
			->where('target_type', 'user')
			->where('target_id', $targetId)
			->fetchOne();
		if ($follow && !$existing)
		{
			$entity = $this->em()->create('Ekitapligim\Social:Follow');
			$entity->user_id = $visitor->user_id;
			$entity->target_type = 'user';
			$entity->target_id = $targetId;
			$entity->follow_date = \XF::$time;
			$entity->save();
		}
		elseif (!$follow && $existing)
		{
			$existing->delete();
		}

		return $this->apiResult(['success' => true, 'following' => $follow, 'active' => $follow]);
	}
}
