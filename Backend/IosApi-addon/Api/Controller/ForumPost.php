<?php

namespace Ekitapligim\IosApi\Api\Controller;

use XF\Mvc\ParameterBag;
use XF\Service\FloodCheckService;

class ForumPost extends \Ekitapligim\MobileApi\Api\Controller\AbstractMobileController
{
	use UgcControllerTrait;

	public function actionPost(ParameterBag $params)
	{
		if ($this->isDeleteOverride())
		{
			return $this->actionDelete($params);
		}

		return $this->editPost($params);
	}

	public function actionEdit(ParameterBag $params)
	{
		return $this->editPost($params);
	}

	public function actionPatch(ParameterBag $params)
	{
		return $this->editPost($params);
	}

	public function actionDelete(ParameterBag $params)
	{
		$visitor = $this->assertRegisteredApiUser();
		$post = $this->assertViewablePost((int) $params->post_id);
		$thread = $post->Thread;
		$isFirstPost = (bool) $post->isFirstPost();

		// First post deletion is thread deletion in XenForo.
		if ($isFirstPost)
		{
			if (!$thread || !$thread->canDelete('soft', $error))
			{
				return $this->apiError(
					$error ?: 'You cannot delete this thread.',
					'cannot_delete',
					null,
					403
				);
			}
		}
		else if (!$post->canDelete('soft', $error))
		{
			return $this->apiError(
				$error ?: 'You cannot delete this post.',
				'cannot_delete',
				null,
				403
			);
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
					'delete_flooding',
					[
						'retry_after' => (int) $timeRemaining,
						'retryAfter' => (int) $timeRemaining
					],
					429
				);
			}
		}

		try
		{
			if ($isFirstPost)
			{
				$deleter = $this->threadDeleter($thread);
				$deleter->delete('soft');
				return $this->apiResult([
					'success' => true,
					'thread_deleted' => true,
					'threadDeleted' => true,
				]);
			}

			$deleter = $this->postDeleter($post);
			$deleter->delete('soft');
		}
		catch (\Throwable $e)
		{
			\XF::logException($e, false, 'IosApi forum post delete failed: ');
			return $this->apiError('Post could not be deleted.', 'delete_failed', null, 500);
		}

		return $this->apiResult(['success' => true]);
	}

	protected function editPost(ParameterBag $params)
	{
		$visitor = $this->assertRegisteredApiUser();
		$post = $this->assertViewablePost((int) $params->post_id);

		if (!$post->canEdit($error))
		{
			throw $this->exception($this->apiError($error ?: 'You cannot edit this post.', 'cannot_edit', null, 403));
		}

		$message = $this->filterMessage();
		if ($policyError = $this->validateUgcWrite([$message]))
		{
			return $policyError;
		}
		if (mb_strlen($message) < 2)
		{
			return $this->apiError('Reply message is too short.', 'message_too_short');
		}

		$editor = $this->postEditor($post);
		$editor->setMessage($message);
		$editor->checkForSpam();

		if (!$editor->validate($errors))
		{
			return $this->apiError(implode(' ', array_map('strval', $errors)), 'edit_invalid');
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
					'edit_flooding',
					[
						'retry_after' => (int) $timeRemaining,
						'retryAfter' => (int) $timeRemaining
					],
					429
				);
			}
		}

		$saved = $editor->save();
		if ($saved instanceof \XF\Entity\Post)
		{
			$post = $saved;
		}
		else
		{
			$reloaded = $this->em()->find('XF:Post', (int) $params->post_id, ['Thread', 'Thread.Forum', 'User']);
			if ($reloaded)
			{
				$post = $reloaded;
			}
		}

		$thread = $post->Thread;
		if (!$thread)
		{
			$thread = $this->em()->find('XF:Thread', $post->thread_id, ['Forum', 'User']);
		}

		return $this->apiResult([
			'success' => true,
			'post' => $this->serializePost($post, $thread)
		]);
	}

	protected function isDeleteOverride(): bool
	{
		$method = strtolower(trim((string) $this->filter('_method', 'str')));
		return $method === 'delete';
	}

	protected function filterMessage(): string
	{
		$message = trim((string) $this->filter('message', 'str'));
		if ($message !== '')
		{
			return $message;
		}

		$raw = trim((string) $this->request->getInputRaw());
		if ($raw === '')
		{
			return '';
		}

		$decoded = json_decode($raw, true);
		if (is_array($decoded) && isset($decoded['message']))
		{
			return trim((string) $decoded['message']);
		}

		return '';
	}

	protected function postEditor(\XF\Entity\Post $post)
	{
		if (class_exists(\XF\Service\Post\EditorService::class))
		{
			return $this->service(\XF\Service\Post\EditorService::class, $post);
		}

		return $this->service('XF:Post\Editor', $post);
	}

	protected function postDeleter(\XF\Entity\Post $post)
	{
		if (class_exists(\XF\Service\Post\DeleterService::class))
		{
			return $this->service(\XF\Service\Post\DeleterService::class, $post);
		}

		return $this->service('XF:Post\Deleter', $post);
	}

	protected function threadDeleter(\XF\Entity\Thread $thread)
	{
		if (class_exists(\XF\Service\Thread\DeleterService::class))
		{
			return $this->service(\XF\Service\Thread\DeleterService::class, $thread);
		}

		return $this->service('XF:Thread\Deleter', $thread);
	}

	protected function assertViewablePost(int $postId): \XF\Entity\Post
	{
		$post = $this->em()->find('XF:Post', $postId, ['Thread', 'Thread.Forum', 'User']);
		if (!$post || !$post->canView())
		{
			throw $this->exception($this->apiError('Post not found.', 'post_not_found', null, 404));
		}

		return $post;
	}

	protected function serializePost(\XF\Entity\Post $post, $thread): array
	{
		$user = $post->User;
		$username = $user ? (string) $user->username : (string) $post->username;
		$canReply = $thread ? (bool) $thread->canReply() : false;

		return [
			'id' => (string) $post->post_id,
			'post_id' => (int) $post->post_id,
			'postId' => (int) $post->post_id,
			'thread_id' => (string) $post->thread_id,
			'threadId' => (string) $post->thread_id,
			'thread_title' => $thread ? (string) $thread->title : '',
			'threadTitle' => $thread ? (string) $thread->title : '',
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
			'can_delete' => (bool) $post->canDelete('soft'),
			'canDelete' => (bool) $post->canDelete('soft'),
			'can_reply' => $canReply,
			'canReply' => $canReply,
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
