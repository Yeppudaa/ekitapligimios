<?php

namespace Ekitapligim\MobileApi\Api\Controller;

use Ekitapligim\MobileApi\Service\AppleAuthorization;
use Ekitapligim\MobileApi\Service\MobileSession;

class AccountDeletionRequest extends AbstractMobileController
{
	public function actionPost()
	{
		$this->assertMobileWriteScope();
		$visitor = $this->assertRegisteredApiUser();

		$currentPassword = (string) $this->filter('current_password', 'str');
		$reason = trim((string) $this->filter('reason', 'str'));
		$hasAppleAuthorization = AppleAuthorization::hasAuthorization((int) $visitor->user_id);
		$authHandler = $visitor->Auth ? $visitor->Auth->getAuthenticationHandler() : null;
		$hasPassword = $authHandler && $authHandler->hasPassword();

		if (!$hasAppleAuthorization && $hasPassword && $currentPassword === '')
		{
			return $this->apiError('Current password is required.', 'current_password_required', null, 400);
		}
		if ($currentPassword !== '' && !$visitor->authenticate($currentPassword))
		{
			return $this->apiError('Current password is not valid.', 'current_password_invalid', null, 403);
		}
		$this->ensureDeletionRequestTable();
		$existingRequestId = $this->findPendingRequestId((int) $visitor->user_id);
		if ($existingRequestId > 0)
		{
			return $this->deletionRequestResult(
				$existingRequestId,
				true,
				AppleAuthorization::hasAuthorization((int) $visitor->user_id)
			);
		}

		$requestId = $this->recordDeletionRequest($visitor, $reason, $currentPassword !== '');
		MobileSession::revokeUserSessions((int) $visitor->user_id);
		$appleRevocationPending = $hasAppleAuthorization
			&& !AppleAuthorization::revokeForUser((int) $visitor->user_id);
		$this->sendDeletionRequestMail($visitor, $reason, $requestId);

		return $this->deletionRequestResult($requestId, false, $appleRevocationPending);
	}

	protected function deletionRequestResult(int $requestId, bool $alreadyPending, bool $appleRevocationPending)
	{
		return $this->apiResult([
			'success' => true,
			'request_id' => $requestId,
			'requestId' => $requestId,
			'already_pending' => $alreadyPending,
			'alreadyPending' => $alreadyPending,
			'apple_revocation_pending' => $appleRevocationPending,
			'appleRevocationPending' => $appleRevocationPending,
			'estimated_completion_days' => 30,
			'estimatedCompletionDays' => 30,
			'message' => 'Hesap silme talebiniz alındı ve genellikle 30 gün içinde tamamlanır.'
		]);
	}

	protected function findPendingRequestId(int $userId): int
	{
		return (int) \XF::db()->fetchOne(
			"SELECT request_id FROM xf_ekitapligim_mobile_account_deletion_request
			 WHERE user_id = ? AND request_state IN ('pending', 'processing')
			 ORDER BY request_id DESC LIMIT 1",
			[$userId]
		);
	}

	protected function recordDeletionRequest(\XF\Entity\User $user, string $reason, bool $passwordVerified): int
	{
		$this->ensureDeletionRequestTable();
		\XF::db()->query(
			"INSERT INTO xf_ekitapligim_mobile_account_deletion_request
				(user_id, username, email, reason, password_verified, request_state, requested_at)
			VALUES (?, ?, ?, ?, ?, 'pending', ?)",
			[
				(int) $user->user_id,
				(string) $user->username,
				(string) $user->email,
				$reason,
				$passwordVerified ? 1 : 0,
				\XF::$time
			]
		);

		return (int) \XF::db()->lastInsertId();
	}

	protected function ensureDeletionRequestTable(): void
	{
		\XF::db()->query("
			CREATE TABLE IF NOT EXISTS xf_ekitapligim_mobile_account_deletion_request (
				request_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
				user_id INT UNSIGNED NOT NULL,
				username VARBINARY(100) NOT NULL DEFAULT '',
				email VARBINARY(120) NOT NULL DEFAULT '',
				reason MEDIUMTEXT NULL,
				password_verified TINYINT UNSIGNED NOT NULL DEFAULT 0,
				request_state ENUM('pending','processing','completed','rejected') NOT NULL DEFAULT 'pending',
				requested_at INT UNSIGNED NOT NULL DEFAULT 0,
				updated_at INT UNSIGNED NOT NULL DEFAULT 0,
				PRIMARY KEY (request_id),
				KEY user_state (user_id, request_state),
				KEY requested_at (requested_at)
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
		");
	}

	protected function sendDeletionRequestMail(\XF\Entity\User $user, string $reason, int $requestId): void
	{
		$contactEmail = trim((string) \XF::options()->contactEmailAddress);
		if ($contactEmail === '')
		{
			\XF::logError('Mobile account deletion request stored without contact email. Request ID: ' . $requestId);
			return;
		}

		$body = sprintf(
			"Mobil uygulama üzerinden hesap silme talebi gönderildi.\n\nTalep ID: %d\nKullanıcı: %s\nUser ID: %d\nE-posta: %s\nTarih: %s\nNeden: %s\n\nLütfen talebi XenForo yönetim panelinden kontrol ederek işleme alın.",
			$requestId,
			$user->username,
			(int) $user->user_id,
			(string) $user->email,
			gmdate('Y-m-d H:i:s') . ' UTC',
			$reason !== '' ? $reason : '-'
		);

		try
		{
			$mail = \XF::app()->mailer()->newMail();
			$mail->setTo($contactEmail);
			$mail->setContent('Mobil uygulama hesap silme talebi', '', $body);
			$mail->send();
		}
		catch (\Throwable $e)
		{
			\XF::logException($e, false, 'Mobile account deletion request mail failed: ');
		}
	}
}
