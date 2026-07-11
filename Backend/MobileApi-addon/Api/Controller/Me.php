<?php

namespace Ekitapligim\MobileApi\Api\Controller;

use Ekitapligim\MobileApi\Service\MobileSession;
use XF\Service\User\EmailChangeService;
use XF\Service\User\PasswordChangeService;

class Me extends AbstractMobileController
{
	public function actionGet()
	{
		$this->assertMobileScope('user:read');
		$visitor = $this->assertRegisteredApiUser();
		$title = $visitor->custom_title !== ''
			? (string) $visitor->custom_title
			: (string) $this->app()->templater()->getDefaultUserTitleForUser($visitor);

		$profile = $visitor->getRelationOrDefault('Profile');

		return $this->apiResult([
			'id' => (string) $visitor->user_id,
			'user_id' => (int) $visitor->user_id,
			'userId' => (int) $visitor->user_id,
			'username' => (string) $visitor->username,
			'email' => (string) $visitor->email,
			'title' => $title,
			'avatar_url' => (string) $visitor->getAvatarUrl('m', null, true),
			'avatarUrl' => (string) $visitor->getAvatarUrl('m', null, true),
			'message_count' => (int) $visitor->message_count,
			'messageCount' => (int) $visitor->message_count,
			'reaction_score' => (int) $visitor->reaction_score,
			'reactionScore' => (int) $visitor->reaction_score,
			'register_date' => (int) $visitor->register_date,
			'registerDate' => (int) $visitor->register_date,
			'is_staff' => (bool) ($visitor->is_staff || $visitor->is_admin || $visitor->is_moderator),
			'isStaff' => (bool) ($visitor->is_staff || $visitor->is_admin || $visitor->is_moderator),
			'can_edit' => (bool) $visitor->canEditProfile(),
			'canEdit' => (bool) $visitor->canEditProfile(),
			'about' => (string) $profile->about,
			'location' => (string) $profile->location,
			'website' => (string) $profile->website,
			'activity_visible' => (bool) $visitor->activity_visible,
			'activityVisible' => (bool) $visitor->activity_visible,
			'role' => $this->mobileUserRolePayload($visitor),
		]);
	}

	public function actionPost()
	{
		$this->assertMobileWriteScope();
		$visitor = $this->assertRegisteredApiUser();
		if (!$visitor->canEditProfile())
		{
			return $this->apiError('You cannot edit this profile.', 'profile_edit_denied', null, 403);
		}

		$about = trim((string) $this->filter('about', 'str'));
		$location = trim((string) $this->filter('location', 'str'));
		$website = trim((string) $this->filter('website', 'str'));
		$activityVisible = (bool) $this->filter('activity_visible', 'bool');

		if (mb_strlen($about) > 5000 || mb_strlen($location) > 100 || mb_strlen($website) > 200)
		{
			return $this->apiError('Profile fields are too long.', 'profile_input_too_long', null, 400);
		}
		if ($website !== '' && (!filter_var($website, FILTER_VALIDATE_URL) || !in_array(strtolower((string) parse_url($website, PHP_URL_SCHEME)), ['http', 'https'], true)))
		{
			return $this->apiError('Website must be a valid HTTP or HTTPS URL.', 'profile_website_invalid', null, 400);
		}

		if ($about !== '' && $visitor->isSpamCheckRequired())
		{
			$checker = $this->app()->spam()->contentChecker();
			$checker->check($visitor, $about, ['content_type' => 'user', 'content_id' => (int) $visitor->user_id]);
			if (in_array($checker->getFinalDecision(), ['moderated', 'denied'], true))
			{
				$checker->logSpamTrigger('user_about', (int) $visitor->user_id);
				return $this->apiError('Profile content could not be submitted.', 'profile_spam_rejected', null, 400);
			}
		}

		$profile = $visitor->getRelationOrDefault('Profile');
		$profile->bulkSet([
			'about' => $about,
			'location' => $location,
			'website' => $website,
		]);
		$visitor->activity_visible = $activityVisible;

		$errors = array_merge($profile->getErrors(), $visitor->getErrors());
		if ($errors)
		{
			return $this->apiError(implode(' ', array_map('strval', $errors)), 'profile_validation_failed', null, 400);
		}

		$profile->save();
		$visitor->save();

		return $this->actionGet();
	}

	public function actionEmail()
	{
		$this->assertMobileWriteScope();
		$visitor = $this->assertRegisteredApiUser();
		$currentPassword = (string) $this->filter('current_password', 'str');
		$email = trim((string) $this->filter('email', 'str'));

		if ($currentPassword === '' || $email === '')
		{
			return $this->apiError('Current password and email are required.', 'identity_fields_required', null, 400);
		}
		if (!$visitor->Auth || !$visitor->Auth->getAuthenticationHandler() || !$visitor->authenticate($currentPassword))
		{
			return $this->apiError('Current password is not valid.', 'current_password_invalid', null, 403);
		}

		/** @var EmailChangeService $emailChange */
		$emailChange = $this->service(EmailChangeService::class, $visitor, $email);
		if (!$emailChange->isValid($error))
		{
			return $this->apiError((string) $error, 'email_validation_failed', null, 400);
		}
		if (!$emailChange->canChangeEmail($error))
		{
			return $this->apiError((string) ($error ?: 'Email may not be changed at this time.'), 'email_change_denied', null, 403);
		}

		$emailChange->save();

		return $this->apiResult([
			'success' => true,
			'email' => (string) $visitor->email,
			'confirmation_required' => (bool) $emailChange->getConfirmationRequired(),
			'confirmationRequired' => (bool) $emailChange->getConfirmationRequired(),
		]);
	}

	public function actionPassword()
	{
		$this->assertMobileWriteScope();
		$visitor = $this->assertRegisteredApiUser();
		$currentPassword = (string) $this->filter('current_password', 'str');
		$newPassword = (string) $this->filter('new_password', 'str');

		if ($currentPassword === '' || $newPassword === '')
		{
			return $this->apiError('Current and new passwords are required.', 'identity_fields_required', null, 400);
		}
		if (!$visitor->Auth || !$visitor->Auth->getAuthenticationHandler() || !$visitor->authenticate($currentPassword))
		{
			return $this->apiError('Current password is not valid.', 'current_password_invalid', null, 403);
		}

		/** @var PasswordChangeService $passwordChange */
		$passwordChange = $this->service(PasswordChangeService::class, $visitor, $newPassword);
		if (!$passwordChange->isValid($error))
		{
			return $this->apiError((string) $error, 'password_validation_failed', null, 400);
		}
		$passwordChange->save();

		MobileSession::revokeUserSessions((int) $visitor->user_id);
		$tokens = MobileSession::issue(
			$visitor,
			$this->request->getIp(),
			(string) $this->request->getServer('HTTP_USER_AGENT', '')
		);

		return $this->apiResult($this->buildMobileAuthPayload($visitor, $tokens));
	}
}
