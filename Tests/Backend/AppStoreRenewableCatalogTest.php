<?php
// Exercises verification + notifications + durable delivery for every current
// interval. Fixture transport substitutes signatures; signature tests run separately.
require __DIR__ . '/AppStoreControllerTest.php';
use Ekitapligim\IosApi\Service\AppStoreTransactionStore as Store;

foreach (['monthly' => 1, 'quarterly' => 3, 'semiannual' => 6, 'yearly' => 12] as $suffix => $months) {
    XF::$database = new AppStoreTestDb();
    XF::$groups = new TestGroupChanges();
    XF::$time = strtotime('2030-01-01 12:00:00 UTC');
    Store::ensureTables();
    $verify = new VerifyController();
    $verify->input = ['prepare_purchase' => true, 'account_name' => 'tester'];
    $prepared = $verify->actionPost();
    $product = 'com.ekitapligim.app.premium.' . $suffix;
    check(in_array($product, $prepared['supported_product_ids'], true), "$suffix preparation advertises server support");
    $tx = purchaseFixture('first-' . $suffix, 'chain-' . $suffix);
    $tx['productId'] = $product;
    $tx['appAccountToken'] = $prepared['app_account_token'];
    $tx['purchaseDate'] = XF::$time * 1000;
    $tx['expiresDate'] = strtotime("+$months months", XF::$time) * 1000;
    $verify->input = ['signed_transaction' => 'tx', 'product_id' => $product, 'account_name' => 'tester'];
    $verify->payloads['tx'] = $tx;
    $first = $verify->actionPost();
    check($first['success'] && $first['expiration_time'] === (int) ($tx['expiresDate'] / 1000), "$suffix grants signed period");
    check($verify->actionPost() === $first, "$suffix verification is idempotent");
    $context = Store::purchaseContext(11);
    check($context['has_active_subscription'] && !$context['has_fixed_term'], "$suffix classified as renewing");
    $verify->payloads['tx']['type'] = 'Non-Renewing Subscription';
    check($verify->actionPost()['error'] === 'product_type_mismatch', "$suffix rejects wrong signed type");
    $verify->payloads['tx'] = $tx;

    // Apple starts the next paid period on expiration. Notifications must deliver
    // access even when the app is closed, without extending dates on replay.
    XF::$time = (int) ($tx['expiresDate'] / 1000);
    $next = $tx;
    $next['transactionId'] = 'renewal-' . $suffix;
    $next['purchaseDate'] = XF::$time * 1000;
    $next['signedDate'] = XF::$time * 1000;
    $next['expiresDate'] = strtotime("+$months months", XF::$time) * 1000;
    $notification = new NotificationController();
    $notification->input = ['signedPayload' => 'event'];
    $notification->payloads = ['event' => ['notificationUUID' => 'renew-' . $suffix, 'notificationType' => 'DID_RENEW',
        'data' => ['bundleId' => 'com.ekitapligim.app', 'environment' => 'Sandbox', 'signedTransactionInfo' => 'tx']], 'tx' => $next];
    check($notification->actionPost()['success'], "$suffix renewal delivered while app is closed");
    check($notification->actionPost()['success'], "$suffix renewal notification replay succeeds");
    $verify->payloads['tx'] = $next;
    $renewed = $verify->actionPost();
    check($renewed['success'] && $renewed['expiration_time'] === (int) ($next['expiresDate'] / 1000), "$suffix renewal restores exact new period");
    check((int) XF::db()->fetchOne('SELECT COUNT(*) FROM xf_ekitapligim_mobile_appstore_entitlement') === 2, "$suffix no duplicate grants");

    $renewal = ['originalTransactionId' => $next['originalTransactionId'], 'autoRenewProductId' => $product,
        'environment' => 'Sandbox', 'signedDate' => $next['signedDate'] + 1000, 'autoRenewStatus' => 0];
    $verify->input['signed_renewal_info'] = 'renewal';
    $verify->payloads['renewal'] = $renewal;
    check($verify->actionPost()['success'], "$suffix cancellation preserves paid access");
    XF::$time = (int) ($next['expiresDate'] / 1000);
    check(!$verify->actionPost()['is_premium'], "$suffix cancelled subscription expires at signed boundary");

    $verify->payloads['renewal']['signedDate'] = XF::$time * 1000;
    $verify->payloads['renewal']['gracePeriodExpiresDate'] = (XF::$time + 3600) * 1000;
    check($verify->actionPost()['is_premium'], "$suffix verified grace grants access");
    $verify->payloads['tx']['revocationDate'] = XF::$time * 1000;
    $verify->payloads['tx']['signedDate'] = XF::$time * 1000;
    check(!$verify->actionPost()['is_premium'], "$suffix refund overrides grace");
}
echo "Renewable catalog: 4 intervals passed purchase, type, renewal, restore, replay, cancellation, expiry, grace and refund checks.\n";
