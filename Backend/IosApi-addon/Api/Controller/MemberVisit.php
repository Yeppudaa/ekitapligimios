<?php

namespace Ekitapligim\IosApi\Api\Controller;

use Ekitapligim\IosApi\Service\ProfileVisit;
use XF\Mvc\ParameterBag;

class MemberVisit extends \Ekitapligim\MobileApi\Api\Controller\AbstractMobileController
{
	public function actionPost(ParameterBag $params)
	{
		$this->assertMobileWriteScope();
		$visitor = $this->assertRegisteredApiUser();
		$targetId = (int) $params->user_id;
		if ($targetId <= 0)
		{
			return $this->apiError('Member not found.', 'member_not_found', null, 404);
		}

		if ($targetId === (int) $visitor->user_id)
		{
			return $this->apiResult(['success' => true, 'recorded' => false]);
		}

		$target = $this->em()->find('XF:User', $targetId);
		if (!$target)
		{
			return $this->apiError('Member not found.', 'member_not_found', null, 404);
		}

		try
		{
			$recorded = ProfileVisit::record($visitor, $target);
		}
		catch (\Throwable $e)
		{
			\XF::logException($e, false, 'IosApi member visit: ');
			$recorded = false;
		}

		return $this->apiResult(['success' => true, 'recorded' => $recorded]);
	}
}
