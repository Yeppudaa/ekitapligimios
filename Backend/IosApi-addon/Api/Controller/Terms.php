<?php

namespace Ekitapligim\IosApi\Api\Controller;

use Ekitapligim\IosApi\Service\TermsAcceptance;

class Terms extends \Ekitapligim\MobileApi\Api\Controller\AbstractMobileController
{
	public const CURRENT_VERSION = TermsAcceptance::CURRENT_VERSION;

	public function actionGet()
	{
		$this->assertMobileScope();
		$visitor = $this->assertRegisteredApiUser();
		return $this->apiResult(TermsAcceptance::status((int) $visitor->user_id));
	}

	public function actionAccept()
	{
		$this->assertMobileWriteScope();
		$visitor = $this->assertRegisteredApiUser();
		$version = trim($this->filter('version', 'str')) ?: self::CURRENT_VERSION;

		if ($version !== self::CURRENT_VERSION)
		{
			return $this->apiError('Terms version is not current.', 'terms_version_mismatch');
		}

		TermsAcceptance::record((int) $visitor->user_id, $version);

		return $this->apiResult(['success' => true]);
	}

}

