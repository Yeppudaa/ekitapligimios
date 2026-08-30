<?php

namespace Ekitapligim\IosApi\Service;

final class UgcPolicy
{
	public static function violation(array $values): ?string
	{
		$terms = self::configuredTerms();
		$spamText = [];
		foreach ($values AS $value)
		{
			$spamText[] = (string) $value;
			$normalized = self::normalize((string) $value);
			if ($normalized === '')
			{
				continue;
			}
			foreach ($terms AS $term)
			{
				if ($term !== '' && str_contains($normalized, $term))
				{
					return 'blocked_term';
				}
			}
		}
		$visitor = \XF::visitor();
		if ($visitor->user_id && $visitor->isSpamCheckRequired())
		{
			$checker = \XF::app()->spam()->contentChecker();
			$checker->check($visitor, implode("\n", $spamText), [
				'content_type' => 'ek_ios_ugc',
				'content_id' => 0,
			]);
			if (in_array($checker->getFinalDecision(), ['moderated', 'denied'], true))
			{
				return 'spam_check';
			}
		}
		return null;
	}

	public static function isConfigured(): bool
	{
		return self::configuredTerms() !== [];
	}

	protected static function configuredTerms(): array
	{
		$raw = (string) (\XF::options()->ekIosUgcBlockedTerms ?? '');
		$lines = preg_split('/\R+/u', $raw) ?: [];
		$terms = [];
		foreach ($lines AS $line)
		{
			$line = trim(preg_replace('/\s+#.*$/u', '', (string) $line));
			if ($line !== '')
			{
				$terms[] = self::normalize($line);
			}
		}
		return array_values(array_unique(array_filter($terms)));
	}

	protected static function normalize(string $value): string
	{
		$value = html_entity_decode(strip_tags($value), ENT_QUOTES | ENT_HTML5, 'UTF-8');
		$value = mb_strtolower($value, 'UTF-8');
		if (class_exists('\Normalizer'))
		{
			$value = \Normalizer::normalize($value, \Normalizer::FORM_KC) ?: $value;
		}
		$value = strtr($value, ['0' => 'o', '1' => 'i', '3' => 'e', '4' => 'a', '5' => 's', '7' => 't']);
		return preg_replace('/[^\p{L}\p{N}]+/u', '', $value) ?: '';
	}
}
