<?php

namespace Ekitapligim\MobileApi\Api\Controller;

use XF\Mvc\ParameterBag;
use XF\Service\FloodCheckService;

class ThreadPosts extends AbstractMobileController
{
	public function actionGet(ParameterBag $params)
	{
		$this->assertMobileScope();

		$thread = $this->assertViewableThread((int) $params->thread_id);
		$page = max(1, (int) $this->filter('page', 'uint'));
		$perPage = min(50, max(1, (int) ($this->filter('per_page', 'uint') ?: 20)));

		$finder = $this->finder('XF:Post')
			->where('thread_id', (int) $thread->thread_id)
			->where('message_state', 'visible')
			->with(['User', 'Thread'])
			->order('post_date', 'ASC');

		$total = $finder->total();
		$posts = $finder->limitByPage($page, $perPage)->fetch();
		$items = [];

		foreach ($posts AS $post)
		{
			if ($post->canView())
			{
				$items[] = $this->serializePost($post, $thread);
			}
		}

		return $this->apiResult([
			'items' => $items,
			'posts' => $items,
			'thread' => $this->serializeThreadSummary($thread),
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
		$thread = $this->assertViewableThread((int) $params->thread_id);

		if (!$this->hasAcceptedCurrentTerms((int) $visitor->user_id))
		{
			return $this->apiError('Topluluk kurallarını kabul etmeden cevap yazamazsınız.', 'terms_acceptance_required', [
				'required_version' => Terms::CURRENT_VERSION,
				'requiredVersion' => Terms::CURRENT_VERSION
			], 403);
		}

		if (!$thread->canReply($error))
		{
			throw $this->exception($this->apiError($error ?: 'You cannot reply to this thread.', 'cannot_reply', null, 403));
		}

		$message = trim((string) $this->filter('message', 'str'));
		if (mb_strlen($message) < 2)
		{
			return $this->apiError('Reply message is too short.', 'message_too_short');
		}

		$replier = $this->service('XF:Thread\Replier', $thread);
		$replier->setMessage($message);
		$replier->checkForSpam();

		if (!$replier->validate($errors))
		{
			return $this->apiError(implode(' ', array_map('strval', $errors)), 'reply_invalid');
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
					'reply_flooding',
					[
						'retry_after' => (int) $timeRemaining,
						'retryAfter' => (int) $timeRemaining
					],
					429
				);
			}
		}

		$post = $replier->save();
		$replier->sendNotifications();

		return $this->apiResult([
			'success' => true,
			'post' => $this->serializePost($post, $thread)
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

	protected function assertViewableThread(int $threadId): \XF\Entity\Thread
	{
		$thread = $this->em()->find('XF:Thread', $threadId, ['Forum', 'User']);
		if (!$thread || !$thread->canView())
		{
			throw $this->exception($this->apiError('Thread not found.', 'thread_not_found', null, 404));
		}

		return $thread;
	}

	protected function serializeThreadSummary(\XF\Entity\Thread $thread): array
	{
		return [
			'id' => (string) $thread->thread_id,
			'thread_id' => (int) $thread->thread_id,
			'threadId' => (int) $thread->thread_id,
			'title' => (string) $thread->title,
			'can_reply' => (bool) $thread->canReply(),
			'canReply' => (bool) $thread->canReply(),
		];
	}

	protected function serializePost(\XF\Entity\Post $post, \XF\Entity\Thread $thread): array
	{
		$user = $post->User;
		$username = $user ? (string) $user->username : (string) $post->username;

		return [
			'id' => (string) $post->post_id,
			'post_id' => (int) $post->post_id,
			'postId' => (int) $post->post_id,
			'thread_id' => (string) $thread->thread_id,
			'threadId' => (string) $thread->thread_id,
			'thread_title' => (string) $thread->title,
			'threadTitle' => (string) $thread->title,
			'username' => $username,
			'user_id' => (int) $post->user_id,
			'userId' => (int) $post->user_id,
			'avatar_url' => $user ? (string) $user->getAvatarUrl('m', null, true) : '',
			'avatarUrl' => $user ? (string) $user->getAvatarUrl('m', null, true) : '',
			'message' => (string) $post->message,
			'post_date' => (int) $post->post_date,
			'postDate' => (int) $post->post_date,
			'can_edit' => (bool) $post->canEdit(),
			'canEdit' => (bool) $post->canEdit(),
			'can_reply' => (bool) $thread->canReply(),
			'canReply' => (bool) $thread->canReply(),
			'is_admin' => (bool) ($user && $user->is_admin),
			'isAdmin' => (bool) ($user && $user->is_admin),
			'is_moderator' => (bool) ($user && $user->is_moderator),
			'isModerator' => (bool) ($user && $user->is_moderator),
			'is_premium' => (bool) ($user && ($this->mobileUserRolePayload($user)['is_premium'] ?? false)),
			'isPremium' => (bool) ($user && ($this->mobileUserRolePayload($user)['isPremium'] ?? false)),
			'image_urls' => [],
			'imageUrls' => [],
		];
	}
}
