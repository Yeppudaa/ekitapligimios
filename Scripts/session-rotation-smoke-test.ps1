param(
    [Parameter(Mandatory = $true)]
    [string]$BaseUrl,
    [switch]$AllowInsecure,
    [int]$TimeoutSec = 15
)

$ErrorActionPreference = "Stop"
$login = [string]$env:EKITAPLIGIM_SMOKE_LOGIN
$password = [string]$env:EKITAPLIGIM_SMOKE_PASSWORD
if ([string]::IsNullOrWhiteSpace($login) -or [string]::IsNullOrWhiteSpace($password)) {
    throw "Set EKITAPLIGIM_SMOKE_LOGIN and EKITAPLIGIM_SMOKE_PASSWORD for a disposable account."
}

$normalized = $BaseUrl.TrimEnd('/') + '/'
$base = [Uri]$normalized
if ($base.Scheme -ne 'https' -and -not $AllowInsecure) {
    throw "BaseUrl must use HTTPS unless -AllowInsecure is provided."
}

function Invoke-Api([string]$Path, [string]$Method = 'GET', $Body = $null, [string]$Token = '') {
    $parameters = @{
        Uri = [Uri]::new($base, $Path)
        Method = $Method
        TimeoutSec = $TimeoutSec
    }
    if ($null -ne $Body) { $parameters.Body = $Body }
    if ($Token) { $parameters.Headers = @{ Authorization = "Bearer $Token" } }
    Invoke-RestMethod @parameters
}

function Assert-Unauthorized([scriptblock]$Call, [string]$Label) {
    try {
        & $Call | Out-Null
        throw "$Label unexpectedly succeeded."
    } catch {
        if ($_.Exception.Message -eq "$Label unexpectedly succeeded.") { throw }
        $status = [int]$_.Exception.Response.StatusCode
        if ($status -ne 401) { throw "$Label returned HTTP $status instead of 401." }
        Write-Host "PASS $Label -> HTTP 401"
    }
}

$initial = Invoke-Api 'auth/login' 'POST' @{ login = $login; password = $password }
$rotated = Invoke-Api 'auth/refresh' 'POST' @{ refresh_token = [string]$initial.refresh_token }

Assert-Unauthorized { Invoke-Api 'me' 'GET' $null ([string]$initial.access_token) } 'rotated access token'
Assert-Unauthorized { Invoke-Api 'auth/refresh' 'POST' @{ refresh_token = [string]$initial.refresh_token } } 'rotated refresh token'
Invoke-Api 'me' 'GET' $null ([string]$rotated.access_token) | Out-Null
Write-Host 'PASS refreshed access token -> authenticated profile'

Invoke-Api 'auth/logout' 'POST' @{} ([string]$rotated.access_token) | Out-Null
Assert-Unauthorized { Invoke-Api 'me' 'GET' $null ([string]$rotated.access_token) } 'logged-out access token'
Assert-Unauthorized { Invoke-Api 'auth/refresh' 'POST' @{ refresh_token = [string]$rotated.refresh_token } } 'logged-out refresh token'

Write-Host 'Session rotation smoke test completed.'
