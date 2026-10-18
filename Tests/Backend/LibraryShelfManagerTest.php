<?php
// Offline execution of the production shelf service and controller. No XenForo bootstrap or network.
namespace XF\Entity {
    class User { public function __construct(public int $user_id = 1, public string $username = 'reader') {} }
}
namespace XF\Mvc { class ParameterBag { public function __construct(public int $thread_id) {} } }
namespace XF\Mvc\Reply { class Exception extends \RuntimeException {} }
namespace XenCustomize\BookThreads\Entity {
    class Book {
        public bool $allowed = true;
        public function __construct(public int $thread_id = 7) {}
        public function canFavorite(): bool { return $this->allowed; }
        public function canAddToCurrentlyReadingShelf(): bool { return $this->allowed; }
        public function canAddToReadShelf(): bool { return $this->allowed; }
        public function canAddToWantToReadShelf(): bool { return $this->allowed; }
    }
}
namespace Ekitapligim\MobileApi\Api\Controller {
    class AbstractMobileController {
        public array $input = [];
        public bool $loggedIn = true;
        public bool $allowed = true;
        public string $contentType = '';
        public string $rawBody = '';
        public object $request;
        public function __construct() {
            $this->request = new class($this) {
                public function __construct(private object $controller) {}
                public function getInput(): array { return $this->controller->input; }
                public function getServer(string $name, string $default = ''): string { return $this->controller->contentType ?: $default; }
                public function getInputRaw(): string { return $this->controller->rawBody; }
            };
        }
        protected function assertMobileWriteScope(): void {}
        protected function assertRegisteredApiUser(): \XF\Entity\User {
            if (!$this->loggedIn) { throw new \XF\Mvc\Reply\Exception('login required'); }
            return new \XF\Entity\User();
        }
        protected function assertBook(int $id): \XenCustomize\BookThreads\Entity\Book {
            if ($id === 99) { throw new \XF\Mvc\Reply\Exception('not viewable'); }
            $book = new \XenCustomize\BookThreads\Entity\Book($id);
            $book->allowed = $this->allowed;
            return $book;
        }
        protected function apiResult(array $result): array { return $result; }
        protected function apiError(string $message, string $code, $params = null, int $status = 400): array {
            return ['error' => $code, 'status' => $status];
        }
    }
}
namespace {
    class XF {
        public static int $time = 2000;
        public static LibraryMemory $memory;
        public static function db(): LibraryMemory { return self::$memory; }
        public static function em(): LibraryMemory { return self::$memory; }
    }
    final class Membership {
        public array $values = [];
        public function __construct(private LibraryMemory $memory, public string $name) {}
        public function bulkSet(array $values): void { $this->values = $values; }
        public function save(): void {
            $key = $this->memory->key($this->name, $this->values);
            if ($this->memory->failWrite) { throw new \RuntimeException('write unavailable'); }
            $this->memory->writes++;
            $this->memory->rows[$key] = $this->values + ['row_id' => ++$this->memory->nextId];
            $this->memory->counters[$this->name] = ($this->memory->counters[$this->name] ?? 0) + 1;
        }
        public function delete(): void {
            if ($this->memory->failWrite) { throw new \RuntimeException('write unavailable'); }
            $this->memory->writes++;
            unset($this->memory->rows[$this->memory->key($this->name, $this->values)]);
            $this->memory->counters[$this->name]--;
        }
    }
    final class LibraryMemory {
        public array $rows = [];
        public array $counters = [];
        public array $progress = [7 => ['position_type' => 'epub', 'position_value' => 'epubcfi(/6/2!/4/2:4)', 'progress_percent' => 28]];
        public int $nextId = 0;
        public int $writes = 0;
        public int $locks = 0;
        public bool $failReadback = false;
        public bool $failWrite = false;
        private array $snapshot = [];
        private const TABLES = ['CurrentlyReadingShelf' => 'currently_reading_shelf', 'ReadShelf' => 'read_shelf',
            'WantToReadShelf' => 'want_to_read_shelf', 'Favorite' => 'favorite'];
        public function beginTransaction(): void { $this->snapshot = [$this->rows, $this->counters, $this->nextId]; }
        public function commit(): void {}
        public function rollback(): void { [$this->rows, $this->counters, $this->nextId] = $this->snapshot; }
        public function key(string $name, array $values): string { return "$name:{$values['thread_id']}:{$values['user_id']}"; }
        public function create(string $name): Membership { return new Membership($this, substr($name, strpos($name, ':') + 1)); }
        public function findOne(string $name, array $values): ?Membership {
            $item = $this->create($name);
            $row = $this->rows[$this->key($item->name, $values)] ?? null;
            if (!$row) { return null; }
            $item->values = $row;
            return $item;
        }
        public function fetchOne(string $sql, $params) {
            if (str_contains($sql, 'FOR UPDATE')) { $this->locks++; return $params; }
            if ($this->failReadback) { throw new \RuntimeException('readback unavailable'); }
            foreach (self::TABLES as $name => $table) {
                if (str_contains($sql, 'xf_xcu_book_thread_' . $table . ' ')) {
                    return isset($this->rows["$name:{$params[0]}:{$params[1]}"]);
                }
            }
            throw new \LogicException('Unexpected query');
        }
    }
    require_once __DIR__ . '/../../Backend/IosApi-addon/Service/LibraryShelfManager.php';
    require_once __DIR__ . '/../../Backend/IosApi-addon/Api/Controller/MeLibraryItem.php';
    $checks = 0;
    function check(bool $condition, string $message): void {
        global $checks;
        if (!$condition) { throw new \RuntimeException($message); }
        $checks++;
    }
    XF::$memory = $db = new LibraryMemory();
    $service = new \Ekitapligim\IosApi\Service\LibraryShelfManager();
    $book = new \XenCustomize\BookThreads\Entity\Book();
    $user = new \XF\Entity\User();
    $originalProgress = $db->progress;
    $want = $service->update($book, $user, 'OKUYACAGIM', null);
    check($want['shelf_state'] === 'OKUYACAGIM' && !$want['is_favorite'], 'Want-to-read is stored');
    $favorite = $service->update($book, $user, null, true);
    check($favorite['shelf_state'] === 'OKUYACAGIM' && $favorite['is_favorite'], 'Adding favorite preserves reading shelf');
    check($db->rows['Favorite:7:1']['create_date'] === XF::$time, 'Real favorite feed source gets server timestamp');
    $favoriteRow = $db->rows['Favorite:7:1'];
    $reading = $service->update($book, $user, 'OKUYORUM', null);
    check($reading['shelf_state'] === 'OKUYORUM' && $reading['is_favorite'], 'Starting reading preserves favorite');
    check(!isset($db->rows['WantToReadShelf:7:1']) && isset($db->rows['CurrentlyReadingShelf:7:1']), 'Reading shelves stay mutually exclusive');
    check($db->rows['Favorite:7:1'] === $favoriteRow, 'Shelf change preserves favorite event identity and date');
    check($db->rows['CurrentlyReadingShelf:7:1']['create_date'] === XF::$time, 'Real reading feed source gets server timestamp');
    $readingRow = $db->rows['CurrentlyReadingShelf:7:1'];
    $writes = $db->writes;
    XF::$time++;
    $service->update($book, $user, 'OKUYORUM', true);
    check($db->writes === $writes && $db->rows['CurrentlyReadingShelf:7:1'] === $readingRow, 'Retry does not duplicate or reorder feed events');
    check($db->counters['CurrentlyReadingShelf'] === 1 && $db->counters['Favorite'] === 1, 'Retry keeps counters stable');
    $notFavorite = $service->update($book, $user, null, false);
    check(!$notFavorite['is_favorite'] && $notFavorite['shelf_state'] === 'OKUYORUM', 'Removing favorite preserves reading');
    $legacy = $service->update($book, $user, 'FAVORI', null);
    check($legacy['is_favorite'] && $legacy['shelf_state'] === 'OKUYORUM', 'Legacy favorite request is additive');
    $finished = $service->update($book, $user, 'OKUDUM', null);
    check($finished['shelf_state'] === 'OKUDUM' && $finished['is_favorite'], 'Finished and favorite coexist');
    $removed = $service->update($book, $user, 'NONE', null);
    check($removed['shelf_state'] === 'FAVORI' && $removed['is_favorite'], 'Removing reading shelf keeps independent favorite');
    check($db->progress === $originalProgress, 'All shelf and favorite writes preserve EPUB progress');
    $service->update($book, new \XF\Entity\User(2, 'other'), 'OKUYORUM', false);
    check(isset($db->rows['CurrentlyReadingShelf:7:2']) && isset($db->rows['Favorite:7:1']), 'Membership is account scoped');

    $rowsBefore = $db->rows;
    $countersBefore = $db->counters;
    $db->failReadback = true;
    try { $service->update($book, $user, 'OKUYORUM', false); throw new \LogicException('False success'); }
    catch (\RuntimeException $expected) {}
    $db->failReadback = false;
    check($db->rows === $rowsBefore && $db->counters === $countersBefore, 'Readback failure rolls membership and counters back');
    $db->failWrite = true;
    try { $service->update($book, $user, null, false); throw new \LogicException('False success'); }
    catch (\RuntimeException $expected) {}
    $db->failWrite = false;
    check($db->rows === $rowsBefore, 'Storage failure preserves prior favorite');

    $controller = new \Ekitapligim\IosApi\Api\Controller\MeLibraryItem();
    $params = new \XF\Mvc\ParameterBag(7);
    foreach ([[], ['shelf_state' => 'invalid'], ['shelf_state' => ''], ['is_favorite' => 'yes'],
        ['is_favorite' => null], ['is_favorite' => []], ['shelf_state' => 'FAVORI', 'is_favorite' => 0],
        ['is_favorite' => 1, 'isFavorite' => 0], ['shelf_state' => 'OKUDUM', 'shelfState' => 'OKUYORUM']] as $input)
    {
        $controller->input = $input;
        $writes = $db->writes;
        check($controller->actionPut($params)['status'] === 400 && $db->writes === $writes, 'Invalid request fails without mutation');
    }
    $controller->input = ['is_favorite' => '0'];
    check(!$controller->actionPut($params)['item']['is_favorite'], 'Explicit false is not treated as omitted');
    $controller->input = ['isFavorite' => true];
    check($controller->actionPut($params)['item']['is_favorite'], 'Camel-case favorite alias works');
    $controller->input = [];
    $controller->contentType = 'application/x-www-form-urlencoded; charset=utf-8';
    $controller->rawBody = 'is_favorite=0';
    check(!$controller->actionPut($params)['item']['is_favorite'], 'UTF-8 PUT form is parsed when XenForo leaves input empty');
    $controller->rawBody = 'shelf_state=OKUYORUM&is_favorite=1';
    $utf8 = $controller->actionPut($params);
    check($utf8['item']['shelf_state'] === 'OKUYORUM' && $utf8['item']['is_favorite'], 'UTF-8 PUT shelf and favorite both persist');
    $controller->rawBody = str_repeat('x', 8193);
    $writes = $db->writes;
    check($controller->actionPut($params)['status'] === 400 && $db->writes === $writes, 'Oversized raw form rejected without changes');
    $controller->contentType = 'application/json';
    $controller->rawBody = 'is_favorite=0';
    check($controller->actionPut($params)['status'] === 400 && $db->writes === $writes, 'Raw form fallback is MIME restricted');
    $controller->contentType = '';
    $controller->rawBody = '';
    $controller->input = ['isFavorite' => true];
    $controller->allowed = false;
    $writes = $db->writes;
    check($controller->actionPut($params)['status'] === 403 && $db->writes === $writes, 'XenForo favorite permission enforced');
    $controller->input = ['shelf_state' => 'OKUYORUM'];
    check($controller->actionPut($params)['status'] === 403 && $db->writes === $writes, 'XenForo reading-shelf permission enforced');
    $controller->allowed = true;
    foreach ([false, true] as $loggedIn)
    {
        $controller->loggedIn = $loggedIn;
        try { $controller->actionPut(new \XF\Mvc\ParameterBag($loggedIn ? 99 : 7)); throw new \LogicException('Unauthorized book update'); }
        catch (\XF\Mvc\Reply\Exception $expected) {}
    }
    check($db->writes === $writes, 'Guest and hidden book requests do not write');
    $controller->input = ['is_favorite' => 0];
    $db->failWrite = true;
    check($controller->actionPut($params)['status'] === 503, 'Storage failure never returns success');
    check($db->locks > 0, 'Mutations serialize the current account');
    echo "Library shelves and favorites: $checks checks passed.\n";
}
