param(
    [string]$BaseUrl = "https://ekitapligim.com/ios-api/v1/"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
. (Join-Path $PSScriptRoot "load-smoke-env.ps1") -Root $root

Write-Host "==> Ekitapligim iOS/Android parity completion report"
Write-Host ""

$loginSet = -not [string]::IsNullOrWhiteSpace($env:EKITAPLIGIM_SMOKE_LOGIN)
$passwordSet = -not [string]::IsNullOrWhiteSpace($env:EKITAPLIGIM_SMOKE_PASSWORD)
$tokenSet = -not [string]::IsNullOrWhiteSpace($env:EKITAPLIGIM_SMOKE_ACCESS_TOKEN)

Write-Host "Environment"
Write-Host "  EKITAPLIGIM_SMOKE_LOGIN     $(if ($loginSet) { 'SET' } else { 'MISSING' })"
Write-Host "  EKITAPLIGIM_SMOKE_PASSWORD  $(if ($passwordSet) { 'SET' } else { 'MISSING' })"
Write-Host "  EKITAPLIGIM_SMOKE_ACCESS_TOKEN $(if ($tokenSet) { 'SET' } else { 'MISSING' })"
Write-Host ""

Write-Host "==> Deploy artifact + prod forum create probe"
& (Join-Path $PSScriptRoot "verify-ios-api-deploy.ps1") -BaseUrl $BaseUrl
$deployExit = $LASTEXITCODE
Write-Host ""

Write-Host "==> Full automated parity gate"
& (Join-Path $PSScriptRoot "parity-audit.ps1") -BaseUrl $BaseUrl
$auditExit = $LASTEXITCODE
Write-Host ""

Write-Host "==> Completion verdict"
& (Join-Path $PSScriptRoot "verify-visual-parity-evidence.ps1") | Out-Null
$visualExit = $LASTEXITCODE
$goalComplete = ($deployExit -eq 0) -and ($loginSet -and $passwordSet) -and ($auditExit -eq 0) -and ($visualExit -eq 0)

if ($deployExit -ne 0) {
    Write-Host "  BLOCKED: IosApi deploy probe failed (forum/thread routes not live on prod)."
}
if (-not ($loginSet -and $passwordSet)) {
    Write-Host "  BLOCKED: Auth mutation smoke not run (copy .env.example to .env or set smoke login/password)."
}
if ($auditExit -ne 0) {
    Write-Host "  BLOCKED: Automated parity gate failed."
}
if ($visualExit -ne 0) {
    Write-Host "  BLOCKED: Mac/Xcode visual evidence missing or incomplete (release-archive/visual-parity/manifest.json)."
}
Write-Host ""

if ($goalComplete) {
    Write-Host "GOAL STATUS: COMPLETE - automated gates and visual parity evidence verified."
    exit 0
}

Write-Host "GOAL STATUS: INCOMPLETE - see ANDROID_IOS_FEATURE_PARITY.md for matrix."
exit 2
