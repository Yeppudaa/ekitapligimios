<?php

namespace Ekitapligim\MobileApi\Api\Controller;

use XF\Mvc\ParameterBag;

class BookRequestVote extends AbstractMobileController
{
	public function actionPost(ParameterBag $params)
	{
		$this->assertMobileWriteScope();
		$visitor = $this->assertRegisteredApiUser();
		$requestId = (int) $params->request_id;

		$db = \XF::db();
		$db->beginTransaction();
		try
		{
			$currentCount = $db->fetchOne(
				'SELECT support_count FROM xf_ekitap_book_request WHERE request_id = ? FOR UPDATE',
				[$requestId]
			);
			if ($currentCount === false)
			{
				$db->rollback();
				return $this->apiError('Request not found.', 'request_not_found', null, 404);
			}

			$exists = (bool) $db->fetchOne(
				'SELECT 1 FROM xf_ekitap_book_request_support WHERE request_id = ? AND user_id = ?',
				[$requestId, (int) $visitor->user_id]
			);

			if ($exists)
			{
				$db->delete(
					'xf_ekitap_book_request_support',
					'request_id = ? AND user_id = ?',
					[$requestId, (int) $visitor->user_id]
				);
				$voted = false;
				$voteCount = max(0, (int) $currentCount - 1);
			}
			else
			{
				$db->insert('xf_ekitap_book_request_support', [
					'request_id' => $requestId,
					'user_id' => (int) $visitor->user_id,
					'support_date' => \XF::$time,
				], false);
				$voted = true;
				$voteCount = (int) $currentCount + 1;
			}

			$db->update(
				'xf_ekitap_book_request',
				['support_count' => $voteCount],
				'request_id = ?',
				[$requestId]
			);
			$db->commit();
		}
		catch (\Throwable $e)
		{
			$db->rollback();
			throw $e;
		}

		return $this->apiResult([
			'success' => true,
			'voted' => $voted,
			'vote_count' => $voteCount,
			'voteCount' => $voteCount,
		]);
	}
}
