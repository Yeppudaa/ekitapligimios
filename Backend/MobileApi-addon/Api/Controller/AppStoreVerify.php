<?php

namespace Ekitapligim\MobileApi\Api\Controller;

class AppStoreVerify extends AbstractMobileController
{
	public function actionPost()
	{
		$this->assertMobileWriteScope();
		$visitor = $this->assertRegisteredApiUser();

		$signedTransaction = trim($this->filter('signed_transaction', 'str'));
		$productId = trim($this->filter('product_id', 'str'));
		$originalTransactionId = trim($this->filter('original_transaction_id', 'str'));

		if ($signedTransaction === '' || $productId === '')
		{
			return $this->apiError('signed_transaction and product_id are required.', 'invalid_input');
		}

		$configuredProducts = trim((string) getenv('EKITAPLIGIM_IOS_PRODUCT_IDS'));
		$allowedProducts = $configuredProducts !== ''
			? array_values(array_filter(array_map('trim', explode(',', $configuredProducts))))
			: ['ekitapligim.premium.monthly', 'ekitapligim.premium.yearly'];
		if (!in_array($productId, $allowedProducts, true))
		{
			return $this->apiError('Product is not configured for this app.', 'product_not_allowed');
		}

		$verification = $this->verifySignedTransaction($signedTransaction);
		if (!$verification['valid'])
		{
			return $this->apiError($verification['message'], $verification['code']);
		}

		$transaction = $verification['payload'];
		$bundleId = (string) ($transaction['bundleId'] ?? '');
		$transactionProductId = (string) ($transaction['productId'] ?? '');
		$transactionId = (string) ($transaction['transactionId'] ?? '');
		$payloadOriginalTransactionId = (string) ($transaction['originalTransactionId'] ?? '');
		$environment = (string) ($transaction['environment'] ?? '');
		$expiresDate = (int) ($transaction['expiresDate'] ?? 0);
		$revocationDate = (int) ($transaction['revocationDate'] ?? 0);

		$expectedBundleId = (string) (getenv('EKITAPLIGIM_IOS_BUNDLE_ID') ?: 'com.ekitapligim.app');
		if ($bundleId !== $expectedBundleId)
		{
			return $this->apiError('Transaction bundle does not match this app.', 'bundle_mismatch');
		}
		if ($transactionProductId !== $productId)
		{
			return $this->apiError('Transaction product does not match the requested product.', 'product_mismatch');
		}
		if ($transactionId === '' || $payloadOriginalTransactionId === '')
		{
			return $this->apiError('Transaction identifiers are missing.', 'transaction_id_missing');
		}
		if ($originalTransactionId !== '' && $payloadOriginalTransactionId !== $originalTransactionId)
		{
			return $this->apiError('Original transaction does not match.', 'original_transaction_mismatch');
		}
		if (!$this->isAllowedEnvironment($environment))
		{
			return $this->apiError('Transaction environment is not allowed for this server.', 'environment_mismatch');
		}

		$isActive = $revocationDate <= 0 && ($expiresDate <= 0 || $expiresDate > (\XF::$time * 1000));
		$this->recordEntitlement($visitor, $transaction, $signedTransaction, $isActive);

		return $this->apiResult([
			'success' => $isActive,
			'status' => $isActive ? 'verified_active' : ($revocationDate > 0 ? 'verified_revoked' : 'verified_expired'),
			'is_premium' => $isActive,
			'isPremium' => $isActive,
			'user_id' => (int) $visitor->user_id,
			'product_id' => $productId,
			'productId' => $productId,
			'transaction_id' => $transactionId,
			'transactionId' => $transactionId,
			'original_transaction_id' => $payloadOriginalTransactionId,
			'originalTransactionId' => $payloadOriginalTransactionId,
			'environment' => $environment,
			'expiration_time' => $expiresDate > 0 ? (int) floor($expiresDate / 1000) : null,
			'expirationTime' => $expiresDate > 0 ? (int) floor($expiresDate / 1000) : null,
		]);
	}

	protected function verifySignedTransaction(string $jws): array
	{
		try
		{
			$decoded = $this->decodeAndVerifyJws($jws);
			return [
				'valid' => true,
				'payload' => $decoded['payload']
			];
		}
		catch (\Throwable $e)
		{
			\XF::logException($e, false, 'MobileApi App Store transaction verification failed: ');
			return [
				'valid' => false,
				'code' => 'transaction_verification_failed',
				'message' => 'Transaction could not be verified.'
			];
		}
	}

	protected function decodeAndVerifyJws(string $jws): array
	{
		$parts = explode('.', $jws);
		if (count($parts) !== 3)
		{
			throw new \RuntimeException('Malformed JWS.');
		}

		$header = $this->jsonDecode($this->base64UrlDecode($parts[0]));
		$payload = $this->jsonDecode($this->base64UrlDecode($parts[1]));
		$signature = $this->base64UrlDecode($parts[2]);

		if (($header['alg'] ?? '') !== 'ES256')
		{
			throw new \RuntimeException('Unexpected JWS algorithm.');
		}
		if (empty($header['x5c']) || !is_array($header['x5c']))
		{
			throw new \RuntimeException('Missing JWS certificate chain.');
		}

		$certificates = $this->decodeCertificateChain($header['x5c']);
		$this->verifyCertificateChain($certificates);

		$publicKey = openssl_pkey_get_public($certificates[0]);
		if (!$publicKey)
		{
			throw new \RuntimeException('Could not read JWS public key.');
		}

		$derSignature = $this->ecdsaJoseToDer($signature);
		$ok = openssl_verify($parts[0] . '.' . $parts[1], $derSignature, $publicKey, OPENSSL_ALGO_SHA256);
		if ($ok !== 1)
		{
			throw new \RuntimeException('Invalid JWS signature.');
		}

		return [
			'header' => $header,
			'payload' => $payload
		];
	}

	protected function decodeCertificateChain(array $x5c): array
	{
		$certificates = [];
		foreach ($x5c AS $certificate)
		{
			$pem = "-----BEGIN CERTIFICATE-----\n" . chunk_split((string) $certificate, 64, "\n") . "-----END CERTIFICATE-----\n";
			if (!openssl_x509_read($pem))
			{
				throw new \RuntimeException('Invalid JWS certificate.');
			}
			$certificates[] = $pem;
		}

		return $certificates;
	}

	protected function verifyCertificateChain(array $certificates): void
	{
		$now = time();
		foreach ($certificates AS $certificate)
		{
			$parsed = openssl_x509_parse($certificate);
			if (!$parsed || ($parsed['validFrom_time_t'] ?? 0) > $now || ($parsed['validTo_time_t'] ?? 0) < $now)
			{
				throw new \RuntimeException('JWS certificate is not currently valid.');
			}
		}

		for ($i = 0; $i < count($certificates) - 1; $i++)
		{
			if (openssl_x509_verify($certificates[$i], $certificates[$i + 1]) !== 1)
			{
				throw new \RuntimeException('JWS certificate chain is invalid.');
			}
		}

		$root = $this->appleRootCertificate();
		if ($root === '')
		{
			throw new \RuntimeException('Apple root certificate is not configured.');
		}
		if (openssl_x509_verify($certificates[count($certificates) - 1], $root) !== 1)
		{
			throw new \RuntimeException('JWS certificate chain is not anchored to the configured Apple root.');
		}
	}

	protected function appleRootCertificate(): string
	{
		$inline = trim((string) getenv('EKITAPLIGIM_APPLE_ROOT_CA_PEM'));
		if ($inline !== '')
		{
			return str_replace('\n', "\n", $inline);
		}

		$file = trim((string) getenv('EKITAPLIGIM_APPLE_ROOT_CA_FILE'));
		if ($file !== '' && is_readable($file))
		{
			return (string) file_get_contents($file);
		}

		return '';
	}

	protected function isAllowedEnvironment(string $environment): bool
	{
		$allowed = trim((string) getenv('EKITAPLIGIM_APPSTORE_ENVIRONMENT'));
		if ($allowed === '' || strcasecmp($allowed, 'Both') === 0)
		{
			return in_array($environment, ['Production', 'Sandbox', 'Xcode'], true);
		}

		return strcasecmp($environment, $allowed) === 0;
	}

	protected function recordEntitlement(\XF\Entity\User $user, array $transaction, string $signedTransaction, bool $active): void
	{
		$this->ensureEntitlementTable();
		\XF::db()->query(
			"INSERT INTO xf_ekitapligim_mobile_appstore_entitlement
				(user_id, product_id, transaction_id, original_transaction_id, environment, expires_date, active, signed_transaction_hash, last_verified)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
			ON DUPLICATE KEY UPDATE
				user_id = VALUES(user_id),
				product_id = VALUES(product_id),
				environment = VALUES(environment),
				expires_date = VALUES(expires_date),
				active = VALUES(active),
				signed_transaction_hash = VALUES(signed_transaction_hash),
				last_verified = VALUES(last_verified)",
			[
				(int) $user->user_id,
				(string) ($transaction['productId'] ?? ''),
				(string) ($transaction['transactionId'] ?? ''),
				(string) ($transaction['originalTransactionId'] ?? ''),
				(string) ($transaction['environment'] ?? ''),
				(int) floor(((int) ($transaction['expiresDate'] ?? 0)) / 1000),
				$active ? 1 : 0,
				hash('sha256', $signedTransaction),
				\XF::$time
			]
		);
	}

	protected function ensureEntitlementTable(): void
	{
		\XF::db()->query("
			CREATE TABLE IF NOT EXISTS xf_ekitapligim_mobile_appstore_entitlement (
				entitlement_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
				user_id INT UNSIGNED NOT NULL,
				product_id VARBINARY(100) NOT NULL,
				transaction_id VARBINARY(100) NOT NULL,
				original_transaction_id VARBINARY(100) NOT NULL,
				environment VARBINARY(20) NOT NULL DEFAULT '',
				expires_date INT UNSIGNED NOT NULL DEFAULT 0,
				active TINYINT UNSIGNED NOT NULL DEFAULT 0,
				signed_transaction_hash VARBINARY(64) NOT NULL,
				last_verified INT UNSIGNED NOT NULL DEFAULT 0,
				PRIMARY KEY (entitlement_id),
				UNIQUE KEY transaction_id (transaction_id),
				KEY user_active (user_id, active, expires_date),
				KEY original_transaction_id (original_transaction_id)
			) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
		");
	}

	protected function jsonDecode(string $json): array
	{
		$value = json_decode($json, true);
		if (!is_array($value))
		{
			throw new \RuntimeException('Invalid JWS JSON.');
		}

		return $value;
	}

	protected function base64UrlDecode(string $value): string
	{
		$base64 = strtr($value, '-_', '+/');
		$base64 .= str_repeat('=', (4 - strlen($base64) % 4) % 4);
		$decoded = base64_decode($base64, true);
		if ($decoded === false)
		{
			throw new \RuntimeException('Invalid base64url data.');
		}

		return $decoded;
	}

	protected function ecdsaJoseToDer(string $signature): string
	{
		if (strlen($signature) !== 64)
		{
			throw new \RuntimeException('Invalid ES256 signature length.');
		}

		$r = substr($signature, 0, 32);
		$s = substr($signature, 32, 32);

		return "\x30" . $this->asn1Length(strlen($this->asn1Integer($r)) + strlen($this->asn1Integer($s)))
			. $this->asn1Integer($r)
			. $this->asn1Integer($s);
	}

	protected function asn1Integer(string $value): string
	{
		$value = ltrim($value, "\x00");
		if ($value === '')
		{
			$value = "\x00";
		}
		if ((ord($value[0]) & 0x80) !== 0)
		{
			$value = "\x00" . $value;
		}

		return "\x02" . $this->asn1Length(strlen($value)) . $value;
	}

	protected function asn1Length(int $length): string
	{
		if ($length < 128)
		{
			return chr($length);
		}

		$bytes = '';
		while ($length > 0)
		{
			$bytes = chr($length & 0xff) . $bytes;
			$length >>= 8;
		}

		return chr(0x80 | strlen($bytes)) . $bytes;
	}
}
