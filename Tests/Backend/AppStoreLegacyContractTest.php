<?php
// Real controllers with verified fixture transport; no accounts, payments or network.
require __DIR__ . '/AppStoreControllerTest.php';
use Ekitapligim\IosApi\Service\AppStoreTransactionStore as Store;
XF::$database = new AppStoreTestDb();
XF::$groups = new TestGroupChanges();
XF::$time = strtotime('2030-02-01 12:00:00 UTC');
Store::ensureTables();
$controller = new VerifyController();
$controller->input = ['prepare_purchase' => true, 'account_name' => 'tester'];
$preparation = $controller->actionPost();
check($preparation['success'] === true && is_string($preparation['app_account_token']), 'Old preparation fields unchanged');
$fixtures = ['prepare' => $preparation];
foreach (['2030-01-01', '2030-02-01'] as $index => $date) {
    $tx = purchaseFixture('legacy-term-' . $index, 'legacy-original-' . $index);
    $tx['productId'] = 'com.ekitapligim.app.premium.three_months';
    $tx['type'] = 'Non-Renewing Subscription';
    $tx['purchaseDate'] = strtotime($date . ' 12:00:00 UTC') * 1000;
    $tx['signedDate'] = $tx['purchaseDate'];
    unset($tx['expiresDate']);
    // Old clients did not send account_name, appAccountToken or renewal JWS.
    $controller->payloads['legacy'] = $tx;
    $controller->input = ['signed_transaction' => 'legacy', 'product_id' => $tx['productId']];
    $response = $controller->actionPost();
    check($response['success'] === true && $response['is_premium'] === true, 'Old client purchase succeeds');
    check($response['expiration_time'] === $response['expirationTime'], 'Both shipped expiration keys stay equal');
    check($controller->actionPost() === $response, 'Old-client retry returns same dates and values');
    $fixtures['term' . $index] = $response;
}
check($fixtures['term1']['expiration_time'] === strtotime('2030-07-01 12:00:00 UTC'), 'Old client receives carried date');
$lifetime = purchaseFixture('legacy-life', 'legacy-life-original');
$lifetime['productId'] = 'com.ekitapligim.app.premium.lifetime';
$lifetime['type'] = 'Non-Consumable';
unset($lifetime['expiresDate']);
$controller->payloads['life'] = $lifetime;
$controller->input = ['signed_transaction' => 'life', 'product_id' => $lifetime['productId']];
$fixtures['lifetime'] = $controller->actionPost();
check($fixtures['lifetime']['success'] && $fixtures['lifetime']['expiration_time'] === null, 'Old lifetime restore contract unchanged');
$controller->input = ['prepare_purchase' => true, 'account_name' => 'tester'];
$fixtures['prepare_lifetime'] = $controller->actionPost();
check($fixtures['prepare_lifetime']['success'] && $fixtures['prepare_lifetime']['has_lifetime'], 'New flags do not break old preparation');
check($fixtures['prepare_lifetime']['app_account_token'] === $preparation['app_account_token'], 'Account token stable across upgrade and purchases');
if (isset($argv[1])) { file_put_contents($argv[1], json_encode($fixtures, JSON_THROW_ON_ERROR)); }
echo "App Store old-client contract: preparation, omitted optional fields, repeat verification, carried expiration and lifetime passed.\n";
