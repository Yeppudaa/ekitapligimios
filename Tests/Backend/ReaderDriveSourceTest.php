<?php
// Pass the installed ExternalEbook.php path to exercise the real URL validator.
namespace XF\Service { abstract class AbstractService {} }
namespace XenCustomize\BookThreads\Entity { class Book {} }
namespace Ekitapligim\MobileApi\Api\Controller {
    class BookReaderSource
    {
        public array $delegated = [];
        protected function serveDriveSource(\XenCustomize\BookThreads\Entity\Book $book, string $url)
        {
            $this->delegated[] = [$book, $url];
            return ['parent_pipeline' => true];
        }
        protected function apiError($message, $code) { return ['error' => $code]; }
    }
}
namespace {
    $validatorPath = $argv[1] ?? '';
    if (!is_file($validatorPath)) {
        throw new \RuntimeException('Usage: php ReaderDriveSourceTest.php <installed ExternalEbook.php>');
    }
    require_once $validatorPath;
    require_once __DIR__ . '/../../Backend/IosApi-addon/Api/Controller/BookReaderSource.php';
    class DriveSourceController extends \Ekitapligim\IosApi\Api\Controller\BookReaderSource {
        public function serve($book, string $url) { return $this->serveDriveSource($book, $url); }
    }
    function check(bool $condition, string $message): void {
        if (!$condition) { throw new \RuntimeException($message); }
    }
    $controller = new DriveSourceController();
    $book = new \XenCustomize\BookThreads\Entity\Book();
    foreach (['', '   ', (string) null, 'invalid', 'http://drive.google.com/file/d/test/view',
        'https://example.com/book.pdf', 'https://drive.google.com.evil.example/file/d/test/view',
        'javascript:alert(1)', 'https://127.0.0.1/book.pdf'] as $invalid) {
        check($controller->serve($book, $invalid) === ['error' => 'ebook_unavailable'],
            'Invalid source must return ebook_unavailable');
    }
    check($controller->delegated === [], 'Invalid sources must never reach the download pipeline');
    foreach ([
        ' https://drive.google.com/file/d/test/view?usp=sharing ' => 'https://drive.google.com/file/d/test/view?usp=sharing',
        'drive.google.com/open?id=test&resourcekey=example' => 'https://drive.google.com/open?id=test&resourcekey=example',
        'https://docs.google.com/document/d/test/edit' => 'https://docs.google.com/document/d/test/edit',
    ] as $input => $expected) {
        check($controller->serve($book, $input) === ['parent_pipeline' => true],
            'Valid source must retain the parent access/preview/delivery pipeline');
        check(end($controller->delegated) === [$book, $expected], 'Normalized source and original book are delegated');
    }
    echo "Reader drive source tests passed (real installed URL validator).\n";
}
