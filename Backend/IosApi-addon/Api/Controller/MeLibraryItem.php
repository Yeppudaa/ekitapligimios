<?php
namespace Ekitapligim\IosApi\Api\Controller;

use Ekitapligim\MobileApi\Service\ShelfManager;
use XF\Mvc\ParameterBag;

class MeLibraryItem extends \Ekitapligim\MobileApi\Api\Controller\AbstractMobileController
{
    public function actionPut(ParameterBag $params)
    {
        $this->assertMobileWriteScope();
        $visitor = $this->assertRegisteredApiUser();
        $book = $this->assertBook((int) $params->thread_id);
        $state = strtoupper(trim($this->filter('shelf_state', 'str') ?: $this->filter('shelfState', 'str')));
        try { (new ShelfManager())->applyShelfState($book, (int) $visitor->user_id, $state ?: 'NONE'); }
        catch (\Throwable $e) { return $this->apiError('Shelf could not be updated.', 'shelf_error'); }
        // Shelf/favorite updates must never turn an EPUB CFI into a PDF page or overwrite a newer web position.
        return $this->apiResult(['success' => true]);
    }
}
