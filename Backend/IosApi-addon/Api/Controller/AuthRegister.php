<?php

namespace Ekitapligim\IosApi\Api\Controller;

use Ekitapligim\IosApi\Service\TermsAcceptance;

class AuthRegister extends \Ekitapligim\MobileApi\Api\Controller\AuthRegister
{
	public function actionPost()
	{
		$version = trim((string) $this->filter('accepted_terms_version', 'str'));
		if (!TermsAcceptance::isCurrent($version))
		{
			return $this->apiError('Güncel kullanım şartlarını kabul etmelisiniz.', 'terms_acceptance_required', [
				'required_version' => TermsAcceptance::CURRENT_VERSION,
				'requiredVersion' => TermsAcceptance::CURRENT_VERSION,
			], 403);
		}
		$reply = parent::actionPost();
		if (is_object($reply) && method_exists($reply, 'getApiResult'))
		{
			$result = $reply->getApiResult();
			$payload = is_object($result) && method_exists($result, 'getResult') ? $result->getResult() : [];
			$userId = (int) ($payload['user']['user_id'] ?? $payload['user']['userId'] ?? 0);
			if ($userId > 0) TermsAcceptance::record($userId, $version);
		}
		return $reply;
	}
}
