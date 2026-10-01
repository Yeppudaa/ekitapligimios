<?php
namespace Ekitapligim\MobileApi\Api\Controller { class AbstractMobileController {} }
namespace {
    require __DIR__ . '/../../Backend/IosApi-addon/Api/Controller/AppStoreVerify.php';
    class SignatureVerifier extends \Ekitapligim\IosApi\Api\Controller\AppStoreVerify {
        public string $root = '';
        protected function appleRootCertificate(): string { return $this->root; }
        public function decode(string $value): array { return $this->decodeAndVerifyJws($value); }
        public function chain(array $value, int $date): void { $this->verifyCertificateChain($value, $date); }
    }
    function expectReject(callable $operation, string $label): void {
        try { $operation(); } catch (\RuntimeException $e) { return; }
        throw new \LogicException($label);
    }
    function b64(string $value): string { return rtrim(strtr(base64_encode($value), '+/', '-_'), '='); }
    function certificate($key, $issuer, $issuerKey, $config, $extension, int $serial): string {
        $options = ['config' => $config, 'digest_alg' => 'sha256', 'x509_extensions' => $extension];
        $csr = openssl_csr_new(['commonName' => 'AppStore audit ' . $serial], $key, $options);
        $cert = openssl_csr_sign($csr, $issuer, $issuerKey, 2, $options, $serial);
        if (!$cert || !openssl_x509_export($cert, $pem)) { throw new \RuntimeException('Fixture certificate failed'); }
        return $pem;
    }
    function signPayload(array $payload, array $certs, $key): string {
        $chain = array_map(fn($pem) => preg_replace('/-----[^\n]+-----|\s/', '', $pem), $certs);
        $unsigned = b64(json_encode(['alg' => 'ES256', 'x5c' => $chain])) . '.' . b64(json_encode($payload));
        if (!openssl_sign($unsigned, $der, $key, OPENSSL_ALGO_SHA256)) { throw new \RuntimeException('Fixture signing failed'); }
        $rLength = ord($der[3]);
        $r = substr($der, 4, $rLength);
        $s = substr($der, 6 + $rLength, ord($der[5 + $rLength]));
        $signature = str_pad(ltrim($r, "\0"), 32, "\0", STR_PAD_LEFT) . str_pad(ltrim($s, "\0"), 32, "\0", STR_PAD_LEFT);
        return $unsigned . '.' . b64($signature);
    }
    $configPath = tempnam(sys_get_temp_dir(), 'ek-appstore-audit-');
    file_put_contents($configPath, "[req]\ndistinguished_name=dn\n[dn]\n[root]\nbasicConstraints=critical,CA:TRUE\nkeyUsage=critical,keyCertSign,cRLSign\n"
        . "[intermediate]\nbasicConstraints=critical,CA:TRUE\nkeyUsage=critical,keyCertSign,cRLSign\n1.2.840.113635.100.6.2.1=DER:05:00\n"
        . "[leaf]\nbasicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature\n1.2.840.113635.100.6.11.1=DER:05:00\n"
        . "[wrong_leaf]\nbasicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature\n");
    try {
        $options = ['config' => $configPath, 'private_key_bits' => 2048, 'private_key_type' => OPENSSL_KEYTYPE_EC, 'curve_name' => 'prime256v1'];
        $rootKey = openssl_pkey_new($options);
        $intermediateKey = openssl_pkey_new($options);
        $leafKey = openssl_pkey_new($options);
        $root = certificate($rootKey, null, $rootKey, $configPath, 'root', 1);
        $intermediate = certificate($intermediateKey, $root, $rootKey, $configPath, 'intermediate', 2);
        $leaf = certificate($leafKey, $intermediate, $intermediateKey, $configPath, 'leaf', 3);
        $verifier = new SignatureVerifier();
        $verifier->root = $root;
        $payload = ['signedDate' => time() * 1000, 'transactionId' => 'fixture'];
        $valid = signPayload($payload, [$leaf, $intermediate, $root], $leafKey);
        if ($verifier->decode($valid)['payload'] !== $payload) { throw new \RuntimeException('Valid signature rejected'); }
        $parts = explode('.', $valid);
        $parts[1] = b64(json_encode($payload + ['revocationDate' => 123]));
        expectReject(fn() => $verifier->decode(implode('.', $parts)), 'Tampered payload accepted');
        $wrong = certificate($leafKey, $intermediate, $intermediateKey, $configPath, 'wrong_leaf', 4);
        expectReject(fn() => $verifier->decode(signPayload($payload, [$wrong, $intermediate, $root], $leafKey)), 'Non-App-Store certificate accepted');
        expectReject(fn() => $verifier->decode(signPayload($payload, [$leaf, $root], $leafKey)), 'Short chain accepted');
        expectReject(fn() => $verifier->decode(signPayload(['signedDate' => (time() + 600) * 1000], [$leaf, $intermediate, $root], $leafKey)), 'Future signature accepted');
        $certificateData = openssl_x509_parse($leaf);
        expectReject(fn() => $verifier->chain([$leaf, $intermediate, $root], $certificateData['validTo_time_t'] + 1), 'Certificate outside signing lifetime accepted');
        $verifier->root = file_get_contents(__DIR__ . '/../../Backend/IosApi-addon/Resources/AppleRootCA-G3.pem');
        expectReject(fn() => $verifier->decode($valid), 'Self-issued chain accepted under Apple root');
        echo "App Store crypto: 7 real ES256 signature, chain, OID, trust and signing-date scenarios passed.\n";
    } finally { unlink($configPath); }
}
