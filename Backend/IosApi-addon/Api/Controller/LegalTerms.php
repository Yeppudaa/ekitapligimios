<?php

namespace Ekitapligim\IosApi\Api\Controller;

use Ekitapligim\IosApi\Service\TermsAcceptance;

class LegalTerms extends \Ekitapligim\MobileApi\Api\Controller\AbstractMobileController
{
	public function actionGet()
	{
		$this->assertMobileScope();
		return $this->apiResult([
			'version' => TermsAcceptance::CURRENT_VERSION,
			'eula_url' => 'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
			'eulaUrl' => 'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
			'terms_url' => 'https://ekitapligim.com/yardim/kurallar/',
			'termsUrl' => 'https://ekitapligim.com/yardim/kurallar/',
			'privacy_url' => 'https://ekitapligim.com/yardim/gizlilik-politikasi/',
			'privacyUrl' => 'https://ekitapligim.com/yardim/gizlilik-politikasi/',
			'support_url' => 'https://ekitapligim.com/diger/iletisim',
			'supportUrl' => 'https://ekitapligim.com/diger/iletisim',
			'moderation_sla_hours' => 24,
			'moderationSlaHours' => 24,
		]);
	}
}
