<?php

namespace Ekitapligim\IosApi\Api\Controller;

use Ekitapligim\IosApi\Service\IgnoredUsers;
use Ekitapligim\IosApi\Service\TermsAcceptance;
use Ekitapligim\IosApi\Service\UgcPolicy;

trait UgcControllerTrait
{
	protected function validateUgcWrite(array $fields)
	{
		$visitor = $this->assertRegisteredApiUser();
		if (!TermsAcceptance::hasAccepted((int) $visitor->user_id))
		{
			return $this->apiError(
				'Topluluk kurallarını kabul etmeden içerik paylaşamazsınız.',
				'terms_acceptance_required',
				['required_version' => TermsAcceptance::CURRENT_VERSION, 'requiredVersion' => TermsAcceptance::CURRENT_VERSION],
				403
			);
		}
		if (UgcPolicy::violation($fields))
		{
			return $this->apiError(
				'Bu içerik topluluk güvenliği kurallarına aykırı olabilir.',
				'content_policy_violation',
				null,
				422
			);
		}
		return null;
	}

	protected function filterReplyCollections($reply, array $keys)
	{
		$visitorId = (int) \XF::visitor()->user_id;
		if (!$visitorId || !is_object($reply) || !method_exists($reply, 'getApiResult'))
		{
			return $reply;
		}
		$result = $reply->getApiResult();
		if (!is_object($result) || !method_exists($result, 'getResult') || !method_exists($result, 'setResult'))
		{
			return $reply;
		}
		$payload = $result->getResult();
		$blocked = IgnoredUsers::ids($visitorId);
		foreach ($keys AS $key)
		{
			if (isset($payload[$key]) && is_array($payload[$key]))
			{
				$payload[$key] = IgnoredUsers::filterItems($payload[$key], $blocked);
			}
		}
		if (isset($payload['post']['comments']) && is_array($payload['post']['comments']))
		{
			$payload['post']['comments'] = IgnoredUsers::filterItems($payload['post']['comments'], $blocked);
		}
		$result->setResult($payload);
		return $reply;
	}
}
