<?php

namespace Ekitapligim\IosApi\Api\Controller;

use Ekitapligim\IosApi\Service\AppStoreEntitlementPolicy;
use Ekitapligim\IosApi\Service\AppStoreTransactionStore;
use Ekitapligim\IosApi\Service\IosMembershipSynchronizer;

class AppStoreVerify extends \Ekitapligim\MobileApi\Api\Controller\AbstractMobileController
{
	public function actionPost()
	{
		$this->assertMobileWriteScope();
		$visitor = $this->assertRegisteredApiUser();
		$accountName = trim($this->filter('account_name', 'str'));
		if ($accountName !== '' && $accountName !== (string) $visitor->username)
		{
			return $this->apiError('The purchase account changed.', 'purchase_account_changed', null, 409);
		}
		if ($this->filter('prepare_purchase', 'bool'))
		{
			if ($accountName === '') { return $this->apiError('Purchase account is required.', 'purchase_account_required'); }
			try
			{
				AppStoreTransactionStore::ensureTables();
				return $this->apiResult(['success' => true,
					'app_account_token' => AppStoreTransactionStore::accountToken((int) $visitor->user_id)]);
			}
			catch (\Throwable $e)
			{
				return $this->apiError('Purchase preparation is temporarily unavailable.', 'purchase_storage_unavailable', null, 503);
			}
		}

		$signedTransaction = trim($this->filter('signed_transaction', 'str'));
		$productId = trim($this->filter('product_id', 'str'));
		$originalTransactionId = trim($this->filter('original_transaction_id', 'str'));
		$signedRenewalInfo = trim($this->filter('signed_renewal_info', 'str'));

		if ($signedTransaction === '' || $productId === '')
		{
			return $this->apiError('signed_transaction and product_id are required.', 'invalid_input');
		}

		if (!$this->isAllowedProductId($productId))
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
		$renewalInfo = [];
		if ($signedRenewalInfo !== '')
		{
			try
			{
				$renewalInfo = $this->decodeAndVerifyJws($signedRenewalInfo)['payload'];
			}
			catch (\Throwable $e)
			{
				return $this->apiError('Renewal information could not be verified.', 'renewal_verification_failed');
			}
		}

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
		if (!AppStoreEntitlementPolicy::hasValidProductType($transaction))
		{
			return $this->apiError('Transaction product type mismatch.', 'product_type_mismatch');
		}
		if ($renewalInfo)
		{
			$renewalOriginalId = (string) ($renewalInfo['originalTransactionId'] ?? '');
			$renewalProductId = (string) ($renewalInfo['autoRenewProductId'] ?? '');
			$renewalEnvironment = (string) ($renewalInfo['environment'] ?? '');
			if ($renewalOriginalId !== $payloadOriginalTransactionId
				|| ($renewalProductId !== '' && !$this->isAllowedProductId($renewalProductId))
				|| strcasecmp($renewalEnvironment, $environment) !== 0)
			{
				return $this->apiError('Renewal information does not match the transaction.', 'renewal_mismatch');
			}
		}

		try
		{
			AppStoreTransactionStore::ensureTables();
			$record = AppStoreTransactionStore::record((int) $visitor->user_id, $transaction, $renewalInfo, hash('sha256', $signedTransaction));
			if (!IosMembershipSynchronizer::syncUser((int) $visitor->user_id))
			{
				throw new \RuntimeException('Premium permission synchronization needs retry.');
			}
		}
		catch (\DomainException $e)
		{
			return $this->apiError('This purchase cannot be linked to this account.', $e->getMessage(), null, 409);
		}
		catch (\Throwable $e)
		{
			return $this->apiError('Purchase storage is temporarily unavailable.', 'purchase_storage_unavailable', null, 503);
		}
		$isActive = (bool) $record['active'] && ((int) $record['expires_date'] === 0 || (int) $record['expires_date'] > \XF::$time);

		return $this->apiResult([
			'success' => $isActive,
			'status' => $isActive ? 'verified_active' : (!empty($record['revoked']) ? 'verified_revoked' : 'verified_expired'),
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
			'expiration_time' => (int) $record['expires_date'] ?: null,
			'expirationTime' => (int) $record['expires_date'] ?: null,
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
			return [
				'valid' => false,
				'code' => 'transaction_verification_failed',
				'message' => 'Transaction could not be verified.'
			];
		}
	}

	protected function decodeAndVerifyJws(string $jws): array
	{
		if (strlen($jws) > 131072) { throw new \RuntimeException('JWS too large.'); }
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
		if (!isset($header['x5c']) || !is_array($header['x5c']) || count($header['x5c']) !== 3)
		{
			throw new \RuntimeException('Missing JWS certificate chain.');
		}

		$certificates = $this->decodeCertificateChain($header['x5c']);
		$signedDate = (int) ($payload['signedDate'] ?? 0);
		if ($signedDate <= 0 || $signedDate > (time() + 300) * 1000)
		{
			throw new \RuntimeException('Invalid JWS signing date.');
		}
		$this->verifyCertificateChain($certificates, (int) floor($signedDate / 1000));

		$publicKey = openssl_pkey_get_public($certificates[0]);
		if (!$publicKey)
		{
			throw new \RuntimeException('Could not read JWS public key.');
		}
		$keyDetails = openssl_pkey_get_details($publicKey);
		if (!$keyDetails || $keyDetails['type'] !== OPENSSL_KEYTYPE_EC
			|| ($keyDetails['ec']['curve_name'] ?? '') !== 'prime256v1')
		{
			throw new \RuntimeException('App Store ES256 requires a P-256 signing key.');
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

	protected function verifyCertificateChain(array $certificates, int $signedAt): void
	{
		if (count($certificates) !== 3)
		{
			throw new \RuntimeException('Unexpected Apple certificate chain length.');
		}
		$leaf = openssl_x509_parse($certificates[0]);
		$intermediate = openssl_x509_parse($certificates[1]);
		if (!isset($leaf['extensions']['1.2.840.113635.100.6.11.1'])
			|| !isset($intermediate['extensions']['1.2.840.113635.100.6.2.1']))
		{
			throw new \RuntimeException('Certificate is not an App Store signing certificate.');
		}
		if (strpos((string) ($intermediate['extensions']['basicConstraints'] ?? ''), 'CA:TRUE') === false
			|| strpos((string) ($leaf['extensions']['basicConstraints'] ?? ''), 'CA:TRUE') !== false)
		{
			throw new \RuntimeException('Invalid App Store certificate constraints.');
		}
		foreach ($certificates AS $certificate)
		{
			$parsed = openssl_x509_parse($certificate);
			if (!$parsed || ($parsed['validFrom_time_t'] ?? 0) > $signedAt || ($parsed['validTo_time_t'] ?? 0) < $signedAt)
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

		$bundledRoot = dirname(__DIR__, 2) . '/Resources/AppleRootCA-G3.pem';
		if (is_readable($bundledRoot))
		{
			return (string) file_get_contents($bundledRoot);
		}

		return '';
	}

	protected function isAllowedEnvironment(string $environment): bool
	{
		$allowed = trim((string) getenv('EKITAPLIGIM_APPSTORE_ENVIRONMENT'));
		if ($allowed === '' || strcasecmp($allowed, 'Both') === 0)
		{
			return in_array($environment, ['Production', 'Sandbox'], true);
		}

		return strcasecmp($environment, $allowed) === 0;
	}

	protected function allowedProductIds(): array
	{
		$shippedProducts = [
			'com.ekitapligim.app.premium.monthly',
			'com.ekitapligim.app.premium.three_months',
			'com.ekitapligim.app.premium.six_months',
			'com.ekitapligim.app.premium.yearly',
			'com.ekitapligim.app.premium.yearly_once',
			'com.ekitapligim.app.premium.lifetime',
			'ekitapligim.premium.monthly',
			'ekitapligim.premium.yearly'
		];
		$configuredProducts = trim((string) getenv('EKITAPLIGIM_IOS_PRODUCT_IDS'));
		if ($configuredProducts === '')
		{
			return $shippedProducts;
		}

		return array_values(array_unique(array_merge(
			$shippedProducts,
			array_filter(array_map('trim', explode(',', $configuredProducts)))
		)));
	}

	protected function isAllowedProductId(string $productId): bool
	{
		return in_array($productId, $this->allowedProductIds(), true);
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

