<?php

namespace Ekitapligim\IosApi\Api\Controller;

use Ekitapligim\IosApi\Service\MobilePresence;
use XF\Api\Mvc\Reply\ApiResult;
use XF\Mvc\ParameterBag;
use XF\Mvc\Reply\AbstractReply;

class Members extends \Ekitapligim\MobileApi\Api\Controller\Members
{
	public function actionGet(ParameterBag $params)
	{
		$reply = parent::actionGet($params);
		return $this->decorateMemberReply($reply);
	}

	protected function decorateMemberReply(AbstractReply $reply): AbstractReply
	{
		if (!$reply instanceof ApiResult)
		{
			return $reply;
		}

		$result = $reply->getApiResult();
		if (is_array($result))
		{
			$reply->setApiResult(MobilePresence::decorateMembersResponse($result));
		}

		return $reply;
	}
}
