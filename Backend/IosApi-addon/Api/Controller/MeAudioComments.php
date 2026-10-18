<?php

namespace Ekitapligim\IosApi\Api\Controller;

/** Personal audio replies use the same published-book and entity permissions as the website. */
class MeAudioComments extends \Ekitapligim\MobileApi\Api\Controller\AbstractMobileController
{
	public function actionGet()
	{
		$this->assertMobileScope('user:read');
		$visitor = $this->assertRegisteredApiUser();
		$addon = $this->app()->addOnManager()->getById('EKitapligim/AudioBooks');
		if (!$addon || !$addon->isActive()
			|| !class_exists('EKitapligim\AudioBooks\Repository\Catalog')
			|| !class_exists('EKitapligim\AudioBooks\Repository\ProfileLibrary'))
		{
			return $this->apiError('Sesli kitap yorumları şu anda kullanılamıyor.', 'audio_unavailable', null, 503);
		}

		$page = max(1, (int) $this->filter('page', 'uint'));
		$perPage = min(50, max(1, (int) ($this->filter('per_page', 'uint') ?: 30)));
		$rows = $this->repository('EKitapligim\AudioBooks:ProfileLibrary')->comments($visitor);
		$posts = [];
		foreach ($rows AS $row)
		{
			$post = $row['content'] ?? null;
			if (!$post instanceof \XF\Entity\Post
				|| (int) $post->user_id !== (int) $visitor->user_id
				|| (int) $post->position <= 0 || $post->message_state !== 'visible'
				|| !$post->canView())
			{
				continue;
			}
			$thread = $post->Thread;
			if (!$thread || $thread->discussion_state !== 'visible' || !$thread->canView()) continue;
			$posts[(int) $post->post_id] = $post;
		}

		// Count and paginate after all permissions, so hidden replies never affect totals or pages.
		usort($posts, static fn ($a, $b) => (int) $b->post_date <=> (int) $a->post_date
			?: (int) $b->post_id <=> (int) $a->post_id);
		$total = count($posts);
		$items = [];
		foreach (array_slice($posts, ($page - 1) * $perPage, $perPage) AS $post)
		{
			$thread = $post->Thread;
			$user = $post->User ?: $visitor;
			$role = $this->mobileUserRolePayload($user);
			$items[] = array_merge($role, [
				'id' => (string) $post->post_id,
				'post_id' => (int) $post->post_id,
				'thread_id' => (int) $thread->thread_id,
				'thread_title' => (string) $thread->title,
				'threadTitle' => (string) $thread->title,
				'user_id' => (int) $post->user_id,
				'username' => (string) $user->username,
				'message' => (string) $post->message,
				'message_parsed' => (string) $post->message,
				'post_date' => (int) $post->post_date,
				'is_premium_author' => (bool) ($role['is_premium'] ?? false),
				'can_edit' => (bool) $post->canEdit(),
				'can_delete' => (bool) $post->canDelete('soft'),
				'can_reply' => (bool) $thread->canReply(),
			]);
		}

		$pagination = $this->paginationMeta($page, $perPage, $total);
		$pagination['pages'] = max(1, (int) $pagination['pages']);
		return $this->apiResult([
			'scope' => 'audio',
			'items' => $items,
			'comments' => $items,
			'pagination' => $pagination,
		]);
	}
}
