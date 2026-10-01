<?php

namespace Ekitapligim\IosApi\XF\Extension;

use Ekitapligim\IosApi\Service\IosEntitlement;
use Ekitapligim\IosApi\Service\MobilePresence;
use XF\Entity\User;
use XF\Mvc\ParameterBag;

class AbstractMobileController extends XFCP_AbstractMobileController
{
	public function preDispatch($action, ParameterBag $params)
	{
		// Shared MobileApi public controllers also serve /ios-api. Their legacy
		// wrapper leaves web-cookie visitors in place when no bearer is valid.
		// Normalize before XenForo's user/permission checks, only on iOS routes.
		$route = ltrim((string) $this->request->getRoutePath(), '/');
		if (str_starts_with($route, 'ios-api/') && method_exists($this, 'applyMobileBearerVisitor'))
		{
			\XF::setVisitor(\XF::repository('XF:User')->getGuestUser());
			$this->applyMobileBearerVisitor();
			$user = \XF::visitor();
			if ($user->is_banned || in_array($user->user_state, ['rejected', 'disabled'], true))
			{
				\XF::setVisitor(\XF::repository('XF:User')->getGuestUser());
			}
		}
		return parent::preDispatch($action, $params);
	}

	protected function mobileIsPremiumUser(User $user, array $groupTitles): bool
	{
		if (parent::mobileIsPremiumUser($user, $groupTitles))
		{
			return true;
		}

		return IosEntitlement::hasActiveEntitlement($user);
	}

	protected function assertRegisteredApiUser(): User
	{
		$user = parent::assertRegisteredApiUser();
		MobilePresence::touch($user);

		return $user;
	}
}
