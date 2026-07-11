param(
    [Parameter(Mandatory = $true)]
    [string]$AddonPath,

    [switch]$CreateZip,

    [switch]$BumpVersion,

    [string]$OutputDirectory = ""
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$sourceRoot = Join-Path $repoRoot "Backend/MobileApi-addon"
$targetRoot = Resolve-Path $AddonPath

function Write-Step($Message) {
    Write-Host "==> $Message"
}

function Assert-Path($Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Path not found: $Path"
    }
}

function Update-FileText($Path, [scriptblock]$Transform) {
    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }
    $content = Get-Content -Raw -LiteralPath $Path
    $updated = & $Transform $content
    if ($updated -ne $content) {
        Set-Content -LiteralPath $Path -Value $updated -Encoding UTF8
    }
}

Assert-Path (Join-Path $targetRoot "addon.json")
Assert-Path (Join-Path $targetRoot "_data/routes.xml")
Assert-Path (Join-Path $sourceRoot "routes-fragment.xml")

Write-Step "Copying API controllers"
$sourceControllerDir = Join-Path $sourceRoot "Api/Controller"
$sourceServiceDir = Join-Path $sourceRoot "Service"
$targetApiDir = Join-Path $targetRoot "Api/Controller"
$targetPubDir = Join-Path $targetRoot "Pub/Controller"
$targetServiceDir = Join-Path $targetRoot "Service"
$sourceCliDir = Join-Path $sourceRoot "Cli/Command"
$targetCliDir = Join-Path $targetRoot "Cli/Command"
New-Item -ItemType Directory -Force -Path $targetApiDir | Out-Null
New-Item -ItemType Directory -Force -Path $targetPubDir | Out-Null
New-Item -ItemType Directory -Force -Path $targetServiceDir | Out-Null
New-Item -ItemType Directory -Force -Path $targetCliDir | Out-Null
Copy-Item -LiteralPath (Join-Path $sourceRoot "Pub/Controller/PublicEndpointTrait.php") -Destination (Join-Path $targetPubDir "PublicEndpointTrait.php") -Force

Get-ChildItem -LiteralPath $sourceControllerDir -Filter "*.php" | ForEach-Object {
    $apiTarget = Join-Path $targetApiDir $_.Name
    Copy-Item -LiteralPath $_.FullName -Destination $apiTarget -Force
}

if (Test-Path -LiteralPath $sourceServiceDir) {
    Get-ChildItem -LiteralPath $sourceServiceDir -Filter "*.php" | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $targetServiceDir $_.Name) -Force
    }
}
if (Test-Path -LiteralPath $sourceCliDir) {
    Get-ChildItem -LiteralPath $sourceCliDir -Filter "*.php" | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $targetCliDir $_.Name) -Force
    }
}

Write-Step "Applying XenForo 2.3 controller compatibility fixes"
Get-ChildItem -LiteralPath $targetApiDir -Filter "*.php" | ForEach-Object {
    $content = Get-Content -Raw -LiteralPath $_.FullName
    $updated = $content -replace '\$this->db\(\)', '\XF::db()'
    if ($updated -ne $content) {
        Set-Content -LiteralPath $_.FullName -Value $updated -Encoding UTF8
    }
}

Write-Step "Applying local registration extension compatibility"
foreach ($registrationController in @("AuthRegister.php", "AuthGoogle.php")) {
    $registrationPath = Join-Path $targetApiDir $registrationController
    Update-FileText $registrationPath {
        param($content)
        if ($content -match "'style_variation'\s*=>") { return $content }
        return $content -replace "('timezone'\s*=>\s*[^,]+,)", "`$1`r`n`t`t`t'style_variation' => 'default',"
    }
}

$abstractControllerPath = Join-Path $targetApiDir "AbstractMobileController.php"
Update-FileText $abstractControllerPath {
    param($content)
    return $content -replace "apiError\('Login required\.', 'login_required'\)", "apiError('Login required.', 'login_required', null, 401)"
}

Write-Step "Wiring iOS App Store entitlements into premium checks"
$abstractControllerPath = Join-Path $targetApiDir "AbstractMobileController.php"
Update-FileText $abstractControllerPath {
    param($content)
    $updated = $content
    if ($updated -notmatch "use Ekitapligim\\MobileApi\\Service\\IosEntitlement;") {
        $updated = $updated -replace "use Ekitapligim\\MobileApi\\Service\\CatalogQuery;\r?\n", "use Ekitapligim\MobileApi\Service\CatalogQuery;`r`nuse Ekitapligim\MobileApi\Service\IosEntitlement;`r`n"
    }
    if ($updated -notmatch 'IosEntitlement::hasActiveEntitlement\(\$user\)') {
        $updated = $updated -replace 'if \(method_exists\(\$user, ''isBookPremiumMember''\) && \$user->isBookPremiumMember\(\)\)\r?\n\t\t\{\r?\n\t\t\treturn true;\r?\n\t\t\}', "if (method_exists(`$user, 'isBookPremiumMember') && `$user->isBookPremiumMember())`r`n`t`t{`r`n`t`t`treturn true;`r`n`t`t}`r`n`t`tif (IosEntitlement::hasActiveEntitlement(`$user))`r`n`t`t{`r`n`t`t`treturn true;`r`n`t`t}"
    }
    if ($updated -notmatch "use Ekitapligim\\MobileApi\\Service\\MobileSession;") {
        $updated = $updated -replace "namespace Ekitapligim\\MobileApi\\Api\\Controller;\r?\n", "namespace Ekitapligim\MobileApi\Api\Controller;`r`n`r`nuse Ekitapligim\MobileApi\Service\MobileSession;`r`n"
    }
    if ($updated -notmatch 'function buildMobileAuthPayload\(') {
        $anchor = "`tprotected function assertBook(int `$threadId): Book"
        $helper = @'
	protected function buildMobileAuthPayload(\XF\Entity\User $user, ?array $tokens = null): array
	{
		$tokens = $tokens ?: MobileSession::issue(
			$user,
			$this->request->getIp(),
			(string) $this->request->getServer('HTTP_USER_AGENT', '')
		);
		$roles = $this->mobileUserRolePayload($user);

		return [
			'access_token' => $tokens['access_token'],
			'accessToken' => $tokens['access_token'],
			'refresh_token' => $tokens['refresh_token'],
			'refreshToken' => $tokens['refresh_token'],
			'user' => [
				'user_id' => (int) $user->user_id,
				'userId' => (int) $user->user_id,
				'username' => (string) $user->username,
				'email' => (string) $user->email,
				'is_premium' => (bool) $roles['is_premium'],
				'isPremium' => (bool) $roles['isPremium'],
				'premium_plan_name' => (bool) $roles['is_premium'] ? $roles['role_label'] : 'Standart Üye',
				'premiumPlanName' => (bool) $roles['isPremium'] ? $roles['roleLabel'] : 'Standart Üye',
				'role' => $roles,
			],
		];
	}

'@
        $updated = $updated.Replace($anchor, $helper + $anchor)
    }
    return $updated
}

Write-Step "Migrating all mobile auth responses to revocable sessions"
foreach ($authControllerName in @("AuthRegister.php", "AuthGoogle.php")) {
    $authControllerPath = Join-Path $targetApiDir $authControllerName
    Update-FileText $authControllerPath {
        param($content)
        if ($content -match 'buildMobileAuthPayload\(') {
            return $content
        }
        $updated = [regex]::Replace(
            $content,
            '(?s)return \$this->apiResult\(\[\s*''access_token'' => ''xf_user:'' \. \$user->user_id,.*?\s*\]\);',
            'return $this->apiResult($this->buildMobileAuthPayload($user));',
            1
        )
        return [regex]::Replace(
            $updated,
            '(?s)protected function buildAuthPayload\(User \$user\): array\s*\{\s*return \[\s*''access_token'' => ''xf_user:'' \. \$user->user_id,.*?\s*\];\s*\}',
            "protected function buildAuthPayload(User `$user): array`r`n`t{`r`n`t`treturn `$this->buildMobileAuthPayload(`$user);`r`n`t}",
            1
        )
    }
}

Write-Step "Making premium-only catalog filtering fail closed"
$catalogQueryPath = Join-Path $targetServiceDir "CatalogQuery.php"
Update-FileText $catalogQueryPath {
    param($content)
    if ($content -match "Thread\.thread_id', 0") {
        return $content
    }
    $oldBlock = @'
		if (!empty($filters['premium_only']) && $this->columnExists('xf_xcu_book_thread', 'ebook_premium_only'))
		{
			$finder->where('ebook_premium_only', 1);
		}
'@
    $newBlock = @'
		if (!empty($filters['premium_only']))
		{
			if ($this->columnExists('xf_xcu_book_thread', 'ebook_premium_only'))
			{
				$finder->where('ebook_premium_only', 1);
			}
			else
			{
				$finder->where('Thread.thread_id', 0);
			}
		}
'@
    return $content.Replace($oldBlock, $newBlock)
}

Write-Step "Hardening book request input and rate limits"
$bookRequestsPath = Join-Path $targetApiDir "BookRequests.php"
Update-FileText $bookRequestsPath {
    param($content)
    if ($content -match "request_rate_limited") {
        return $content
    }
    $anchor = @'
		/** @var BookRequest $request */
'@
    $controls = @'
		if (mb_strlen($title) > 255 || mb_strlen($author) > 255 || mb_strlen($isbn) > 32 || mb_strlen($note) > 1000)
		{
			return $this->apiError('Book request fields are too long.', 'input_too_long', null, 400);
		}

		$latestRequestDate = (int) \XF::db()->fetchOne(
			'SELECT MAX(create_date) FROM xf_ekitap_book_request WHERE user_id = ?',
			[(int) $visitor->user_id]
		);
		if ($latestRequestDate > \XF::$time - 30)
		{
			return $this->apiError('Please wait before creating another book request.', 'request_rate_limited', null, 429);
		}

'@
    return $content.Replace($anchor, $controls + $anchor)
}

Write-Step "Aligning book comments with XenForo reply safety"
$bookCommentsPath = Join-Path $targetApiDir "BookComments.php"
Update-FileText $bookCommentsPath {
    param($content)
    $updated = $content
    if ($updated -notmatch 'use XF\\Service\\FloodCheckService;') {
        $updated = $updated -replace "use XF\\Mvc\\ParameterBag;\r?\n", "use XF\Mvc\ParameterBag;`r`nuse XF\Service\FloodCheckService;`r`n"
    }
    if ($updated -notmatch '\$replier->checkForSpam\(\);') {
        $updated = $updated -replace '(\$replier->setMessage\(\$message\);)', "`$1`r`n`t`t`t`$replier->checkForSpam();"
    }
    if ($updated -notmatch "checkFlooding\('post', \(int\) \`$visitor->user_id\)") {
        $floodControl = @'
			if (!$visitor->hasPermission('general', 'bypassFloodCheck'))
			{
				$floodChecker = $this->service(FloodCheckService::class);
				$timeRemaining = $floodChecker->checkFlooding('post', (int) $visitor->user_id);
				if ($timeRemaining)
				{
					return $this->apiError(
						(string) \XF::phrase('must_wait_x_seconds_before_performing_this_action', ['count' => $timeRemaining]),
						'comment_flooding',
						['retry_after' => (int) $timeRemaining, 'retryAfter' => (int) $timeRemaining],
						429
					);
				}
			}
'@
        $updated = $updated -replace '(\t\t\t\$post = \$replier->save\(\);)', ($floodControl + "`r`n`$1")
    }
    if ($updated -notmatch '\$replier->sendNotifications\(\);') {
        $updated = $updated -replace '(\$post = \$replier->save\(\);)', "`$1`r`n`t`t`t`$replier->sendNotifications();"
    }
    return $updated
}

Write-Step "Aligning routed action prefixes with XenForo dispatch"
$conversationsPath = Join-Path $targetApiDir "Conversations.php"
Update-FileText $conversationsPath {
    param($content)
    $updated = $content.Replace(
        'public function actionGetMessages(ParameterBag $params)',
        'public function actionMessages(ParameterBag $params)'
    )
    $updated = $updated.Replace(
        'public function actionPostReply(ParameterBag $params)',
        'public function actionReply(ParameterBag $params)'
    )
    return $updated
}
$membersPath = Join-Path $targetApiDir "Members.php"
Update-FileText $membersPath {
    param($content)
    $updated = $content.Replace(
        'public function actionPostFollow(ParameterBag $params)',
        'public function actionFollow(ParameterBag $params)'
    )
    $updated = $updated.Replace(
        'public function actionPostUnfollow(ParameterBag $params)',
        'public function actionUnfollow(ParameterBag $params)'
    )
    return $updated
}
$notificationsPath = Join-Path $targetApiDir "MeNotifications.php"
Update-FileText $notificationsPath {
    param($content)
    return $content.Replace(
        'public function actionPostMarkAll()',
        'public function actionMarkAll()'
    )
}

$readerAccessPath = Join-Path $targetApiDir "BookReaderAccess.php"
Update-FileText $readerAccessPath {
    param($content)
    $updated = $content
    if ($updated -notmatch "use Ekitapligim\\MobileApi\\Service\\IosEntitlement;") {
        $updated = $updated -replace "use XF\\Mvc\\ParameterBag;\r?\n", "use XF\Mvc\ParameterBag;`r`nuse Ekitapligim\MobileApi\Service\IosEntitlement;`r`n"
    }
    if ($updated -notmatch 'IosEntitlement::hasActiveEntitlement\(\$visitor\)') {
        $updated = $updated -replace 'if \(method_exists\(\$visitor, ''isBookPremiumMember''\) && \$visitor->isBookPremiumMember\(\)\)\r?\n\t\t\{\r?\n\t\t\treturn ''premium'';\r?\n\t\t\}', "if (method_exists(`$visitor, 'isBookPremiumMember') && `$visitor->isBookPremiumMember())`r`n`t`t{`r`n`t`t`treturn 'premium';`r`n`t`t}`r`n`t`tif (IosEntitlement::hasActiveEntitlement(`$visitor))`r`n`t`t{`r`n`t`t`treturn 'premium';`r`n`t`t}"
    }
    return $updated
}

$meSubscriptionPath = Join-Path $targetApiDir "MeSubscription.php"
Update-FileText $meSubscriptionPath {
    param($content)
    $updated = $content
    if ($updated -notmatch "use Ekitapligim\\MobileApi\\Service\\IosEntitlement;") {
        $updated = $updated -replace "namespace Ekitapligim\\MobileApi\\Api\\Controller;\r?\n", "namespace Ekitapligim\MobileApi\Api\Controller;`r`n`r`nuse Ekitapligim\MobileApi\Service\IosEntitlement;`r`n"
    }
    if ($updated -notmatch 'IosEntitlement::hasActiveEntitlement\(\$visitor\)') {
        $updated = $updated -replace 'if \(method_exists\(\$visitor, ''isBookPremiumMember''\) && \$visitor->isBookPremiumMember\(\)\)\r?\n\t\t\{\r?\n\t\t\treturn ''premium'';\r?\n\t\t\}', "if (method_exists(`$visitor, 'isBookPremiumMember') && `$visitor->isBookPremiumMember())`r`n`t`t{`r`n`t`t`treturn 'premium';`r`n`t`t}`r`n`t`tif (IosEntitlement::hasActiveEntitlement(`$visitor))`r`n`t`t{`r`n`t`t`treturn 'premium';`r`n`t`t}"
    }
    if ($updated -notmatch 'IosEntitlement::expirationTime\(\$visitor\)') {
        $oldExpiration = @'
	protected function getPremiumExpirationTime(\XF\Entity\User $visitor): int
	{
		try
		{
			return (int) \XF::db()->fetchOne(
				'SELECT MAX(end_date) FROM xf_user_upgrade_active WHERE user_id = ?',
				[(int) $visitor->user_id]
			);
		}
		catch (\Throwable $e)
		{
			return 0;
		}
	}
'@
        $newExpiration = @'
	protected function getPremiumExpirationTime(\XF\Entity\User $visitor): int
	{
		$iosExpiration = IosEntitlement::expirationTime($visitor);
		if ($iosExpiration > 0)
		{
			return $iosExpiration;
		}

		try
		{
			return (int) \XF::db()->fetchOne(
				'SELECT MAX(end_date) FROM xf_user_upgrade_active WHERE user_id = ?',
				[(int) $visitor->user_id]
			);
		}
		catch (\Throwable $e)
		{
			return 0;
		}
	}
'@
        $updated = $updated.Replace($oldExpiration, $newExpiration)
    }
    return $updated
}

$readerPermissionPath = Join-Path $targetRoot "Service/ReaderPermission.php"
Update-FileText $readerPermissionPath {
    param($content)
    $updated = $content
    if ($updated -notmatch "use Ekitapligim\\MobileApi\\Service\\IosEntitlement;") {
        $updated = $updated -replace "use XenCustomize\\BookThreads\\Helper\\PremiumUrl;\r?\n", "use XenCustomize\BookThreads\Helper\PremiumUrl;`r`nuse Ekitapligim\MobileApi\Service\IosEntitlement;`r`n"
    }
    if ($updated -notmatch 'IosEntitlement::hasActiveEntitlement\(\$user\)') {
        $updated = $updated -replace 'if \(!empty\(\$readStatus\[''isUnlimited''\]\)\)\r?\n\t\t\{\r?\n\t\t\treturn ''premium'';\r?\n\t\t\}', "if (!empty(`$readStatus['isUnlimited']))`r`n`t`t{`r`n`t`t`treturn 'premium';`r`n`t`t}`r`n`t`tif (IosEntitlement::hasActiveEntitlement(`$user))`r`n`t`t{`r`n`t`t`treturn 'premium';`r`n`t`t}"
    }
    return $updated
}

Get-ChildItem -LiteralPath $targetApiDir -Filter "*.php" | Where-Object {
    $_.Name -notin @("AbstractMobileController.php", "MetaDirectoryTrait.php")
} | ForEach-Object {
    $className = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
    $pubTarget = Join-Path $targetPubDir $_.Name
    $pubContent = @"
<?php

namespace Ekitapligim\MobileApi\Pub\Controller;

class $className extends \Ekitapligim\MobileApi\Api\Controller\$className
{
    use PublicEndpointTrait;
}
"@
    Set-Content -LiteralPath $pubTarget -Value $pubContent -Encoding UTF8
}

Write-Step "Merging route fragment"
[xml]$routes = Get-Content -Raw -LiteralPath (Join-Path $targetRoot "_data/routes.xml")
[xml]$fragment = Get-Content -Raw -LiteralPath (Join-Path $sourceRoot "routes-fragment.xml")

$staleRouteKeys = @(
    "public|mobile-api|me-profile|v1/me|Ekitapligim\MobileApi:Me|",
    "api|me|profile||Ekitapligim\MobileApi:Me|"
)

foreach ($route in @($routes.routes.route)) {
    $key = "$($route.route_type)|$($route.route_prefix)|$($route.sub_name)|$($route.format)|$($route.controller)|$($route.action_prefix)"
    if ($staleRouteKeys -contains $key) {
        [void]$routes.routes.RemoveChild($route)
    }
}

$existingKeys = @{}
foreach ($route in $routes.routes.route) {
    $key = "$($route.route_type)|$($route.route_prefix)|$($route.sub_name)|$($route.format)|$($route.controller)|$($route.action_prefix)"
    $existingKeys[$key] = $true
}

$added = 0
foreach ($route in $fragment.routes.route) {
    $key = "$($route.route_type)|$($route.route_prefix)|$($route.sub_name)|$($route.format)|$($route.controller)|$($route.action_prefix)"
    if ($existingKeys.ContainsKey($key)) {
        continue
    }
    $imported = $routes.ImportNode($route, $true)
    [void]$routes.routes.AppendChild($imported)
    $existingKeys[$key] = $true
    $added++
}

$routes.Save((Join-Path $targetRoot "_data/routes.xml"))
Write-Host "Routes added: $added"

Write-Step "Auditing routed action prefixes"
foreach ($route in @($routes.routes.route | Where-Object { $_.action_prefix })) {
    $controllerName = ([string] $route.controller -split ':')[-1]
    $controllerPath = Join-Path $targetApiDir ($controllerName + ".php")
    if (-not (Test-Path -LiteralPath $controllerPath)) {
        throw "Route controller source not found for action-prefix audit: $($route.controller)"
    }

    $actionWords = ([string] $route.action_prefix -replace '[^a-zA-Z0-9]', ' ')
    $actionName = (Get-Culture).TextInfo.ToTitleCase($actionWords).Replace(' ', '')
    $methodName = "action$actionName"
    $controllerSource = Get-Content -Raw -LiteralPath $controllerPath
    if ($controllerSource -notmatch ("function\s+" + [regex]::Escape($methodName) + "\s*\(")) {
        throw "Route '$($route.format)' expects missing $methodName() in $controllerName"
    }
}

Write-Step "Merging CLI command fragment"
$cliPath = Join-Path $targetRoot "_data/cli.xml"
$cliFragmentPath = Join-Path $sourceRoot "cli-fragment.xml"
if (-not (Test-Path -LiteralPath $cliPath)) {
    Set-Content -LiteralPath $cliPath -Value '<?xml version="1.0" encoding="utf-8"?><cli_commands />' -Encoding UTF8
}
[xml]$cli = Get-Content -Raw -LiteralPath $cliPath
[xml]$cliFragment = Get-Content -Raw -LiteralPath $cliFragmentPath
$existingCliClasses = @{}
foreach ($command in @($cli.cli_commands.command)) {
    $existingCliClasses[[string]$command.class] = $true
}
$cliAdded = 0
foreach ($command in @($cliFragment.cli_commands.command)) {
    $class = [string]$command.class
    if ($existingCliClasses.ContainsKey($class)) { continue }
    [void]$cli.DocumentElement.AppendChild($cli.ImportNode($command, $true))
    $existingCliClasses[$class] = $true
    $cliAdded++
}
$cli.Save($cliPath)
Write-Host "CLI commands added: $cliAdded"

if ($BumpVersion) {
    Write-Step "Bumping addon version"
    $addonJsonPath = Join-Path $targetRoot "addon.json"
    $addonJson = Get-Content -Raw -LiteralPath $addonJsonPath | ConvertFrom-Json
    $addonJson.version_id = [int] $addonJson.version_id + 1
    $versionParts = ([string] $addonJson.version_string).Split(".")
    if ($versionParts.Length -gt 0 -and $versionParts[-1] -match "^\d+$") {
        $versionParts[-1] = ([int] $versionParts[-1] + 1).ToString()
        $addonJson.version_string = ($versionParts -join ".")
    } else {
        $addonJson.version_string = "$($addonJson.version_string).1"
    }
    $addonJson | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $addonJsonPath -Encoding UTF8
    Write-Host "New addon version: $($addonJson.version_string) ($($addonJson.version_id))"
}

Write-Step "Validating patched PHP"
$php = Get-Command php -ErrorAction SilentlyContinue
if ($php) {
    Get-ChildItem -LiteralPath $targetApiDir -Filter "*.php" | Where-Object {
        Test-Path -LiteralPath (Join-Path $sourceControllerDir $_.Name)
    } | ForEach-Object {
        & php -l $_.FullName | Write-Host
        if ($LASTEXITCODE -ne 0) {
            throw "PHP syntax failed: $($_.FullName)"
        }
    }
    foreach ($directory in @($targetServiceDir, $targetCliDir)) {
        Get-ChildItem -LiteralPath $directory -Filter "*.php" | Where-Object {
            (Test-Path -LiteralPath (Join-Path $sourceServiceDir $_.Name)) -or
            (Test-Path -LiteralPath (Join-Path $sourceCliDir $_.Name))
        } | ForEach-Object {
            & php -l $_.FullName | Write-Host
            if ($LASTEXITCODE -ne 0) { throw "PHP syntax failed: $($_.FullName)" }
        }
    }
} else {
    Write-Host "php not found; skipping PHP syntax validation"
}

if ($CreateZip) {
    Write-Step "Creating addon zip"
    $addonJson = Get-Content -Raw -LiteralPath (Join-Path $targetRoot "addon.json") | ConvertFrom-Json
    $version = if ($addonJson.version_string) { $addonJson.version_string } else { Get-Date -Format "yyyyMMddHHmmss" }
    $outDir = if ($OutputDirectory) { $OutputDirectory } else { Split-Path -Parent $targetRoot }
    $resolvedOutDir = [System.IO.Path]::GetFullPath($outDir)
    $resolvedTargetRoot = [System.IO.Path]::GetFullPath($targetRoot)
    if ($resolvedOutDir.TrimEnd('\') -eq $resolvedTargetRoot.TrimEnd('\') -or
        $resolvedOutDir.StartsWith($resolvedTargetRoot.TrimEnd('\') + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "OutputDirectory must be outside AddonPath to avoid recursive packaging"
    }
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    $stage = Join-Path $outDir "_ios_mobileapi_package_$version"
    $uploadTarget = Join-Path $stage "upload/src/addons/Ekitapligim/MobileApi"
    if (Test-Path -LiteralPath $stage) {
        Remove-Item -LiteralPath $stage -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $uploadTarget | Out-Null
    Copy-Item -Path (Join-Path $targetRoot "*") -Destination $uploadTarget -Recurse -Force
    $zipPath = Join-Path $outDir "Ekitapligim-MobileApi-iOS-$version.zip"
    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }
    Compress-Archive -LiteralPath (Join-Path $stage "upload") -DestinationPath $zipPath -Force
    Remove-Item -LiteralPath $stage -Recurse -Force
    Write-Host "Created $zipPath"
}

Write-Host "MobileApi iOS patch applied."
