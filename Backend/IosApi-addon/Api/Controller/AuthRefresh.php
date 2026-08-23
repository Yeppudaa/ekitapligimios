<?php

namespace Ekitapligim\IosApi\Api\Controller;

use Ekitapligim\IosApi\Service\MobileSession;

class AuthRefresh extends \Ekitapligim\MobileApi\Api\Controller\AbstractMobileController
{
	public function actionPost()
	{
		$this->assertMobileWriteScope();
		$refreshToken = trim($this->filter('refresh_token', 'str'));
		$rotated = MobileSession::rotate($refreshToken, $this->request->getIp(), (string) $this->request->getServer('HTTP_USER_AGENT', ''));
		if (!$rotated)
		{
			return $this->apiError('Session refresh token is invalid or expired.', 'refresh_token_invalid', null, 401);
		}

		return $this->apiResult($this->buildMobileAuthPayload($rotated['user'], $rotated['tokens']));
	}
}

