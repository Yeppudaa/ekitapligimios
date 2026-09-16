<?php

namespace Ekitapligim\IosApi\Api\Controller;

use Ekitapligim\IosApi\Service\ReaderProgress;
use XF\Mvc\ParameterBag;

class BookReaderProgress extends \Ekitapligim\MobileApi\Api\Controller\AbstractMobileController
{
    public function actionGet(ParameterBag $params)
    {
        $this->assertMobileScope();
        $visitor = $this->assertRegisteredApiUser();
        $book = $this->assertBook((int) $params->thread_id);
        try { return $this->apiResult((new ReaderProgress())->get((int) $visitor->user_id, (int) $book->thread_id)); }
        catch (\Throwable $e) { return $this->apiError('Reading progress unavailable.', 'reader_progress_unavailable', null, 503); }
    }

    public function actionPost(ParameterBag $params)
    {
        $this->assertMobileWriteScope();
        $visitor = $this->assertRegisteredApiUser();
        $book = $this->assertBook((int) $params->thread_id);
        $type = $this->filter('position_type', 'str');
        $revision = $this->filter('base_revision', 'str');
        // A pending write must not follow a token refresh/account switch into another user's library.
        if ($revision !== '' && !hash_equals((string) $visitor->username, $this->filter('account_name', 'str')))
        {
            return $this->apiError('Reader account changed.', 'reader_account_changed', null, 409);
        }
        // Compatibility with previously shipped iOS PDF requests.
        if ($type === 'page') { $type = 'pdf'; }
        try
        {
            return $this->apiResult((new ReaderProgress())->save((int) $visitor->user_id, (int) $book->thread_id,
                $type, trim($this->filter('position_value', 'str')), (float) $this->filter('progress_percent', 'float'),
                $revision));
        }
        catch (\InvalidArgumentException $e) { return $this->apiError('Invalid reader position.', 'invalid_reader_position', null, 400); }
        catch (\Throwable $e) { return $this->apiError('Reading progress could not be saved.', 'reader_progress_unavailable', null, 503); }
    }
}
