<?php

namespace Ekitapligim\IosApi\XF\Extension;

use Ekitapligim\IosApi\Service\IosEntitlement;

class AbstractMobileController extends XFCP_AbstractMobileController
{
	protected function mobileIsPremiumUser(\XF\Entity\User $user, array $groupTitles): bool
	{
		if (parent::mobileIsPremiumUser($user, $groupTitles))
		{
			return true;
		}

		return IosEntitlement::hasActiveEntitlement($user);
	}
}
