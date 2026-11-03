<?php

namespace Ekitapligim\IosApi\Pub\View;

class AgendaImage extends \XF\Pub\View\Attachment\View
{
	public function renderRaw()
	{
		$stream = parent::renderRaw();
		$this->response->header('Cache-Control', 'private, no-store')
			->header('Vary', 'Authorization')->header('X-Content-Type-Options', 'nosniff');
		return $stream;
	}
}
