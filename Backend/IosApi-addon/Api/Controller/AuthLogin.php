<?php

namespace Ekitapligim\IosApi\Api\Controller;

use Ekitapligim\IosApi\Service\TermsAcceptance;
use XF\Entity\User;
use XF\Service\User\LoginService;

class AuthLogin extends \Ekitapligim\MobileApi\Api\Controller\AbstractMobileController
{
	public function actionPost()
	{
		$this->assertMobileWriteScope();
		$acceptedVersion = trim((string) $this->filter('accepted_terms_version', 'str'));
		if (!TermsAcceptance::isCurrent($acceptedVersion))
		{
			return $this->apiError('Güncel kullanım şartlarını kabul etmelisiniz.', 'terms_acceptance_required', [
				'required_version' => TermsAcceptance::CURRENT_VERSION,
				'requiredVersion' => TermsAcceptance::CURRENT_VERSION,
			], 403);
		}

		$login = trim($this->filter('login', 'str'));
		$password = (string) $this->filter('password', 'str');

		if ($login === '' || $password === '')
		{
			return $this->apiError('Login and password are required.', 'missing_credentials', null, 400);
		}

		/** @var LoginService $loginService */
		$loginService = $this->service(LoginService::class, $login, $this->request->getIp());
		if ($loginService->isLoginLimited($limitType))
		{
			return $this->apiError('Too many login attempts. Please try again later.', 'login_limited', ['limit_type' => $limitType], 429);
		}

		$error = null;
		$user = $loginService->validate($password, $error);
		if (!$user)
		{
			return $this->apiError($error ?: 'Login failed.', 'auth_failed', null, 401);
		}

		if (!$this->isUsableMobileUser($user))
		{
			return $this->apiError('This account cannot be used right now.', 'account_unavailable', null, 403);
		}
		TermsAcceptance::record((int) $user->user_id, $acceptedVersion);

		return $this->apiResult($this->buildAuthPayload($user));
	}

	protected function isUsableMobileUser(User $user): bool
	{
		if ($user->is_banned || $user->user_state === 'rejected' || $user->user_state === 'disabled')
		{
			return false;
		}

		return true;
	}

	protected function buildAuthPayload(User $user): array
	{
		return $this->buildMobileAuthPayload($user);
	}
}

