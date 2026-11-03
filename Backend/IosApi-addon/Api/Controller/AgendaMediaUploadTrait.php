<?php

namespace Ekitapligim\IosApi\Api\Controller;

use Ekitapligim\IosApi\Service\AgendaMediaSerializer;

trait AgendaMediaUploadTrait
{
	protected function mediaCapabilities()
	{
		$this->assertMobileScope();
		$visitor = \XF::visitor();
		$handler = $this->repository('XF:Attachment')->getAttachmentHandler('ek_social_post');
		$context = ['user_id' => (int) $visitor->user_id];
		$constraints = $handler ? $handler->getConstraints($context) : [];
		$maxBytes = min(8388608, !empty($constraints['size']) ? (int) $constraints['size'] : 8388608);
		$canUpload = $visitor->user_id && $visitor->hasPermission('ekSocial', 'view')
			&& $visitor->hasPermission('ekSocial', 'create') && $visitor->hasPermission('ekSocial', 'upload')
			&& $handler && $handler->canManageAttachments($context)
			&& in_array('jpg', $constraints['extensions'] ?? [], true);
		return $this->apiResult(['image_upload_version' => 1, 'can_upload_images' => (bool) $canUpload, 'maximum_bytes' => $maxBytes]);
	}

	protected function createPostWithImage()
	{
		$this->assertMobileWriteScope();
		$visitor = $this->assertRegisteredApiUser();
		if (!$visitor->hasPermission('ekSocial', 'view') || !$visitor->hasPermission('ekSocial', 'create')
			|| !$visitor->hasPermission('ekSocial', 'upload'))
			return $this->apiError('You cannot upload agenda images.', 'no_permission', null, 403);
		$this->assertPostFlooding($visitor);
		$repo = $this->repository('XF:Attachment');
		$handler = $repo->getAttachmentHandler('ek_social_post');
		$context = ['user_id' => (int) $visitor->user_id];
		if (!$handler || !$handler->canManageAttachments($context))
			return $this->apiError('You cannot upload agenda images.', 'no_permission', null, 403);
		$upload = $this->request->getFile('image', false, false);
		if (!$upload || !$upload->isImage() || $upload->getImageType() !== IMAGETYPE_JPEG
			|| $upload->getFileSize() <= 0 || $upload->getFileSize() > 8388608)
			return $this->apiError('Choose a JPEG image smaller than 8 MB.', 'invalid_image', null, 422);

		$data = [
			'post_type' => strtolower(trim($this->filter('post_type', 'str') ?: 'standard')),
			'visibility' => strtolower(trim($this->filter('visibility', 'str') ?: 'public')),
			'book_thread_id' => (int) $this->filter('book_thread_id', 'uint'),
			'author_id' => (int) $this->filter('author_id', 'uint'),
			'quote_post_id' => (int) $this->filter('quote_post_id', 'uint'), 'club_id' => 0,
			'review_title' => trim($this->filter('review_title', 'str')),
			'rating' => min(5, (int) $this->filter('rating', 'uint')),
			'page_number' => trim($this->filter('page_number', 'str')),
			'progress_current' => (int) $this->filter('progress_current', 'uint'),
			'progress_total' => (int) $this->filter('progress_total', 'uint'),
		];
		if (!in_array($data['post_type'], ['standard', 'book', 'quotation', 'review', 'progress', 'quote'], true)) $data['post_type'] = 'standard';
		if (!in_array($data['visibility'], ['public', 'members', 'followers', 'private'], true)) $data['visibility'] = 'public';
		if ($data['book_thread_id'])
		{
			$book = $this->assertBook($data['book_thread_id']);
			if (!$data['author_id']) $data['author_id'] = (int) $book->author_canonical_id;
		}
		if (in_array($data['post_type'], ['book', 'quotation', 'review', 'progress'], true) && !$data['book_thread_id'])
			return $this->apiError('A book is required for this post type.', 'book_required', null, 422);
		if ($data['quote_post_id'])
		{
			if (!$this->repository('Ekitapligim\Social:Feed')->getPost($data['quote_post_id']))
				return $this->apiError('Quoted post not found.', 'post_not_found', null, 404);
			$data['post_type'] = 'quote';
		}
		// The server owns the temporary hash. Clients cannot associate another user's pending files.
		$hash = bin2hex(random_bytes(16));
		$class = \XF::extendClass(\XF\Attachment\Manipulator::class);
		$manipulator = new $class($handler, $repo, $context, $hash);
		if (!$manipulator->canUpload($error)) return $this->apiError((string) $error, 'upload_denied', null, 422);
		$creator = $this->service(\Ekitapligim\Social\Service\Post\Creator::class);
		$creator->setMessage(trim($this->filter('message', 'str')));
		$creator->setData($data);
		$creator->setAttachmentHash($hash);
		if (!$creator->validate($errors)) return $this->apiError(implode(' ', $errors), 'validation_error', null, 422);
		$attachment = $manipulator->insertAttachmentFromUpload($upload, $error);
		if (!$attachment) return $this->apiError((string) $error, 'upload_failed', null, 422);
		$saved = false;
		try
		{
			$post = $creator->save(); // Social's transaction associates the image before committing the post.
			$saved = true;
		}
		finally
		{
			// Manipulator does not add freshly inserted files to its deletion map in XF 2.3.
			if (!$saved) $attachment->delete();
		}
		$repo->addAttachmentsToContent([$post], 'ek_social_post');
		$serializer = new AgendaMediaSerializer();
		$payload = $serializer->post($post, $serializer->viewerState([(int) $post->post_id], [(int) $post->user_id]));
		return $this->apiResult(['success' => true, 'post' => $serializer->withMedia($post, $payload)]);
	}
}
