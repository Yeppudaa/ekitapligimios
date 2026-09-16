<?php

namespace Ekitapligim\IosApi\Service;

/** Uses exactly the same record as Codex/BookReader. No parallel progress table. */
class ReaderProgress
{
    private const TABLE = 'xf_codex_book_reader_progress';

    public static function normalize(?array $row): ?array
    {
        if (!$row) { return null; }
        return [
            'position_type' => (string) $row['position_type'],
            'position_value' => (string) $row['position_value'],
            'progress_percent' => (float) $row['progress_percent'],
            'last_read_date' => (int) $row['last_read_date'],
        ];
    }

    public static function revision(?array $row): string
    {
        return hash('sha256', json_encode(self::normalize($row), JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES));
    }

    public static function validate(string $type, string $value, float $percent): void
    {
        if (!is_finite($percent) || $percent < 0 || $percent > 100 || strlen($value) > 255
            || ($type !== 'pdf' && $type !== 'epub')
            || ($type === 'pdf' && (!ctype_digit($value) || (int) $value < 1))
            || ($type === 'epub' && !preg_match('/^epubcfi\([^\r\n]+![^\r\n]+\)$/D', $value)))
        {
            throw new \InvalidArgumentException('Invalid reader position.');
        }
    }

    protected function db()
    {
        $db = \XF::db();
        if (!$db->getSchemaManager()->tableExists(self::TABLE))
        {
            throw new \RuntimeException('Reader progress storage unavailable.');
        }
        return $db;
    }

    public function get(int $userId, int $bookId): array
    {
        $row = $this->db()->fetchRow('SELECT position_type, position_value, progress_percent, last_read_date FROM '
            . self::TABLE . ' WHERE user_id = ? AND thread_id = ?', [$userId, $bookId]);
        return $this->response($row ?: null);
    }

    public function all(int $userId): array
    {
        return $this->db()->fetchAllKeyed('SELECT thread_id, position_type, position_value, progress_percent, last_read_date FROM '
            . self::TABLE . ' WHERE user_id = ? ORDER BY last_read_date DESC, thread_id DESC', 'thread_id', $userId);
    }

    public function save(int $userId, int $bookId, string $type, string $value, float $percent, string $baseRevision): array
    {
        self::validate($type, $value, $percent);
        $db = $this->db();
        $db->beginTransaction();
        try
        {
            // Lock the shared row so web writes cannot race the compare-and-save.
            $row = $db->fetchRow('SELECT position_type, position_value, progress_percent, last_read_date FROM '
                . self::TABLE . ' WHERE user_id = ? AND thread_id = ? FOR UPDATE', [$userId, $bookId]) ?: null;
            if ($baseRevision !== '' && !hash_equals(self::revision($row), $baseRevision))
            {
                $db->commit();
                return $this->response($row, false, true);
            }
            $db->query('INSERT INTO ' . self::TABLE . '
                (user_id, thread_id, position_type, position_value, progress_percent, last_read_date)
                VALUES (?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE position_type = VALUES(position_type), position_value = VALUES(position_value),
                    progress_percent = VALUES(progress_percent), last_read_date = VALUES(last_read_date)',
                [$userId, $bookId, $type, $value, $percent, \XF::$time]);
            // Return the stored representation (including DB decimal rounding), not the request.
            $result = $this->get($userId, $bookId);
            $db->commit();
            $result['saved'] = true;
            $result['success'] = true;
            return $result;
        }
        catch (\Throwable $e)
        {
            $db->rollback();
            throw $e;
        }
    }

    private function response(?array $row, bool $saved = false, bool $conflict = false): array
    {
        return ['progress' => self::normalize($row), 'revision' => self::revision($row),
            'saved' => $saved, 'success' => !$conflict, 'conflict' => $conflict];
    }
}
