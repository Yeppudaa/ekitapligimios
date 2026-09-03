<?php

namespace Ekitapligim\IosApi\Service;

use XF\Entity\UserAlert;

final class AlertAppRoute
{
	public static function fromAlert(UserAlert $alert, string $url = ''): string
	{
		try
		{
			return self::fromAlertInner($alert, $url);
		}
		catch (\Throwable $e)
		{
			\XF::logException($e, false, 'IosApi AlertAppRoute: ');
			return self::fromUrl($url);
		}
	}

	protected static function fromAlertInner(UserAlert $alert, string $url = ''): string
	{
		$type = strtolower(trim((string) $alert->content_type));
		$action = strtolower(trim((string) $alert->action));
		$contentId = (int) $alert->content_id;
		$extra = is_array($alert->extra_data) ? $alert->extra_data : [];

		if ($action === 'book_request_new')
		{
			return 'requests';
		}

		$socialPostId = self::socialPostId($type, $contentId, $extra);
		if ($socialPostId > 0)
		{
			return 'book-agenda/' . $socialPostId;
		}

		$readingRoute = self::readingInvitationRoute($type, $alert);
		if ($readingRoute !== '')
		{
			return $readingRoute;
		}

		$memberRoute = self::memberRoute($alert);
		if ($memberRoute !== '')
		{
			return $memberRoute;
		}

		$conversationId = self::conversationId($type, $alert, $contentId, $extra);
		if ($conversationId > 0)
		{
			return 'conversation/' . $conversationId;
		}
		if (strpos($type, 'conversation') !== false)
		{
			return 'messages';
		}

		$chatRoomId = self::chatRoomId($type, $alert, $contentId, $extra);
		if ($chatRoomId > 0)
		{
			return 'chat/' . $chatRoomId;
		}

		$threadRoute = self::threadRouteFromAlert($type, $alert, $contentId, $extra);
		if ($threadRoute !== '')
		{
			return $threadRoute;
		}

		$fromUrl = self::fromUrl($url);
		if ($fromUrl !== '')
		{
			return $fromUrl;
		}

		return '';
	}

	public static function memberRoute(UserAlert $alert): string
	{
		$type = strtolower(trim((string) $alert->content_type));
		$action = strtolower(trim((string) $alert->action));

		if ($action === 'book_request_new')
		{
			return '';
		}

		$isMemberAlert = in_array($type, ['user', 'member', 'profile_post', 'profile_post_comment'], true)
			|| strpos($type, 'profile_visitor') !== false
			|| strpos($type, 'profilevisitor') !== false
			|| in_array($action, [
				'following',
				'follow',
				'visit',
				'profile_view',
				'profile_visit',
				'profile_visitor'
			], true);

		if (!$isMemberAlert)
		{
			return '';
		}

		$memberId = (int) $alert->user_id;
		if ($memberId <= 0 && in_array($type, ['user', 'member'], true))
		{
			$memberId = (int) $alert->content_id;
		}
		if ($memberId <= 0)
		{
			$extra = is_array($alert->extra_data) ? $alert->extra_data : [];
			$memberId = (int) ($extra['visitor_id'] ?? $extra['user_id'] ?? $extra['visitorUserId'] ?? 0);
		}

		return $memberId > 0 ? 'member/' . $memberId : '';
	}

	public static function fromUrl(string $url): string
	{
		if ($url === '')
		{
			return '';
		}

		$path = (string) (parse_url($url, PHP_URL_PATH) ?: '');
		if ($path === '')
		{
			return '';
		}

		if (preg_match('#/(?:books|konular)/[^/]*\.(\d+)/?#i', $path, $match))
		{
			return 'detail/' . $match[1];
		}
		if (preg_match('#/(?:threads|konular)/[^/]*\.(\d+)/?#i', $path, $match)
			|| preg_match('#/threads/(\d+)/?#i', $path, $match))
		{
			return 'thread/' . $match[1];
		}
		if (preg_match('#/forums?/(\d+)/?#i', $path, $match))
		{
			return 'forum/' . $match[1];
		}
		if (preg_match('#/kitap-gundemi/(?:[^/]*\.)?(\d+)/?#i', $path, $match))
		{
			return 'book-agenda/' . $match[1];
		}
		if (strpos($path, '/kitap-gundemi') === 0)
		{
			return 'book-agenda';
		}
		if (preg_match('#/conversations?/(?:[^/]*\.)?(\d+)/?#i', $path, $match))
		{
			return 'conversation/' . $match[1];
		}
		if (strpos($path, '/book-requests') === 0)
		{
			return 'requests';
		}
		if (preg_match('#/members/(?:[^/]*\.)?(\d+)/?#i', $path, $match))
		{
			return 'member/' . $match[1];
		}
		if (preg_match('#/chat/(?:[^/]*\.)?(\d+)/?#i', $path, $match))
		{
			return 'chat/' . $match[1];
		}

		return '';
	}

	protected static function socialPostId(string $type, int $contentId, array $extra): int
	{
		$isSocial = in_array($type, [
			'ek_social_post',
			'ek_social_comment',
			'social_post',
			'book_agenda',
			'kitap_gundemi'
		], true) || strpos($type, 'social_post') !== false;

		if (!$isSocial)
		{
			return 0;
		}

		$postId = (int) ($extra['post_id'] ?? $extra['social_post_id'] ?? $extra['socialPostId'] ?? 0);
		if ($postId <= 0 && $type !== 'ek_social_comment')
		{
			$postId = $contentId;
		}

		return $postId > 0 ? $postId : 0;
	}

	protected static function readingInvitationRoute(string $type, UserAlert $alert): string
	{
		if ($type !== 'ek_reading_invitation')
		{
			return '';
		}

		$content = self::alertContent($alert);
		$thread = null;
		try
		{
			$thread = $content->Thread ?? $content;
		}
		catch (\Throwable $e)
		{
			$thread = $content;
		}

		if ($thread && isset($thread->thread_id))
		{
			return self::threadRoute($thread);
		}

		return '';
	}

	protected static function conversationId(string $type, UserAlert $alert, int $contentId, array $extra): int
	{
		if (strpos($type, 'conversation') === false)
		{
			return 0;
		}

		$conversationId = (int) ($extra['conversation_id'] ?? $extra['conversationId'] ?? 0);
		$content = self::alertContent($alert);
		if ($conversationId <= 0 && $content && isset($content->conversation_id))
		{
			$conversationId = (int) $content->conversation_id;
		}
		if ($conversationId <= 0 && $type === 'conversation')
		{
			$conversationId = $contentId;
		}

		return $conversationId > 0 ? $conversationId : 0;
	}

	protected static function chatRoomId(string $type, UserAlert $alert, int $contentId, array $extra): int
	{
		if (strpos($type, 'chat') === false && $type !== 'siropu_chat_room_message')
		{
			return 0;
		}

		$roomId = (int) ($extra['room_id'] ?? $extra['roomId'] ?? 0);
		$content = self::alertContent($alert);
		if ($roomId <= 0 && $content)
		{
			try
			{
				$roomId = (int) ($content->room_id ?? 0);
				if ($roomId <= 0)
				{
					$roomId = (int) ($content->message_room_id ?? 0);
				}
			}
			catch (\Throwable $e)
			{
				$roomId = 0;
			}
		}
		if ($roomId <= 0)
		{
			$roomId = $contentId;
		}

		return $roomId > 0 ? $roomId : 0;
	}

	protected static function threadRouteFromAlert(string $type, UserAlert $alert, int $contentId, array $extra): string
	{
		$content = self::alertContent($alert);
		if ($content)
		{
			if ($type === 'thread' && isset($content->thread_id))
			{
				return self::threadRoute($content);
			}

			if (($type === 'post' || $type === 'forum_post') && isset($content->thread_id))
			{
				$thread = null;
				try
				{
					$thread = $content->Thread ?? null;
				}
				catch (\Throwable $e)
				{
					$thread = null;
				}
				if ($thread)
				{
					return self::threadRoute($thread);
				}

				return 'thread/' . (int) $content->thread_id;
			}
		}

		$threadId = (int) ($extra['thread_id'] ?? $extra['threadId'] ?? 0);
		if ($threadId <= 0 && $type === 'thread')
		{
			$threadId = $contentId;
		}
		if ($threadId <= 0 && ($type === 'post' || $type === 'forum_post') && $contentId > 0)
		{
			try
			{
				$post = \XF::em()->find('XF:Post', $contentId);
				$threadId = $post ? (int) $post->thread_id : 0;
			}
			catch (\Throwable $e)
			{
				$threadId = 0;
			}
		}

		if ($threadId <= 0)
		{
			return '';
		}

		try
		{
			$thread = \XF::em()->find('XF:Thread', $threadId);
			if ($thread)
			{
				return self::threadRoute($thread);
			}
		}
		catch (\Throwable $e)
		{
		}

		return 'thread/' . $threadId;
	}

	protected static function alertContent(UserAlert $alert)
	{
		try
		{
			return $alert->Content;
		}
		catch (\Throwable $e)
		{
			return null;
		}
	}

	protected static function threadRoute($thread): string
	{
		$threadId = (int) ($thread->thread_id ?? 0);
		if ($threadId <= 0)
		{
			return '';
		}

		if ((string) ($thread->discussion_type ?? '') === 'xcu_bookthreads_book')
		{
			return 'detail/' . $threadId;
		}

		return 'thread/' . $threadId;
	}
}
