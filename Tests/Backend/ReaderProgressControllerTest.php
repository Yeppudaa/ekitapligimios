<?php
namespace XF\Mvc\Reply { class Exception extends \RuntimeException {} }
namespace XF\Mvc {
    class ParameterBag { public function __construct(public int $thread_id) {} }
}
namespace Ekitapligim\MobileApi\Api\Controller {
    class AbstractMobileController
    {
        public array $input = [];
        public bool $loggedIn = true;
        protected function assertMobileScope(): void {}
        protected function assertMobileWriteScope(): void {}
        protected function assertRegisteredApiUser(): object {
            if (!$this->loggedIn) { throw new \XF\Mvc\Reply\Exception('login required'); }
            return (object) ['user_id' => 1, 'username' => 'reader'];
        }
        protected function assertBook(int $id): object {
            if ($id === 99) { throw new \XF\Mvc\Reply\Exception('not viewable'); }
            return (object) ['thread_id' => $id, 'book_title' => "Book $id", 'book_author' => 'Author', 'book_pages' => 100];
        }
        protected function filter(string $key, string $type) { return $this->input[$key] ?? ($type === 'float' ? 0 : ''); }
        protected function apiResult(array $result): array { return $result; }
        protected function apiError(string $message, string $code, $params = null, int $status = 400): array {
            return ['error' => $code, 'status' => $status];
        }
    }
}
namespace Ekitapligim\MobileApi\Service {
    class ShelfManager {
        public static array $shelfCalls = [];
        public function getLibraryItems(int $userId): array { return [['book_id' => '7', 'shelf_state' => 'OKUYORUM']]; }
        public function applyShelfState($book, int $userId, string $state): void { self::$shelfCalls[] = [$book->thread_id, $userId, $state]; }
    }
}
namespace {
    class XF {
        public static int $time = 2000;
        public static $database;
        public static function db() { return self::$database; }
    }
    class ControllerMemoryDb {
        public bool $available = true;
        public int $writes = 0;
        public array $rows = [
            7 => ['thread_id' => 7, 'position_type' => 'pdf', 'position_value' => '25', 'progress_percent' => 25, 'last_read_date' => 100],
            8 => ['thread_id' => 8, 'position_type' => 'epub', 'position_value' => 'epubcfi(/6/2!/4/2/1:12)', 'progress_percent' => 12, 'last_read_date' => 200],
            99 => ['thread_id' => 99, 'position_type' => 'pdf', 'position_value' => '10', 'progress_percent' => 10, 'last_read_date' => 300],
        ];
        public function getSchemaManager() { return $this; }
        public function tableExists(string $table): bool { return $this->available; }
        public function fetchAllKeyed($sql, $key, $user): array { return $this->rows; }
        public function fetchRow($sql, $params) { return $this->rows[$params[1]] ?? false; }
        public function query($sql, $params): void { $this->writes++; }
        public function beginTransaction(): void {}
        public function commit(): void {}
        public function rollback(): void {}
    }
    require_once __DIR__ . '/../../Backend/IosApi-addon/Service/ReaderProgress.php';
    require_once __DIR__ . '/../../Backend/IosApi-addon/Api/Controller/BookReaderProgress.php';
    require_once __DIR__ . '/../../Backend/IosApi-addon/Api/Controller/MeLibrary.php';
    require_once __DIR__ . '/../../Backend/IosApi-addon/Api/Controller/MeLibraryItem.php';
    function check(bool $condition, string $message): void { if (!$condition) { throw new \RuntimeException($message); } }
    XF::$database = new ControllerMemoryDb();
    $controller = new \Ekitapligim\IosApi\Api\Controller\BookReaderProgress();
    $params = new \XF\Mvc\ParameterBag(7);
    $get = $controller->actionGet($params);
    check($get['progress']['position_value'] === '25', 'GET returns web PDF progress');
    $controller->input = ['position_type' => 'pdf', 'position_value' => '40', 'progress_percent' => 40,
        'base_revision' => $get['revision'], 'account_name' => 'different-user'];
    check($controller->actionPost($params)['error'] === 'reader_account_changed', 'Wrong-account pending write refused');
    check(XF::$database->writes === 0, 'Wrong-account write does not touch storage');
    $controller->loggedIn = false;
    foreach (['actionGet', 'actionPost'] as $action) {
        try { $controller->$action($params); throw new \LogicException('Anonymous request accepted'); }
        catch (\XF\Mvc\Reply\Exception $expected) {}
    }
    $controller->loggedIn = true;
    foreach (['actionGet', 'actionPost'] as $action) {
        try { $controller->$action(new \XF\Mvc\ParameterBag(99)); throw new \LogicException('Hidden book accepted'); }
        catch (\XF\Mvc\Reply\Exception $expected) {}
    }
    $library = (new \Ekitapligim\IosApi\Api\Controller\MeLibrary())->actionGet()['items'];
    check(array_column($library, 'book_id') === ['8', '7'], 'Unshelved reading book included, hidden book omitted, server recency ordering');
    check($library[0]['position_type'] === 'epub' && $library[0]['last_read_page'] === 0, 'EPUB is not represented as a PDF page');
    $shelf = new \Ekitapligim\IosApi\Api\Controller\MeLibraryItem();
    $shelf->input = ['shelf_state' => 'FAVORI', 'last_read_page' => '1', 'progress_percent' => 1];
    check($shelf->actionPut(new \XF\Mvc\ParameterBag(8))['success'], 'Shelf update succeeds');
    check(XF::$database->writes === 0, 'Shelf update never overwrites progress');
    XF::$database->available = false;
    check($controller->actionGet($params)['status'] === 503, 'Missing progress storage is an error, not empty success');
    echo "Reader controllers: auth, account binding, permissions, unshelved books and shelf preservation passed.\n";
}
