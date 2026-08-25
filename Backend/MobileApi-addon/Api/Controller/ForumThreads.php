<?php

namespace Ekitapligim\MobileApi\Api\Controller;

use XF\Mvc\ParameterBag;
use XF\Service\FloodCheckService;

class ForumThreads extends AbstractMobileController
{
	public function actionGet(ParameterBag $params)
	{
		$this->assertMobileScope();

		$forum = $this->assertViewableForum((int) $params->node_id);
		$page = max(1, (int) $this->filter('page', 'uint'));
		$perPage = min(50, max(1, (int) ($this->filter('per_page', 'uint') ?: 20)));

		$finder = $this->finder('XF:Thread')
			->where('node_id', (int) $forum->node_id)
			->where('discussion_state', 'visible')
			->with(['User', 'Forum'])
			->order('sticky', 'DESC')
			->order('last_post_date', 'DESC');

		$total = $finder->total();
		$threads = $finder->limitByPage($page, $perPage)->fetch();
		$items = [];

		foreach ($threads AS $thread)
		{
			if ($thread->canView())
			{
				$items[] = $this->serializeThread($thread);
			}
		}

		return $this->apiResult([
			'items' => $items,
			'threads' => $items,
			'forum' => [
				'id' => (string) $forum->node_id,
				'node_id' => (int) $forum->node_id,
				'title' => (string) $forum->title,
			],
			'current_page' => $page,
			'currentPage' => $page,
			'last_page' => (int) max(1, ceil($total / $perPage)),
			'lastPage' => (int) max(1, ceil($total / $perPage)),
			'total' => $total,
			'pagination' => $this->paginationMeta($page, $perPage, $total)
		]);
	}

	public function actionPost(ParameterBag $params)
	{
		$visitor = $this->assertRegisteredApiUser();
		$forumNode = $this->assertViewableForum((int) $params->node_id);
		$forum = $this->em()->find('XF:Forum', (int) $forumNode->node_id);
		if (!$forum)
		{
			throw $this->exception($this->apiError('Forum not found.', 'forum_not_found', null, 404));
		}

		if (!$this->hasAcceptedCurrentTerms((int) $visitor->user_id))
		{
			return $this->apiError('Topluluk kurallarını kabul etmeden konu açamazsınız.', 'terms_acceptance_required', [
				'required_version' => Terms::CURRENT_VERSION,
				'requiredVersion' => Terms::CURRENT_VERSION
			], 403);
		}

		if (!$forum->canCreateThread($error))
		{
			throw $this->exception($this->apiError($error ?: 'You cannot create a thread in this forum.', 'cannot_create_thread', null, 403));
		}

		$title = trim((string) $this->filter('title', 'str'));
		$message = trim((string) $this->filter('message', 'str'));
		if (mb_strlen($title) < 3)
		{
			return $this->apiError('Thread title is too short.', 'title_too_short');
		}
		if (mb_strlen($message) < 2)
		{
			return $this->apiError('Thread message is too short.', 'message_too_short');
		}

		if (!$visitor->hasPermission('general', 'bypassFloodCheck'))
		{
			$floodChecker = $this->service(FloodCheckService::class);
			$timeRemaining = $floodChecker->checkFlooding('post', (int) $visitor->user_id);
			if ($timeRemaining)
			{
				return $this->apiError(
					(string) \XF::phrase('must_wait_x_seconds_before_performing_this_action', [
						'count' => $timeRemaining
					]),
					'thread_flooding',
					[
						'retry_after' => (int) $timeRemaining,
						'retryAfter' => (int) $timeRemaining
					],
					429
				);
			}
		}

		$creator = $this->service('XF:Thread\Creator', $forum);
		$creator->setContent($title, $message);
		$creator->checkForSpam();

		if (!$creator->validate($errors))
		{
			return $this->apiError(implode(' ', array_map('strval', $errors)), 'thread_invalid');
		}

		$thread = $creator->save();
		$creator->sendNotifications();
		$thread = $this->em()->find('XF:Thread', (int) $thread->thread_id, ['User', 'Forum']);

		return $this->apiResult([
			'success' => true,
			'thread' => $this->serializeThread($thread)
		]);
	}

	protected function hasAcceptedCurrentTerms(int $userId): bool
	{
		\XF::db()->query(
			'CREATE TABLE IF NOT EXISTS xf_ekitapligim_mobile_terms_acceptance (
				user_id INT UNSIGNED NOT NULL,
				terms_version VARCHAR(32) NOT NULL,
				accept_date INT UNSIGNED NOT NULL,
				PRIMARY KEY (user_id)
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
		);

		return (bool) \XF::db()->fetchOne(
			'SELECT 1 FROM xf_ekitapligim_mobile_terms_acceptance WHERE user_id = ? AND terms_version = ? LIMIT 1',
			[$userId, Terms::CURRENT_VERSION]
		);
	}

	protected function assertViewableForum(int $nodeId)
	{
		$node = $this->em()->find('XF:Node', $nodeId);
		if (!$node || $node->node_type_id !== 'Forum' || !$node->canView())
		{
			throw $this->exception($this->apiError('Forum not found.', 'forum_not_found', null, 404));
		}

		return $node;
	}

	protected function serializeThread(\XF\Entity\Thread $thread): array
	{
		$username = $thread->User ? (string) $thread->User->username : (string) $thread->username;

		return [
			'id' => (string) $thread->thread_id,
			'thread_id' => (int) $thread->thread_id,
			'threadId' => (int) $thread->thread_id,
			'title' => (string) $thread->title,
			'username' => $username,
			'user_id' => (int) $thread->user_id,
			'userId' => (int) $thread->user_id,
			'reply_count' => (int) $thread->reply_count,
			'replyCount' => (int) $thread->reply_count,
			'view_count' => (int) $thread->view_count,
			'viewCount' => (int) $thread->view_count,
			'post_date' => (int) $thread->post_date,
			'postDate' => (int) $thread->post_date,
			'last_post_date' => (int) $thread->last_post_date,
			'lastPostDate' => (int) $thread->last_post_date,
			'can_reply' => (bool) $thread->canReply(),
			'canReply' => (bool) $thread->canReply(),
			'is_sticky' => (bool) $thread->sticky,
			'isSticky' => (bool) $thread->sticky,
			'discussion_type' => (string) $thread->discussion_type,
			'discussionType' => (string) $thread->discussion_type,
		];
	}
}
