[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$global:ekitapligimSmokeContractCalls = [System.Collections.Generic.List[string]]::new()
function Invoke-WebRequest {
    param($Uri, $Method, $Headers, $Body, $ContentType, $TimeoutSec, [switch]$UseBasicParsing)
    $global:ekitapligimSmokeContractCalls.Add("$Method $Uri")
    if ($Method -ne 'GET') { throw 'Unexpected network write in read-only smoke check' }
    return [pscustomobject]@{ StatusCode=200; Content='{}' }
}
function Invoke-RestMethod {
    param($Uri, $Method, $Headers, $Body, $ContentType, $TimeoutSec)
    $global:ekitapligimSmokeContractCalls.Add("$Method $Uri")
    if ($Method -ne 'GET') { throw 'Unexpected network write in read-only smoke check' }
    if ([string]$Uri -like '*/me/terms') { return [pscustomobject]@{requiredVersion='new-terms'} }
    if ([string]$Uri -like '*/members?*') { return [pscustomobject]@{members=@([pscustomobject]@{id=22})} }
    if ([string]$Uri -like '*/conversations?*') { return [pscustomobject]@{conversations=@([pscustomobject]@{id=33})} }
    return $null
}
# Inject a synthetic bearer. All HTTP calls above are mocked; no live account is accessed.
& "$PSScriptRoot/api-smoke-test.ps1" -BaseUrl 'https://ekitapligim.com/ios-api/v1/' -BearerToken 'synthetic-smoke-test'
if ($global:ekitapligimSmokeContractCalls.Count -eq 0) { throw 'Read checks did not execute' }
if ($global:ekitapligimSmokeContractCalls | Where-Object { $_ -like '*conversation-detail*' }) { throw 'Read-only check must not mark messages read' }
foreach ($scriptName in @('api-smoke-test', 'parity-audit')) {
    $before = $global:ekitapligimSmokeContractCalls.Count
    $blocked = $false
    try { & "$PSScriptRoot/$scriptName.ps1" -BaseUrl 'https://ekitapligim.com/ios-api/v1/' -ExerciseMutations }
    catch { $blocked = $_.Exception.Message -match 'Production writes require explicit' }
    if (-not $blocked -or $global:ekitapligimSmokeContractCalls.Count -ne $before) { throw "$scriptName must reject production writes before HTTP" }
}
Write-Output 'PASS: read-only smoke checks make no writes or read receipts; both production mutation guards stop before HTTP.'
