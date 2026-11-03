<?php

namespace Ekitapligim\IosApi\Service;

/** Adds image metadata without changing the shared Android serializer or feed ordering. */
class AgendaMediaSerializer extends \Ekitapligim\MobileApi\Service\BookAgendaSerializer
{
	public function decorateReply($reply)
	{
		if (!is_object($reply) || !method_exists($reply, 'getApiResult')) return $reply;
		$result = $reply->getApiResult();
		if (!is_object($result) || !method_exists($result, 'getResult') || !method_exists($result, 'setResult')) return $reply;
		$payload = $result->getResult();
		$items = $payload['items'] ?? (isset($payload['post']) ? [$payload['post']] : []);
		$ids = array_values(array_filter(array_map(static fn($item) => (int) ($item['id'] ?? 0), $items)));
		if (!$ids) return $reply;
		// XF cannot join TO_MANY relations. Its attachment repository hydrates the batch separately.
		$posts = \XF::em()->findByIds('Ekitapligim\Social:Post', $ids);
		\XF::repository('XF:Attachment')->addAttachmentsToContent($posts, 'ek_social_post');
		$decorate = function (array $item) use ($posts): array {
			$post = $posts[(int) ($item['id'] ?? 0)] ?? null;
			return $post && $post->canView() ? $this->withMedia($post, $item) : $item;
		};
		if (isset($payload['items'])) $payload['items'] = array_map($decorate, $payload['items']);
		if (isset($payload['post'])) $payload['post'] = $decorate($payload['post']);
		$result->setResult($payload);
		return $reply;
	}

	public function withMedia($post, array $payload): array
	{
		$images = [];
		foreach ($post->Attachments ?? [] as $attachment)
		{
			if (!$attachment->Data || !$attachment->width || !$attachment->height) continue;
			$images[] = [
				'id' => (string) $attachment->attachment_id,
				'url' => $this->absolute($attachment->getDirectUrl()),
				'thumbnail_url' => $this->absolute((string) $attachment->getThumbnailUrl()),
				'width' => (int) $attachment->width, 'height' => (int) $attachment->height,
				'protected_image' => true,
			];
		}
		// Existing web posts may embed a remote image instead of uploading an attachment.
		preg_match_all('/\[IMG(?:=[^\]]*)?\](.*?)\[\/IMG\]/is', (string) $post->message, $matches);
		$seen = [];
		foreach ($matches[1] as $url)
		{
			$url = trim(html_entity_decode($url, ENT_QUOTES | ENT_HTML5, 'UTF-8'));
			$parts = parse_url($url);
			if (!$parts || strtolower($parts['scheme'] ?? '') !== 'https' || empty($parts['host'])
				|| isset($parts['user']) || isset($parts['pass']) || isset($seen[$url])) continue;
			$seen[$url] = true;
			$images[] = ['id' => 'inline-' . substr(hash('sha256', $url), 0, 20), 'url' => $url, 'thumbnail_url' => null,
				'width' => 0, 'height' => 0, 'protected_image' => false];
			if (count($images) >= 10) break;
		}
		$payload['attachments'] = $images;
		$message = preg_replace('/\[(IMG|ATTACH)(?:[^\]]*)\].*?\[\/\1\]/is', '', (string) $post->message);
		$payload['message'] = $this->plainText($message ?? (string) $post->message);
		return $payload;
	}
}
