$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $root

function Require-Text([string]$Path, [string]$Text) {
    $content = Get-Content -Raw -LiteralPath $Path
    if ($content -notmatch [regex]::Escape($Text)) {
        throw "$Path is missing Premium contract control: $Text"
    }
}

$expectedProducts = @("com.ekitapligim.app.premium.monthly", "com.ekitapligim.app.premium.yearly")
$legacyProducts = @("ekitapligim.premium.monthly", "ekitapligim.premium.yearly")
$configuration = Get-Content -Raw -LiteralPath "App/Ekitapligim/StoreKit/Ekitapligim.storekit" | ConvertFrom-Json
$subscriptions = @($configuration.subscriptionGroups.subscriptions)
$configuredProducts = @($subscriptions.productID | Sort-Object)
if (Compare-Object ($expectedProducts | Sort-Object) $configuredProducts) {
    throw "StoreKit product IDs do not match the client/backend Premium contract."
}
if (@($subscriptions.groupNumber | Sort-Object -Unique).Count -ne 1) {
    throw "Monthly and yearly Premium products must use the same subscription service level."
}

foreach ($product in $expectedProducts) {
    Require-Text "App/Ekitapligim/Purchases/StoreKitPurchaseService.swift" $product
    Require-Text "Backend/IosApi-addon/Api/Controller/AppStoreVerify.php" $product
}

foreach ($product in $legacyProducts) {
    Require-Text "App/Ekitapligim/Purchases/StoreKitPurchaseService.swift" $product
    Require-Text "Backend/IosApi-addon/Api/Controller/AppStoreVerify.php" $product
}

foreach ($control in @('$shippedProducts', 'array_unique', 'array_merge')) {
    Require-Text "Backend/IosApi-addon/Api/Controller/AppStoreVerify.php" $control
    Require-Text "Backend/MobileApi-addon/Api/Controller/AppStoreVerify.php" $control
}

foreach ($control in @(
    "Transaction.currentEntitlements",
    "Transaction.updates",
    "Product.SubscriptionInfo.Status.updates",
    "signedRenewalInfo",
    "PurchaseVerificationPolicy.requireActive",
    "remain unfinished for redelivery"
)) {
    Require-Text "App/Ekitapligim/Purchases/StoreKitPurchaseService.swift" $control
}

foreach ($control in @(
    "signed_renewal_info",
    "gracePeriodExpiresDate",
    "original_transaction_already_linked",
    "GET_LOCK",
    "EKITAPLIGIM_APPSTORE_ENVIRONMENT",
    "EKITAPLIGIM_APPLE_ROOT_CA",
    "Resources/AppleRootCA-G3.pem"
)) {
    Require-Text "Backend/IosApi-addon/Api/Controller/AppStoreVerify.php" $control
}

$appleRootPath = "Backend/IosApi-addon/Resources/AppleRootCA-G3.pem"
$appleRootBase64 = (Get-Content -Raw -LiteralPath $appleRootPath) `
    -replace '-----BEGIN CERTIFICATE-----', '' `
    -replace '-----END CERTIFICATE-----', '' `
    -replace '\s', ''
$appleRoot = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
    [Convert]::FromBase64String($appleRootBase64)
)
$appleRootFingerprint = $appleRoot.GetCertHashString([System.Security.Cryptography.HashAlgorithmName]::SHA256)
if ($appleRootFingerprint -ne "63343ABFB89A6A03EBB57E9B3F5FA7BE7C4F5C756F3017B3A8C488C3653E9179") {
    throw "Bundled Apple Root CA - G3 fingerprint does not match Apple's published certificate."
}

foreach ($control in @("signedRenewalInfo", "AppStoreEntitlementPolicy::isActive")) {
    Require-Text "Backend/IosApi-addon/Api/Controller/AppStoreNotifications.php" $control
}

foreach ($control in @("gracePeriodExpiresDate", "revocationDate", "missing expiration", "return false")) {
    Require-Text "Backend/IosApi-addon/Service/AppStoreEntitlementPolicy.php" $control
}

Require-Text "App/Ekitapligim/Features/PremiumView.swift" "manageSubscriptionsSheet"
Require-Text "project.yml" "storeKitConfiguration: App/Ekitapligim/StoreKit/Ekitapligim.storekit"
Require-Text "App/Ekitapligim/Support/PrivacyInfo.xcprivacy" "NSPrivacyCollectedDataTypePurchaseHistory"

Write-Host "Premium contract audit completed: products, StoreKit lifecycle, server verification, ownership, grace period, cancellation UI, and privacy controls match."
