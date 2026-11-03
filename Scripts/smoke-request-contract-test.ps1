[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
# Exercise the real helper with a captured transport, without running the smoke script.
$tokens = $null; $parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $PSScriptRoot 'api-smoke-test.ps1'), [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw 'Smoke script has parse errors' }
$helper = $ast.Find({ param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Invoke-SmokePut'
}, $true)
if (-not $helper) { throw 'PUT helper missing' }
. ([scriptblock]::Create($helper.Extent.Text))
$script:baseUri = [Uri]'https://smoke.invalid/ios-api/v1/'
$BearerToken = 'synthetic-smoke-token'
$TimeoutSec = 5
$script:capturedRequest = $null
function Invoke-WebRequest {
    param($Uri, $Method, $Headers, $Body, $ContentType, $TimeoutSec, [switch]$UseBasicParsing)
    $script:capturedRequest = @{Uri=$Uri; Method=$Method; Headers=$Headers; Body=$Body; ContentType=$ContentType}
    [pscustomobject]@{StatusCode=200}
}
Invoke-SmokePut 'me/library/42' @{shelf_state='OKUYORUM'; progress_percent='1'; last_read_page='1'} -RequiresAuth
if ($script:capturedRequest.Method -ne 'PUT' -or $script:capturedRequest.Uri.Host -ne 'smoke.invalid') {
    throw 'Unexpected PUT destination or method'
}
if ($script:capturedRequest.ContentType -ne 'application/x-www-form-urlencoded; charset=utf-8') {
    throw 'PUT smoke requests must declare the same UTF-8 form content type as the app'
}
if ($script:capturedRequest.Headers.Authorization -ne "Bearer $BearerToken" -or
    $script:capturedRequest.Body.shelf_state -ne 'OKUYORUM') { throw 'PUT auth/body changed' }
Write-Output 'PASS: real PUT helper preserves the authenticated UTF-8 form contract; no network used.'
