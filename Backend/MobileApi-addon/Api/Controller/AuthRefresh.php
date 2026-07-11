<?php

namespace Ekitapligim\MobileApi\Api\Controller;

use Ekitapligim\MobileApi\Service\MobileSession;

class AuthRefresh extends AbstractMobileController
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
