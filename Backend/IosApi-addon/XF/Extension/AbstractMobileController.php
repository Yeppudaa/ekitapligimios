<?php

namespace Ekitapligim\IosApi\XF\Extension;

use Ekitapligim\IosApi\Service\IosEntitlement;
use Ekitapligim\IosApi\Service\MobilePresence;
use XF\Entity\User;

class AbstractMobileController extends XFCP_AbstractMobileController
{
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
