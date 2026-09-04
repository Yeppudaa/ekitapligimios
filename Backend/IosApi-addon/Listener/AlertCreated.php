<?php

namespace Ekitapligim\IosApi\Listener;

use Ekitapligim\IosApi\Service\AlertAppRoute;
use Ekitapligim\IosApi\Service\ApnsPush;
use XF\Entity\UserAlert;

/**
 * Listens for newly persisted XenForo UserAlert entities and queues APNs delivery.
 */
class AlertCreated
{
	public static function onUserAlert(UserAlert $alert): void
	{
		if (!$alert->isInsert() || !$alert->alert_id)
		{
			return;
		}

		\XF::app()->jobManager()->enqueueUnique(
			'ekitapligimIosApnsAlert' . (int) $alert->alert_id,
			'Ekitapligim\IosApi:SendAlertPush',
			['alert_id' => (int) $alert->alert_id],
			false
		);
	}

	public static function deliver(UserAlert $alert): array
	{
		try
		{
			$userId = (int) $alert->alerted_user_id;
			if ($userId <= 0)
			{
				return ['attempted' => 0, 'sent' => 0, 'failed' => 0, 'removed' => 0];
			}

			$title = self::titleFromAlert($alert);
			$body = self::bodyFromAlert($alert);

			$appRoute = null;
			try
			{
				$handlerOutput = null;
				if ($alert->getHandler())
				{
					$handlerOutput = $alert->getHandler()->getApiOutput($alert);
				}
				$url = is_array($handlerOutput) ? trim((string) ($handlerOutput['url'] ?? '')) : '';
				$appRoute = AlertAppRoute::fromAlert($alert, $url);
			}
			catch (\Throwable $e)
			{
				$appRoute = null;
			}

			$badge = self::unreadCount($userId);

			$customData = [
				'type' => (string) $alert->content_type,
				'action' => (string) $alert->action,
				'content_id' => (int) $alert->content_id,
				'actor_user_id' => (int) $alert->user_id,
			];

			if (is_array($appRoute))
			{
				$customData['route'] = $appRoute['native_route'] ?? ($appRoute['nativeRoute'] ?? null);
				$customData['target_url'] = $appRoute['target_url'] ?? ($appRoute['targetUrl'] ?? null);
			}
			elseif (is_string($appRoute))
			{
				$customData['route'] = $appRoute;
			}

			$payload = ApnsPush::buildPayload($title, $body, $badge, $customData);
			return ApnsPush::sendToUser($userId, $payload);
		}
		catch (\Throwable $e)
		{
			\XF::logException($e, false, 'IosApi push notification: ');
			return ['attempted' => 0, 'sent' => 0, 'failed' => 1, 'removed' => 0];
		}
	}

	private static function unreadCount(int $userId): int
	{
		try
		{
			$user = \XF::em()->find('XF:User', $userId);
			return $user ? (int) $user->alerts_unread : 0;
		}
		catch (\Throwable $e)
		{
			return 0;
		}
	}

	private static function titleFromAlert(UserAlert $alert): string
	{
		$action = (string) $alert->action;
		$type = (string) $alert->content_type;

		if ($action === 'book_request_new') { return 'Yeni kitap isteği'; }
		if ($action === 'profile_visit' || $action === 'profile_view' || $action === 'visit') { return 'Profil ziyareti'; }
		if ($action === 'reading_goal') { return 'Okuma hedefi'; }
		if ($action === 'following' || $action === 'follow') { return 'Yeni takip'; }
		if ($action === 'mention') { return 'Etiketleme'; }

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

	private static function bodyFromAlert(UserAlert $alert): string
	{
		$action = (string) $alert->action;
		$type = (string) $alert->content_type;

		$actor = '';
		try
		{
			$user = $alert->User;
			$actor = $user ? (string) $user->username : (string) $alert->username;
		}
		catch (\Throwable $e)
		{
			$actor = (string) $alert->username;
		}
		$actor = $actor !== '' ? $actor : 'Bir üye';

		if ($action === 'book_request_new')
		{
			$extra = is_array($alert->extra_data) ? $alert->extra_data : [];
			$title = trim((string) ($extra['book_title'] ?? ''));
			return $title !== '' ? "Yeni kitap isteği: {$title}" : 'Yeni bir kitap isteği oluşturuldu.';
		}
		if (($action === 'profile_visit' || $action === 'profile_view' || $action === 'visit'))
		{
			return $actor . ' profilinizi ziyaret etti.';
		}
		if ($action === 'following' || $action === 'follow')
		{
			return $actor . ' sizi takip etmeye başladı.';
		}

		try
		{
			$rendered = (string) $alert->render();
			$plain = trim((string) preg_replace('/\s+/u', ' ', strip_tags(html_entity_decode((string) preg_replace('/<[^>]+>/', ' ', $rendered), ENT_QUOTES | ENT_HTML5, 'UTF-8'))));
			if ($plain !== '')
			{
				return mb_strlen($plain) > 200 ? mb_substr($plain, 0, 197) . '...' : $plain;
			}
		}
		catch (\Throwable $e)
		{
		}

		return $actor . ' hesabınızla ilgili yeni bir etkinlik oluşturdu.';
	}
}
