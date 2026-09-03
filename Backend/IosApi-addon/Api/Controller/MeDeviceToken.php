<?php

namespace Ekitapligim\IosApi\Api\Controller;

class MeDeviceToken extends \Ekitapligim\MobileApi\Api\Controller\AbstractMobileController
{
	public function actionPost()
	{
		$this->assertMobileWriteScope();
		$visitor = $this->assertRegisteredApiUser();

		$token = trim((string) $this->filter('device_token', 'str'));
		$platform = trim((string) ($this->filter('platform', 'str') ?: 'ios'));

		if ($token === '')
		{
			return $this->apiError('device_token is required.', 'missing_device_token', 400);
		}

		$db = $this->app()->db();
		$db->insert('xf_ios_device_tokens', [
			'user_id' => (int) $visitor->user_id,
			'device_token' => $token,
			'platform' => $platform,
			'created_at' => \XF::$time,
		], false, 'user_id = VALUES(user_id), platform = VALUES(platform), created_at = VALUES(created_at)');

		return $this->apiSuccess(['registered' => true]);
	}

	public function actionDelete()
	{
		$this->assertMobileWriteScope();
		$visitor = $this->assertRegisteredApiUser();

		$token = trim((string) $this->filter('device_token', 'str'));

		if ($token === '')
		{
			return $this->apiError('device_token is required.', 'missing_device_token', 400);
		}

		$db = $this->app()->db();
		$db->delete('xf_ios_device_tokens', 'device_token = ? AND user_id = ?', [$token, (int) $visitor->user_id]);

		return $this->apiSuccess(['unregistered' => true]);
	}
}
