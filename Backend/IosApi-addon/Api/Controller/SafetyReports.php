<?php

namespace Ekitapligim\IosApi\Api\Controller;

use Ekitapligim\IosApi\Service\UgcModeration;

class SafetyReports extends \Ekitapligim\MobileApi\Api\Controller\AbstractMobileController
{
	public function actionPost()
	{
		$this->assertMobileWriteScope();
		$this->assertRegisteredApiUser();
		$type = strtolower(trim((string) $this->filter('content_type', 'str')));
		$contentId = (int) $this->filter('content_id', 'uint');
		$reason = strtolower(trim((string) $this->filter('reason_code', 'str')));
		$details = trim((string) $this->filter('details', 'str'));
		try
		{
			$result = UgcModeration::createReport($type, $contentId, $reason, $details);
			return $this->apiResult([
				'success' => true,
				'report_id' => (int) $result['report_id'],
				'reportId' => (int) $result['report_id'],
			]);
		}
		catch (\InvalidArgumentException | \LengthException $e)
		{
			return $this->apiError($e->getMessage(), 'invalid_report', null, 422);
		}
		catch (\OutOfBoundsException $e)
		{
			return $this->apiError('Report content not found.', 'content_not_found', null, 404);
		}
		catch (\DomainException $e)
		{
			return $this->apiError($e->getMessage(), 'cannot_report', null, 403);
		}
		catch (\Throwable $e)
		{
			\XF::logException($e, false, 'IosApi UGC report failed: ');
			return $this->apiError('Report could not be submitted.', 'report_failed', null, 500);
		}
	}
}
