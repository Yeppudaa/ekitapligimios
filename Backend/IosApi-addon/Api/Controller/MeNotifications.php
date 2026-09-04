<?php

namespace Ekitapligim\IosApi\Api\Controller;

use Ekitapligim\IosApi\Service\AlertAppRoute;
use Ekitapligim\IosApi\Service\NotificationCounts;
use XF\Entity\UserAlert;
use XF\Repository\UserAlertRepository;

class MeNotifications extends \Ekitapligim\MobileApi\Api\Controller\AbstractMobileController
{
	public function actionGet()
	{
		$this->assertMobileScope('alert:read');
		$visitor = $this->assertRegisteredApiUser();

		$page = max(1, (int) $this->filter('page', 'uint'));
		$perPage = min(50, max(1, (int) ($this->filter('per_page', 'uint') ?: 30)));
		$cutoff = (int) $this->filter('cutoff', 'uint');

		$finder = $this->getAlertRepo()
			->findAlertsForUser((int) $visitor->user_id, $cutoff)
			->with('api');

		if ($this->filter('unviewed', 'bool'))
		{
			$finder->where('view_date', 0);
		}
		if ($this->filter('unread', 'bool'))
		{
			$finder->where('read_date', 0);
		}

		$total = $finder->total();
		$alerts = $finder->limitByPage($page, $perPage)->fetch();

		try
		{
			$this->getAlertRepo()->addContentToAlerts($alerts);
		}
		catch (\Throwable $e)
		{
			\XF::logException($e, false, 'IosApi notifications addContent: ');
		}

		try
		{
			$alerts = $alerts->filterViewable();
		}
		catch (\Throwable $e)
		{
			\XF::logException($e, false, 'IosApi notifications filterViewable: ');
		}

		$items = [];
		foreach ($alerts AS $alert)
		{
			try
			{
				$items[] = $this->serializeAlert($alert);
			}
			catch (\Throwable $e)
			{
				\XF::logException($e, false, 'IosApi serializeAlert: ');
			}
		}

		return $this->apiResult([
			'items' => $items,
			'notifications' => $items,
			'counts' => [
				'unread' => (int) $visitor->alerts_unread,
				'unviewed' => (int) $visitor->alerts_unviewed,
				'conversations_unread' => (int) $visitor->conversations_unread,
				'conversationsUnread' => (int) $visitor->conversations_unread,
			],
			'current_page' => $page,
			'last_page' => $perPage > 0 ? (int) ceil($total / $perPage) : 1,
			'total' => $total,
			'pagination' => $this->paginationMeta($page, $perPage, $total),
		]);
	}

	public function actionMarkAll()
	{
		$this->assertMobileWriteScope();
		$visitor = $this->assertRegisteredApiUser();

		if ($this->filter('viewed', 'bool'))
		{
			$this->getAlertRepo()->markUserAlertsViewed($visitor);
		}
		else
		{
			$this->getAlertRepo()->markUserAlertsRead($visitor);
		}

		return $this->apiResult(NotificationCounts::forUser((int) $visitor->user_id));
	}

	protected function serializeAlert(UserAlert $alert): array
	{
		$output = null;
		if ($alert->getHandler())
		{
			try
			{
				$handlerOutput = $alert->getHandler()->getApiOutput($alert);
				$output = is_array($handlerOutput) ? $handlerOutput : null;
			}
			catch (\Throwable $e)
			{
				$output = null;
			}
		}

		$text = trim((string) ($output['text'] ?? ''));
		$url = trim((string) ($output['url'] ?? ''));
		if ($text === '')
		{
			$text = $this->fallbackAlertText($alert);
		}

		try
		{
			$user = $alert->User;
		}
		catch (\Throwable $e)
		{
			$user = null;
		}

		try
		{
			$appRoute = AlertAppRoute::fromAlert($alert, $url);
		}
		catch (\Throwable $e)
		{
			\XF::logException($e, false, 'IosApi appRouteFromAlert: ');
			$appRoute = AlertAppRoute::fromUrl($url);
		}

		return [
			'id' => (string) $alert->alert_id,
			'alert_id' => (int) $alert->alert_id,
			'type' => (string) $alert->content_type,
			'content_type' => (string) $alert->content_type,
			'content_id' => (int) $alert->content_id,
			'action' => (string) $alert->action,
			'title' => $this->titleFromAlert($alert),
			'message' => $text,
			'actor_user_id' => (int) $alert->user_id,
			'actorUserId' => (int) $alert->user_id,
			'actor_username' => (string) ($user ? $user->username : $alert->username),
			'avatar_url' => $user ? (string) $user->getAvatarUrl('m', null, true) : '',
			'target_url' => $url,
			'app_route' => $appRoute,
			'event_date' => (int) $alert->event_date,
			'view_date' => (int) $alert->view_date,
			'read_date' => (int) $alert->read_date,
			'is_viewed' => (bool) $alert->view_date,
			'is_read' => (bool) $alert->read_date,
			'priority' => 'normal',
			'extra' => is_array($alert->extra_data) ? $alert->extra_data : [],
		];
	}

	protected function titleFromAlert(UserAlert $alert): string
	{
		$type = (string) $alert->content_type;
		$action = (string) $alert->action;

		if ($action === 'book_request_new')
		{
			return 'Yeni kitap isteği';
		}
		if ($action === 'profile_visit' || $action === 'profile_view' || $action === 'visit')
		{
			return 'Profil ziyareti';
		}
		if ($action === 'reading_goal')
		{
			return 'Okuma hedefi';
		}
		if ($action === 'following' || $action === 'follow')
		{
			return 'Yeni takip';
		}
		if ($action === 'mention')
		{
			return 'Etiketleme';
		}

		switch ($type)
		{
			case 'post':
			case 'forum_post':
				return 'Yeni yanıt';
			case 'thread':
				return 'Konu bildirimi';
			case 'user':
				return 'Üye bildirimi';
			case 'profile_post':
				return 'Profil mesajı';
			case 'profile_post_comment':
				return 'Profil cevabı';
			case 'conversation':
			case 'conversation_message':
				return 'Yeni özel mesaj';
			case 'trophy':
				return 'Yeni başarı';
			case 'ek_social_post':
			case 'ek_social_comment':
			case 'ek_social_follow':
			case 'social_post':
				return 'Kitap Gündemi';
			case 'ek_reading_invitation':
				return 'Ortak okuma';
			case 'siropu_chat_room_message':
			case 'siropu_chat_conv_message':
			case 'chat_message':
				return 'Yeni mesaj';
			default:
				return 'Bildirim';
		}
	}

	protected function fallbackAlertText(UserAlert $alert): string
	{
		$type = (string) $alert->content_type;
		$action = (string) $alert->action;
		$actor = trim((string) ($alert->username ?: ''));
		if ($actor === '')
		{
			try
			{
				$actor = trim((string) ($alert->User->username ?? ''));
			}
			catch (\Throwable $e)
			{
				$actor = '';
			}
		}
		$actor = $actor !== '' ? $actor : 'Bir üye';

		if ($action === 'book_request_new')
		{
			$extra = is_array($alert->extra_data) ? $alert->extra_data : [];
			$title = trim((string) ($extra['book_title'] ?? ''));
			$author = trim((string) ($extra['book_author'] ?? ''));
			if ($title === '')
			{
				return 'Yeni bir kitap isteği oluşturuldu.';
			}

			return $author !== ''
				? "Yeni kitap isteği: {$title} — {$author}"
				: "Yeni kitap isteği: {$title}";
		}
		if ($type === 'user' && ($action === 'profile_visit' || $action === 'profile_view' || $action === 'visit'))
		{
			return $actor . ' profilinizi ziyaret etti.';
		}
		if ($type === 'user' && $action === 'reading_goal')
		{
			$extra = is_array($alert->extra_data) ? $alert->extra_data : [];
			return 'Okuma hedefinizde %' . (int) ($extra['milestone'] ?? 0) . ' seviyesine ulaştınız.';
		}
		if ($action === 'following' || $action === 'follow')
		{
			return $actor . ' sizi takip etmeye başladı.';
		}

		try
		{
			$rendered = (string) $alert->render();
			$preview = preg_replace('/<[^>]+>/', ' ', $rendered);
			$plain = html_entity_decode(strip_tags((string) $preview), ENT_QUOTES | ENT_HTML5, 'UTF-8');
			$plain = trim((string) preg_replace('/\s+/u', ' ', $plain));
			if ($plain !== '')
			{
				return $plain;
			}
		}
		catch (\Throwable $e)
		{
		}

		return $actor . ' hesabınızla ilgili yeni bir etkinlik oluşturdu.';
	}

	protected function getAlertRepo(): UserAlertRepository
	{
		return $this->repository(UserAlertRepository::class);
	}
}
