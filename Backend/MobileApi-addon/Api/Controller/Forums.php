<?php

namespace Ekitapligim\MobileApi\Api\Controller;

class Forums extends AbstractMobileController
{
	public function actionGet()
	{
		$this->assertMobileScope();

		$nodes = $this->finder('XF:Node')
			->where('node_type_id', 'Forum')
			->order('display_order')
			->fetch();

		$forums = [];
		foreach ($nodes AS $node)
		{
			if (!$node->canView())
			{
				continue;
			}

			$threadCount = $this->forumCounter($node, 'discussion_count');
			$messageCount = $this->forumCounter($node, 'message_count');

			$forums[] = [
				'id' => (string) $node->node_id,
				'node_id' => (int) $node->node_id,
				'nodeId' => (int) $node->node_id,
				'title' => (string) $node->title,
				'description' => (string) $node->description,
				'url' => $this->buildForumUrl($node),
				'stats' => $this->buildStatsText($threadCount, $messageCount),
				'thread_count' => $threadCount,
				'threadCount' => $threadCount,
				'message_count' => $messageCount,
				'messageCount' => $messageCount,
				'is_book_forum' => true,
				'isBookForum' => true,
			];
		}

		return $this->apiResult([
			'forums' => $forums,
			'items' => $forums,
		]);
	}

	protected function forumCounter($node, string $forumColumn): int
	{
		try
		{
			return (int) \XF::db()->fetchOne(
				"SELECT {$forumColumn} FROM xf_forum WHERE node_id = ?",
				(int) $node->node_id
			);
		}
		catch (\Throwable $e)
		{
			return 0;
		}
	}

	protected function buildForumUrl($node): string
	{
		try
		{
			return (string) \XF::app()->router('public')->buildLink('canonical:forums', $node);
		}
		catch (\Throwable $e)
		{
			return '';
		}
	}

	protected function buildStatsText(int $threadCount, int $messageCount): string
	{
		return sprintf('%d konu, %d mesaj', $threadCount, $messageCount);
	}
}
