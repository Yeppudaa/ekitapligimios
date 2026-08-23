<?php

namespace Ekitapligim\IosApi\Api\Controller;

use XF\Service\User\AvatarService;
use XF\Service\User\ProfileBannerService;
use XF\Mvc\ParameterBag;

class MeMedia extends \Ekitapligim\MobileApi\Api\Controller\AbstractMobileController
{
	public function actionAvatar(ParameterBag $params)
	{
		if (strtolower($this->request->getRequestMethod()) === 'delete')
		{
			return $this->actionDeleteAvatar();
		}

		return $this->actionPostAvatar();
	}

	public function actionBanner(ParameterBag $params)
	{
		if (strtolower($this->request->getRequestMethod()) === 'delete')
		{
			return $this->actionDeleteBanner();
		}

		return $this->actionPostBanner();
	}

	public function actionPostAvatar()
	{
		$this->assertMobileWriteScope();
		$visitor = $this->assertRegisteredApiUser();
		if (!$visitor->canUploadAvatar())
		{
			return $this->apiError('Avatar upload is not allowed for this account.', 'avatar_upload_denied', null, 403);
		}

		$upload = $this->request->getFile('image', false, false)
			?: $this->request->getFile('avatar', false, false);
		if (!$upload)
		{
			return $this->apiError('An image file is required.', 'image_required', null, 400);
		}

		/** @var AvatarService $service */
		$service = $this->service(AvatarService::class, $visitor);
		if (!$service->setImageFromUpload($upload))
		{
			return $this->apiError((string) $service->getError(), 'avatar_invalid', null, 400);
		}
		if (!$service->updateAvatar())
		{
			return $this->apiError('Avatar could not be processed.', 'avatar_processing_failed', null, 400);
		}

		return $this->apiResult([
			'success' => true,
			'avatar_url' => (string) $visitor->getAvatarUrl('l', null, true),
		]);
	}

	public function actionDeleteAvatar()
	{
		$this->assertMobileWriteScope();
		$visitor = $this->assertRegisteredApiUser();
		/** @var AvatarService $service */
		$service = $this->service(AvatarService::class, $visitor);
		$service->deleteAvatar();
		return $this->apiSuccess();
	}

	public function actionPostBanner()
	{
		$this->assertMobileWriteScope();
		$visitor = $this->assertRegisteredApiUser();
		if (!$visitor->canUploadProfileBanner())
		{
			return $this->apiError('Profile banner upload is not allowed for this account.', 'banner_upload_denied', null, 403);
		}

		$upload = $this->request->getFile('image', false, false)
			?: $this->request->getFile('banner', false, false);
		if (!$upload)
		{
			return $this->apiError('An image file is required.', 'image_required', null, 400);
		}

		/** @var ProfileBannerService $service */
		$service = $this->service(ProfileBannerService::class, $visitor);
		if (!$service->setImageFromUpload($upload))
		{
			return $this->apiError((string) $service->getError(), 'banner_invalid', null, 400);
		}
		if (!$service->updateBanner())
		{
			return $this->apiError('Profile banner could not be processed.', 'banner_processing_failed', null, 400);
		}

		return $this->apiResult([
			'success' => true,
			'banner_url' => (string) $visitor->Profile->getBannerUrl('l', true),
		]);
	}

	public function actionDeleteBanner()
	{
		$this->assertMobileWriteScope();
		$visitor = $this->assertRegisteredApiUser();
		/** @var ProfileBannerService $service */
		$service = $this->service(ProfileBannerService::class, $visitor);
		$service->deleteBanner();
		return $this->apiSuccess();
	}
}
