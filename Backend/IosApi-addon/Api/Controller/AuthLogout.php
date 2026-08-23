<?php

namespace Ekitapligim\IosApi\Api\Controller;

use Ekitapligim\IosApi\Service\MobileSession;

class AuthLogout extends \Ekitapligim\MobileApi\Api\Controller\AbstractMobileController
{
	public function actionPost()
	{
		$this->assertMobileWriteScope();
		$this->assertRegisteredApiUser();
		MobileSession::revokeAccessToken(MobileSession::bearerToken($this->request->getAuthorizationHeader()));

		return $this->apiResult(['success' => true, 'logged_out' => true]);
	}
}

