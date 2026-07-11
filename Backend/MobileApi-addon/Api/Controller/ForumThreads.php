<?php

namespace Ekitapligim\MobileApi\Api\Controller;

use XF\Mvc\ParameterBag;

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
