<?php
namespace Ekitapligim\IosApi\Api\Controller;

use Ekitapligim\IosApi\Service\ReaderProgress;
use Ekitapligim\MobileApi\Service\ShelfManager;

class MeLibrary extends \Ekitapligim\MobileApi\Api\Controller\AbstractMobileController
{
    public function actionGet()
    {
        $this->assertMobileScope();
        $visitor = $this->assertRegisteredApiUser();
        $userId = (int) $visitor->user_id;
        try { $progress = (new ReaderProgress())->all($userId); }
        catch (\Throwable $e) { return $this->apiError('Reading progress unavailable.', 'reader_progress_unavailable', null, 503); }
        $items = [];
        foreach ((new ShelfManager())->getLibraryItems($userId) as $item)
        {
            $items[(int) $item['book_id']] = $item;
        }
        foreach ($progress as $id => $row)
        {
            if (!isset($items[$id])) { $items[$id] = ['book_id' => (string) $id, 'shelf_state' => 'NONE']; }
        }
        $result = [];
        foreach ($items as $id => $item)
        {
            try { $book = $this->assertBook($id); }
            catch (\XF\Mvc\Reply\Exception $e) { continue; }
            $row = $progress[$id] ?? null;
            $page = $row && $row['position_type'] === 'pdf' && ctype_digit((string) $row['position_value']) ? (int) $row['position_value'] : 0;
            $item['last_read_page'] = $item['lastReadPage'] = $page;
            $item['progress_percent'] = $item['progressPercent'] = $row ? (int) round((float) $row['progress_percent']) : 0;
            $item['last_read_date'] = $item['lastReadDate'] = (int) ($row['last_read_date'] ?? 0);
            $item['position_type'] = (string) ($row['position_type'] ?? '');
            $item['title'] = (string) $book->book_title;
            $item['author'] = (string) $book->book_author;
            $item['page_count'] = $item['pageCount'] = max(1, (int) $book->book_pages);
            $item['cover_url'] = $item['coverUrl'] = 'https://cdn.ekitapligim.com/data/books/covers/' . (int) floor($id / 1000) . '/' . $id . '.jpg';
            $result[] = $item;
        }
        usort($result, static fn(array $a, array $b): int => ($b['last_read_date'] <=> $a['last_read_date']) ?: ((int) $b['book_id'] <=> (int) $a['book_id']));
        return $this->apiResult(['items' => $result, 'library' => $result]);
    }
}
