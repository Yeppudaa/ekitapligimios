<?php

namespace Ekitapligim\MobileApi\Api\Controller;

use XF\Mvc\ParameterBag;
use XF\Service\FloodCheckService;

class PostReport extends AbstractMobileController
{
	public function actionPost(ParameterBag $params)
	{
		$this->assertMobileWriteScope();
		$visitor = $this->assertRegisteredApiUser();

		$post = $this->em()->find('XF:Post', (int) $params->post_id, ['Thread']);
		if (!$post || !$post->canView())
		{
			throw $this->exception($this->notFound());
		}
		if (!$post->canReport($error))
		{
			return $this->apiError($error ?: 'You cannot report this post.', 'cannot_report', null, 403);
		}

		$message = trim($this->filter('message', 'str'));
		if (mb_strlen($message) < 8)
		{
			return $this->apiError('Report message is too short.', 'message_too_short');
		}

		try
		{
			$creator = $this->service('XF:Report\Creator', 'post', $post);
			$creator->setMessage($message);
			if (!$creator->validate($errors))
			{
				return $this->apiError(implode(' ', array_map('strval', $errors)), 'report_invalid');
			}
			if (!$visitor->hasPermission('general', 'bypassFloodCheck'))
			{
				$floodChecker = $this->service(FloodCheckService::class);
				$timeRemaining = $floodChecker->checkFlooding('report', (int) $visitor->user_id);
				if ($timeRemaining)
				{
					return $this->apiError(
						(string) \XF::phrase('must_wait_x_seconds_before_performing_this_action', ['count' => $timeRemaining]),
						'report_flooding',
						['retry_after' => (int) $timeRemaining, 'retryAfter' => (int) $timeRemaining],
						429
					);
				}
			}
			$creator->save();
			$creator->sendNotifications();
		}
		catch (\Throwable $e)
		{
			\XF::logException($e, false, 'MobileApi post report failed: ');
			return $this->apiError('Report could not be submitted.', 'report_failed');
		}

		return $this->apiResult(['success' => true]);
	}
}
