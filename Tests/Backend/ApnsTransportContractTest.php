<?php
declare(strict_types=1);

// Intercept only cURL inside the service namespace: no Apple network traffic.
namespace Ekitapligim\IosApi\Service {
    final class CurlFixture {
        public static string $url = '', $body = '';
        public static array $options = [];
        public static int $status = 200, $errno = 0;
    }
    function curl_init(string $url) { CurlFixture::$url = $url; return new \stdClass(); }
    function curl_setopt_array($handle, array $options) { CurlFixture::$options = $options; return true; }
    function curl_exec($handle) {
        $callback = CurlFixture::$options[CURLOPT_HEADERFUNCTION];
        $header = "apns-id: 9BDD5C13-651C-2B1A-0623-0EAA707D975E\r\n";
        if ($callback($handle, $header) !== strlen($header)) { throw new \RuntimeException('Header length changed'); }
        return CurlFixture::$errno ? false : CurlFixture::$body;
    }
    function curl_getinfo($handle, $name) { return CurlFixture::$status; }
    function curl_errno($handle) { return CurlFixture::$errno; }
    function curl_close($handle) {}
}
namespace {
    use Ekitapligim\IosApi\Service\ApnsPush;
    use Ekitapligim\IosApi\Service\CurlFixture;
    if (!defined('CURLOPT_HTTP_VERSION')) {
        throw new RuntimeException('This offline contract test needs PHP cURL constants. Use a curl-enabled PHP runtime; requests remain mocked.');
    }
    final class XF {
        public static object $options;
        public static array $errors = [];
        public static function options() { return self::$options; }
        public static function logError($message) { self::$errors[] = $message; }
    }
    require __DIR__.'/../../Backend/IosApi-addon/Service/ApnsPush.php';
    final class TransportHarness extends ApnsPush {
        public static function jwt(): ?string { return parent::generateJwt(); }
        public static function request(string $jwt): array {
            return parent::sendSingle('synthetic-device-token', '{"aps":{"alert":"fixture"}}', $jwt);
        }
    }
    function check(bool $ok, string $message): void { if (!$ok) throw new RuntimeException($message); }
    function decodeBase64Url(string $value): string {
        $decoded = base64_decode(strtr($value, '-_', '+/'), true);
        if ($decoded === false) throw new RuntimeException('Invalid fixture base64url');
        return $decoded;
    }
    function derInteger(string $bytes): string {
        $bytes = ltrim($bytes, "\0");
        if ($bytes === '') $bytes = "\0";
        if (ord($bytes[0]) & 0x80) $bytes = "\0".$bytes;
        return "\x02".chr(strlen($bytes)).$bytes;
    }
    $keyPath = tempnam(sys_get_temp_dir(), 'ek-apns-test-key-');
    $configPath = tempnam(sys_get_temp_dir(), 'ek-apns-test-config-');
    $randomPath = tempnam(sys_get_temp_dir(), 'ek-apns-test-random-');
    $previousRandomFile = getenv('RANDFILE');
    putenv('RANDFILE='.$randomPath);
    try {
        file_put_contents($configPath, "[req]\ndistinguished_name=dn\n[dn]\n");
        $key = openssl_pkey_new(['private_key_bits' => 2048, 'private_key_type' => OPENSSL_KEYTYPE_EC,
            'curve_name' => 'prime256v1', 'config' => $configPath]);
        check($key !== false && openssl_pkey_export($key, $pem, null, ['config' => $configPath]), 'Cannot generate isolated test key');
        file_put_contents($keyPath, $pem);
        XF::$options = (object) ['ekitapligimApnsKeyId' => 'TESTKEY123', 'ekitapligimApnsTeamId' => 'TESTTEAM12',
            'ekitapligimApnsKeyPath' => $keyPath, 'ekitapligimApnsTopic' => 'com.ekitapligim.app',
            'ekitapligimApnsEnvironment' => 'production'];
        $jwt = TransportHarness::jwt();
        check(is_string($jwt), 'APNs JWT generation failed');
        $parts = explode('.', $jwt);
        check(count($parts) === 3, 'JWT shape changed');
        check(json_decode(decodeBase64Url($parts[0]), true) === ['alg' => 'ES256', 'kid' => 'TESTKEY123'], 'JWT header changed');
        $claims = json_decode(decodeBase64Url($parts[1]), true);
        check($claims['iss'] === 'TESTTEAM12' && abs(time() - $claims['iat']) <= 2, 'JWT claims changed');
        $signature = decodeBase64Url($parts[2]);
        check(strlen($signature) === 64, 'ES256 signature must be 64 JOSE bytes');
        $integers = derInteger(substr($signature, 0, 32)).derInteger(substr($signature, 32));
        $der = "\x30".chr(strlen($integers)).$integers;
        $details = openssl_pkey_get_details($key);
        check(openssl_verify($parts[0].'.'.$parts[1], $der, $details['key'], OPENSSL_ALGO_SHA256) === 1, 'Actual APNs JWT signature failed verification');
        echo "PASS: actual APNs JWT retains ES256/key/team claims and passes real P-256 signature verification.\n";

        $response = TransportHarness::request($jwt);
        check($response['status'] === 200, 'Successful response changed');
        check(CurlFixture::$url === 'https://api.push.apple.com/3/device/synthetic-device-token', 'Production endpoint changed');
        $options = CurlFixture::$options;
        check($options[CURLOPT_HTTP_VERSION] === CURL_HTTP_VERSION_2_0 && $options[CURLOPT_POST] === true, 'HTTP/2 POST changed');
        check($options[CURLOPT_POSTFIELDS] === '{"aps":{"alert":"fixture"}}' && $options[CURLOPT_TIMEOUT] === 10, 'Payload/timeout changed');
        check($options[CURLOPT_HTTPHEADER] === ['authorization: bearer '.$jwt, 'apns-topic: com.ekitapligim.app',
            'apns-push-type: alert', 'apns-priority: 10', 'content-type: application/json'], 'APNs headers changed');
        check(!isset($options[CURLOPT_SSL_VERIFYPEER]) && !isset($options[CURLOPT_FOLLOWLOCATION]), 'TLS or redirect policy weakened');
        XF::$options->ekitapligimApnsEnvironment = 'development';
        TransportHarness::request($jwt);
        check(CurlFixture::$url === 'https://api.development.push.apple.com/3/device/synthetic-device-token', 'Existing development endpoint changed');
        echo "PASS: existing environment/topic, HTTP/2 POST, payload, bearer, TLS defaults and priority remain intact.\n";

        CurlFixture::$status = 410;
        $timestamp = 1791788400123;
        CurlFixture::$body = json_encode(['reason' => 'Unregistered', 'timestamp' => $timestamp]);
        $response = TransportHarness::request($jwt);
        check($response === ['status' => 410, 'reason' => 'Unregistered',
            'apns_id' => '9BDD5C13-651C-2B1A-0623-0EAA707D975E', 'timestamp' => $timestamp], 'Actual timestamp/body/header decoding failed');
        foreach ([null, 'bad', 0, -1] as $invalidTimestamp) {
            CurlFixture::$body = json_encode(['reason' => 'Unregistered', 'timestamp' => $invalidTimestamp]);
            check(TransportHarness::request($jwt)['timestamp'] === null, 'Invalid timestamp accepted');
        }
        CurlFixture::$body = '<html>gateway error</html>'; CurlFixture::$status = 503;
        check(TransportHarness::request($jwt)['reason'] === '', 'Non-JSON failure invented reason');
        CurlFixture::$status = 0; CurlFixture::$errno = 28;
        check(TransportHarness::request($jwt)['reason'] === 'curl_28', 'cURL transport failure lost');
        check(XF::$errors === [], 'Transport emitted duplicate/raw token diagnostics');
        echo "PASS: actual transport decodes APNs millisecond timestamps, rejects malformed ones and retains safe transport error classification.\n";
    } finally {
        foreach ([$keyPath, $configPath, $randomPath] as $path) { if (is_file($path)) unlink($path); }
        putenv($previousRandomFile === false ? 'RANDFILE' : 'RANDFILE='.$previousRandomFile);
    }
    echo "ALL APNS TRANSPORT CONTRACT TESTS PASSED (temporary test key, zero network requests).\n";
}
