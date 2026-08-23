<?php

namespace Ekitapligim\IosApi\Api\Controller;

use Ekitapligim\IosApi\Service\ReadingStats;

class MeReadingStats extends \Ekitapligim\MobileApi\Api\Controller\AbstractMobileController
{
	public function actionGet()
	{
		$this->assertMobileScope('user:read');
		$visitor = $this->assertRegisteredApiUser();
		return $this->apiResult((new ReadingStats())->get((int) $visitor->user_id));
	}

	public function actionPost()
	{
		$this->assertMobileWriteScope();
		$visitor = $this->assertRegisteredApiUser();
		$service = new ReadingStats();
		$goal = (int) $this->filter('daily_goal_minutes', 'uint');
		if ($goal)
		{
			return $this->apiResult($service->setGoal((int) $visitor->user_id, $goal));
		}

		try
		{
			$stats = $service->recordSession(
				(int) $visitor->user_id,
				(string) $this->filter('client_session_id', 'str'),
				(int) $this->filter('book_id', 'uint'),
				(string) $this->filter('reading_date', 'str'),
				(int) $this->filter('seconds', 'uint'),
				(int) $this->filter('pages', 'uint')
			);
			return $this->apiResult($stats);
		}
		catch (\InvalidArgumentException $e)
		{
			return $this->apiError($e->getMessage(), 'reading_session_invalid', null, 400);
		}
	}
}
