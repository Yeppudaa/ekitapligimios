<?php
// Run without XenForo or a live database: executes the actual compare/save service.
require_once __DIR__ . '/../../Backend/IosApi-addon/Service/ReaderProgress.php';

use Ekitapligim\IosApi\Service\ReaderProgress;

class XF { public static int $time = 2000; }
final class ProgressMemoryDb
{
    public array $rows = [];
    public bool $failWrite = false;
    public bool $failReadAfterWrite = false;
    public int $writes = 0;
    private array $snapshot = [];
    public function beginTransaction(): void { $this->snapshot = $this->rows; }
    public function commit(): void {}
    public function rollback(): void { $this->rows = $this->snapshot; }
    public function fetchRow(string $sql, array $params)
    {
        if ($this->failReadAfterWrite && $this->writes > 0) { throw new RuntimeException('read failed'); }
        return $this->rows[implode(':', $params)] ?? false;
    }
    public function query(string $sql, array $params): void
    {
        if ($this->failWrite) { throw new RuntimeException('write failed'); }
        [$user, $book, $type, $value, $percent, $date] = $params;
        $this->writes++;
        $this->rows["$user:$book"] = ['position_type' => $type, 'position_value' => $value,
            'progress_percent' => round($percent, 2), 'last_read_date' => $date];
    }
}
final class TestReaderProgress extends ReaderProgress
{
    public function __construct(public ProgressMemoryDb $memory) {}
    protected function db() { return $this->memory; }
}
function check(bool $condition, string $message): void
{
    if (!$condition) { throw new RuntimeException($message); }
}

$db = new ProgressMemoryDb();
$service = new TestReaderProgress($db);
$empty = $service->get(1, 7);
check($empty['progress'] === null && !$empty['saved'], 'Missing progress has no fabricated page');
$pdf = $service->save(1, 7, 'pdf', '25', 25, $empty['revision']);
check($pdf['saved'] && $pdf['progress']['position_value'] === '25', 'PDF 25 saved');
check($pdf['progress']['last_read_date'] === 2000, 'Server timestamp returned');
$next = $service->save(1, 7, 'pdf', '40', 40, $pdf['revision']);
$conflict = $service->save(1, 7, 'pdf', '60', 60, $pdf['revision']);
check($conflict['conflict'] && !$conflict['saved'], 'Same-second stale write rejected');
check($conflict['progress']['position_value'] === '40', 'Conflict returns canonical position');
$back = $service->save(1, 7, 'pdf', '12', 12, $next['revision']);
check($back['saved'] && $back['progress']['position_value'] === '12', 'Intentional backward reading allowed');
check($service->get(2, 7)['progress'] === null, 'Account isolation');
$cfi = 'epubcfi(/6/4[bolum]!/4/2/1:25)';
$epub = $service->save(1, 8, 'epub', $cfi, 20.1234, $empty['revision']);
check($epub['progress']['position_value'] === $cfi, 'EPUB CFI survives roundtrip');
check($epub['revision'] === $service->get(1, 8)['revision'], 'Revision uses stored decimal precision');
foreach ([['pdf', '0', 0], ['epub', '25', 10], ['pdf', '12', NAN], ['pdf', '12', 101], ['epub', str_repeat('x', 256), 10]] as $invalid)
{
    try { ReaderProgress::validate(...$invalid); throw new RuntimeException('Invalid input accepted'); }
    catch (InvalidArgumentException $expected) {}
}
$db->failWrite = true;
try { $service->save(1, 7, 'pdf', '30', 30, $back['revision']); throw new LogicException('Write failure reported success'); }
catch (RuntimeException $expected) {}
$db->failWrite = false;
check($service->get(1, 7)['progress']['position_value'] === '12', 'Failed save preserves old progress');

$rollbackDb = new ProgressMemoryDb();
$rollbackDb->failReadAfterWrite = true;
try { (new TestReaderProgress($rollbackDb))->save(1, 7, 'pdf', '30', 30, $empty['revision']); throw new LogicException('Readback failure reported success'); }
catch (RuntimeException $expected) {}
check($rollbackDb->rows === [], 'Readback failure rolls back transaction');
echo "Reader progress service: 14 scenarios passed.\n";
