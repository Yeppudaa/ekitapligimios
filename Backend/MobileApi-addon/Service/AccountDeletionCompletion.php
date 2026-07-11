<?php

namespace Ekitapligim\MobileApi\Service;

use XF\Entity\User;
use XF\Service\User\DeleteService;

final class AccountDeletionCompletion
{
	public static function inspect(int $requestId): ?array
	{
		return \XF::db()->fetchRow(
			'SELECT request_id, user_id, username, email, reason, request_state, requested_at, updated_at
			 FROM xf_ekitapligim_mobile_account_deletion_request WHERE request_id = ?',
			[$requestId]
		) ?: null;
	}

	public static function complete(int $requestId): array
	{
		$db = \XF::db();
		$db->beginTransaction();
		try
		{
			$request = $db->fetchRow(
				'SELECT * FROM xf_ekitapligim_mobile_account_deletion_request WHERE request_id = ? FOR UPDATE',
				[$requestId]
			);
			if (!$request)
			{
				throw new \RuntimeException('Deletion request was not found.');
			}
			if ($request['request_state'] === 'completed')
			{
				$db->commit();
				return ['already_completed' => true, 'notice_sent' => true];
			}
			if (!in_array($request['request_state'], ['pending', 'processing'], true))
			{
				throw new \RuntimeException('Deletion request is not actionable.');
			}

			$userId = (int) $request['user_id'];
			/** @var User|null $user */
			$user = \XF::em()->find('XF:User', $userId);
			if (!$user)
			{
				throw new \RuntimeException('Requested user no longer exists.');
			}
			if (AppleAuthorization::hasAuthorization($userId)
				&& !AppleAuthorization::revokeForUser($userId))
			{
				throw new \RuntimeException('Apple authorization revocation failed.');
			}

			$db->update('xf_ekitapligim_mobile_account_deletion_request', [
				'request_state' => 'processing',
				'updated_at' => \XF::$time,
			], 'request_id = ?', [$requestId]);

			/** @var DeleteService $deleteService */
			$deleteService = \XF::service(DeleteService::class, $user);
			$deleteService->renameTo('Deleted member ' . $requestId);
			if (!$deleteService->delete($errors))
			{
				throw new \RuntimeException('XenForo user deletion failed: ' . implode('; ', array_map('strval', $errors ?: [])));
			}

			MobileSession::revokeUserSessions($userId);
			$db->delete('xf_ekitapligim_mobile_apple_authorization', 'user_id = ?', [$userId]);
			$db->update('xf_ekitapligim_mobile_account_deletion_request', [
				'username' => '',
				'email' => '',
				'reason' => null,
				'password_verified' => 0,
				'request_state' => 'completed',
				'updated_at' => \XF::$time,
			], 'request_id = ?', [$requestId]);
			$db->commit();

			return [
				'already_completed' => false,
				'user_id' => $userId,
				'email' => (string) $request['email'],
			];
		}
		catch (\Throwable $e)
		{
			$db->rollback();
			throw $e;
		}
	}

	public static function sendCompletionNotice(string $email, int $requestId): bool
	{
		if ($email === '')
		{
			return false;
		}
		try
		{
			$mail = \XF::app()->mailer()->newMail();
			$mail->setTo($email);
			$mail->setContent(
				'Ekitapligim hesap silme işlemi tamamlandı',
				'',
				"Hesabınız ve ilişkili kişisel verileriniz silindi veya anonimleştirildi.\n\nTalep ID: " . $requestId
			);
			return (bool) $mail->send();
		}
		catch (\Throwable $e)
		{
			\XF::logException($e, false, 'Mobile account deletion completion mail failed: ');
			return false;
		}
	}
}
