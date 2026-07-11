<?php

namespace Ekitapligim\MobileApi\Api\Controller;

use Ekitapligim\MobileApi\Service\MobileSession;

class AuthLogout extends AbstractMobileController
{
	public function actionPost()
	{
		$this->assertMobileWriteScope();
		$this->assertRegisteredApiUser();
		MobileSession::revokeAccessToken(MobileSession::bearerToken($this->request->getAuthorizationHeader()));

		return $this->apiResult(['success' => true, 'logged_out' => true]);
	}
}
