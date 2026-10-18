<?php

namespace Ekitapligim\IosApi\Service;

use XenCustomize\BookThreads\Entity\Book;
use XF\Entity\User;

/** A favorite is independent of the mutually exclusive reading shelves. */
class LibraryShelfManager
{
    private const SHELVES = [
        'OKUYORUM' => ['CurrentlyReadingShelf', 'currently_reading_shelf', 'canAddToCurrentlyReadingShelf'],
        'OKUDUM' => ['ReadShelf', 'read_shelf', 'canAddToReadShelf'],
        'OKUYACAGIM' => ['WantToReadShelf', 'want_to_read_shelf', 'canAddToWantToReadShelf'],
    ];

    public function update(Book $book, User $visitor, ?string $shelfState, ?bool $favorite): array
    {
        if (!$visitor->user_id) { throw new \DomainException('Login required.'); }
        if ($shelfState !== null)
        {
            $shelfState = strtoupper(trim($shelfState));
            // Older clients used a fourth shelf for favorites. Preserve their reading shelf.
            if ($shelfState === 'FAVORI')
            {
                if ($favorite === false) { throw new \InvalidArgumentException('Conflicting favorite state.'); }
                $shelfState = null;
                $favorite = true;
            }
            elseif ($shelfState !== 'NONE' && !isset(self::SHELVES[$shelfState]))
            {
                throw new \InvalidArgumentException('Invalid shelf state.');
            }
        }
        if ($shelfState === null && $favorite === null)
        {
            throw new \InvalidArgumentException('A shelf or favorite update is required.');
        }
        if ($shelfState !== null && $shelfState !== 'NONE')
        {
            $permission = self::SHELVES[$shelfState][2];
            if (!$book->$permission()) { throw new \DomainException('Shelf permission denied.'); }
        }
        if ($favorite !== null && !$book->canFavorite())
        {
            throw new \DomainException('Favorite permission denied.');
        }

        $db = \XF::db();
        $db->beginTransaction();
        try
        {
            // Serialize this user's shelf and favorite requests, including rapid consecutive taps.
            $db->fetchOne('SELECT user_id FROM xf_user WHERE user_id = ? FOR UPDATE', (int) $visitor->user_id);
            if ($shelfState !== null)
            {
                foreach (self::SHELVES as $state => [$entity])
                {
                    $this->setMembership($entity, $book, $visitor, $state === $shelfState);
                }
            }
            if ($favorite !== null) { $this->setMembership('Favorite', $book, $visitor, $favorite); }
            $item = $this->snapshot((int) $book->thread_id, (int) $visitor->user_id);
            if (($shelfState !== null && $this->readingState($item) !== $shelfState)
                || ($favorite !== null && $item['is_favorite'] !== $favorite))
            {
                throw new \RuntimeException('Library update was not stored.');
            }
            $db->commit();
            return $item;
        }
        catch (\Throwable $e)
        {
            $db->rollback();
            throw $e;
        }
    }

    private function setMembership(string $entityName, Book $book, User $visitor, bool $add): void
    {
        $em = \XF::em();
        $name = 'XenCustomize\\BookThreads:' . $entityName;
        $membership = $em->findOne($name, ['thread_id' => (int) $book->thread_id, 'user_id' => (int) $visitor->user_id]);
        if ($add && !$membership)
        {
            $membership = $em->create($name);
            // The website's activity feed reads these exact rows and their create_date.
            // Entity hooks also maintain the same shelf/favorite counters as the website.
            $membership->bulkSet(['thread_id' => (int) $book->thread_id, 'user_id' => (int) $visitor->user_id,
                'username' => (string) $visitor->username, 'create_date' => \XF::$time]);
            $membership->save();
        }
        elseif (!$add && $membership) { $membership->delete(); }
    }

    private function snapshot(int $bookId, int $userId): array
    {
        $state = 'NONE';
        foreach (self::SHELVES as $candidate => [, $table])
        {
            if ($this->contains($table, $bookId, $userId)) { $state = $candidate; break; }
        }
        $favorite = $this->contains('favorite', $bookId, $userId);
        if ($state === 'NONE' && $favorite) { $state = 'FAVORI'; }
        return ['book_id' => (string) $bookId, 'bookId' => (string) $bookId,
            'shelf_state' => $state, 'shelfState' => $state, 'is_favorite' => $favorite, 'isFavorite' => $favorite];
    }

    private function contains(string $table, int $bookId, int $userId): bool
    {
        return (bool) \XF::db()->fetchOne('SELECT 1 FROM xf_xcu_book_thread_' . $table . ' WHERE thread_id = ? AND user_id = ?', [$bookId, $userId]);
    }

    private function readingState(array $item): string
    {
        return $item['shelf_state'] === 'FAVORI' ? 'NONE' : $item['shelf_state'];
    }
}
