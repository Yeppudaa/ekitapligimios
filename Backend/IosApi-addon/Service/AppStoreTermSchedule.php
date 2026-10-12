<?php

namespace Ekitapligim\IosApi\Service;

/** Derives fixed-term delivery from verified transactions, never from replay counts. */
final class AppStoreTermSchedule
{
	public static function rebuild(int $userId): void
	{
		// Caller holds the per-user purchase lock and database transaction.
		$db = \XF::db();
		$rows = $db->fetchAll("SELECT entitlement.*, state.transaction_state
			FROM xf_ekitapligim_mobile_appstore_entitlement entitlement
			LEFT JOIN xf_ekitapligim_ios_appstore_state state ON state.transaction_id = entitlement.transaction_id
			WHERE entitlement.user_id = ?", [$userId]);
		$owners = [];
		$terms = [];
		$coverage = [];
		foreach ($rows as $row)
		{
			$original = (string) $row['original_transaction_id'];
			if (!isset($owners[$original]))
			{
				$owners[$original] = (int) $db->fetchOne("SELECT user_id FROM xf_ekitapligim_mobile_appstore_entitlement
					WHERE original_transaction_id = ? AND user_id > 0 ORDER BY entitlement_id ASC LIMIT 1", [$original]);
			}
			if ($owners[$original] !== $userId) { continue; }
			$transaction = !empty($row['transaction_state'])
				? json_decode($row['transaction_state'], true, 512, JSON_THROW_ON_ERROR) : [];
			if (!$transaction)
			{
				// Preserve pre-ledger grants without guessing their purchase dates or durations.
				if (!empty($row['active']) && (int) $row['expires_date'] > 0)
				{
					$coverage[(string) $row['environment']][] = [0, (int) $row['expires_date']];
				}
				continue;
			}
			$purchase = (int) floor((int) ($transaction['purchaseDate'] ?? 0) / 1000);
			$months = AppStoreEntitlementPolicy::nonRenewingMonths($transaction);
			$valid = $purchase > 0 && empty($transaction['revocationDate']) && empty($transaction['isUpgraded']);
			if ($months > 0)
			{
				if (!$valid)
				{
					$db->query('UPDATE xf_ekitapligim_mobile_appstore_entitlement SET active = 0 WHERE transaction_id = ?', [$row['transaction_id']]);
					continue;
				}
				$terms[] = ['row' => $row, 'transaction' => $transaction, 'purchase' => $purchase];
			}
			else if ($valid && ($transaction['type'] ?? '') === 'Auto-Renewable Subscription'
				&& (int) $row['expires_date'] > $purchase)
			{
				// Fixed terms wait behind overlapping verified Apple subscription periods.
				$coverage[(string) $row['environment']][] = [$purchase, (int) $row['expires_date']];
			}
		}
		usort($terms, static function (array $a, array $b): int {
			return ((int) $a['transaction']['purchaseDate'] <=> (int) $b['transaction']['purchaseDate'])
				?: strcmp((string) $a['row']['transaction_id'], (string) $b['row']['transaction_id']);
		});
		foreach ($coverage as &$intervals)
		{
			usort($intervals, static fn($a, $b) => $a[0] <=> $b[0]);
			$merged = [];
			foreach ($intervals as $interval)
			{
				$last = count($merged) - 1;
				if ($last >= 0 && $interval[0] <= $merged[$last][1])
				{
					$merged[$last][1] = max($merged[$last][1], $interval[1]);
				}
				else { $merged[] = $interval; }
			}
			$intervals = $merged;
		}
		unset($intervals);
		$ends = [];
		foreach ($terms as $term)
		{
			$row = $term['row'];
			$environment = (string) $row['environment'];
			$start = max($term['purchase'], $ends[$environment] ?? 0);
			$transaction = $term['transaction'];
			$transaction['purchaseDate'] = $start * 1000;
			$end = AppStoreEntitlementPolicy::effectiveExpirationSeconds($transaction, []);
			foreach ($coverage[$environment] ?? [] as [$coveredStart, $coveredEnd])
			{
				if ($coveredStart < $end && $coveredEnd > $start)
				{
					if ($coveredStart <= $start)
					{
						// Already covered at purchase/start: begin the calendar term afterwards.
						$start = $coveredEnd;
						$transaction['purchaseDate'] = $start * 1000;
						$end = AppStoreEntitlementPolicy::effectiveExpirationSeconds($transaction, []);
					}
					else
					{
						// A later subscription interrupts delivery: carry only overlapping time.
						$end += $coveredEnd - $coveredStart;
					}
				}
			}
			$ends[$environment] = $end;
			$db->query('UPDATE xf_ekitapligim_mobile_appstore_entitlement SET expires_date = ?, active = ? WHERE transaction_id = ?',
				[$end, $end > \XF::$time ? 1 : 0, $row['transaction_id']]);
		}
	}
}
