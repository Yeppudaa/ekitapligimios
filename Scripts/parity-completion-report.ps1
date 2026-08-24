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
$goalComplete = ($deployExit -eq 0) -and ($loginSet -and $passwordSet) -and ($auditExit -eq 0)

if ($deployExit -ne 0) {
    Write-Host "  BLOCKED: IosApi v1.0.4 not live on prod (forum POST still 404)."
}
if (-not ($loginSet -and $passwordSet)) {
    Write-Host "  BLOCKED: Auth mutation smoke not run (copy .env.example to .env or set smoke login/password)."
}
Write-Host "  BLOCKED: Mac/Xcode visual checklist not executed from this environment."
Write-Host ""

if ($goalComplete) {
    Write-Host "GOAL STATUS: All automated gates green; run visual-parity-checklist.ps1 on Mac to finish."
    exit 0
}

Write-Host "GOAL STATUS: INCOMPLETE - see ANDROID_IOS_FEATURE_PARITY.md for matrix."
exit 2
