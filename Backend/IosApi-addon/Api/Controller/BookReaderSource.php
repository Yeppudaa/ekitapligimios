<?php

namespace Ekitapligim\IosApi\Api\Controller;

class BookReaderSource extends \Ekitapligim\MobileApi\Api\Controller\BookReaderSource
{
	protected function serveDriveSource(\XenCustomize\BookThreads\Entity\Book $book, string $url)
	{
		// Older MobileApi versions log invalid source data as an unexpected exception.
		// Validate here before delegating; keep the parent's access and preview pipeline.
		$url = \XenCustomize\BookThreads\Service\Book\ExternalEbook::validateAndNormalizeUrl($url);
		if (!$url)
		{
			return $this->apiError('Drive ebook unavailable.', 'ebook_unavailable');
		}

		return parent::serveDriveSource($book, $url);
	}

	protected function deliverReaderContents(string $fileName, string $mimeType, string $contents)
	{
		if ($contents === '')
		{
			return $this->apiError('Ebook file empty.', 'ebook_unavailable');
		}

		if ($this->filter('format', 'str') === 'json' || strtolower((string) $this->request->getServer('HTTP_ACCEPT')) === 'application/json')
		{
			return parent::deliverReaderContents($fileName, $mimeType, $contents);
		}

		$this->setResponseType('raw');
		return $this->view('Ekitapligim\IosApi:Reader\Source', '', [
			'contents' => $contents,
			'fileName' => $fileName,
			'mimeType' => $mimeType,
			'readerMetadata' => $this->readerMetadata,
		]);
	}
}
