param(
    [Parameter(Mandatory = $true)]
    [string]$BaseUrl,

    [Parameter(Mandatory = $true)]
    [string]$BearerToken,

    [int]$BlockedUserId = 4,

    [int]$ThreadId = 1,

    [switch]$AllowInsecure,

    [int]$TimeoutSec = 15
)

$ErrorActionPreference = "Stop"

function Write-Step($Message) {
    Write-Host "==> $Message"
}

function Normalize-BaseUrl($Url) {
    $trimmed = $Url.Trim()
    if (-not $trimmed.EndsWith("/")) {
        $trimmed = "$trimmed/"
    }
    return $trimmed
}

function Invoke-JsonGet($Path) {
    $uri = [Uri]::new($script:baseUri, $Path)
    Invoke-RestMethod -Uri $uri -Method GET -Headers $script:headers -TimeoutSec $TimeoutSec
}

function Invoke-JsonPost($Path, $Body) {
    $uri = [Uri]::new($script:baseUri, $Path)
    Invoke-RestMethod -Uri $uri -Method POST -Headers $script:headers -Body $Body -TimeoutSec $TimeoutSec
}

function Invoke-ExpectedHttpError($Path, $Body, [int]$ExpectedStatus, [string]$ExpectedText) {
    $uri = [Uri]::new($script:baseUri, $Path)
    try {
        $response = Invoke-WebRequest -Uri $uri -Method POST -Headers $script:headers -Body $Body -UseBasicParsing -TimeoutSec $TimeoutSec
        throw "Expected HTTP $ExpectedStatus for $Path but got HTTP $($response.StatusCode)."
    } catch {
        $status = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
        if ($status -ne $ExpectedStatus) {
            throw "Expected HTTP $ExpectedStatus for $Path but got HTTP $status."
        }
        $message = [string]$_.ErrorDetails.Message
        try {
            $errorPayload = $message | ConvertFrom-Json
            if ($errorPayload.errors) {
                $message = @($errorPayload.errors) -join " "
            }
        } catch {
            # Keep the raw response for non-JSON error bodies.
        }
        if ($ExpectedText -and $message -notmatch [regex]::Escape($ExpectedText)) {
            throw "Expected response for $Path to contain '$ExpectedText'."
        }
        Write-Host "PASS POST $Path -> expected HTTP $status"
    }
}

$normalized = Normalize-BaseUrl $BaseUrl
$script:baseUri = [Uri]$normalized

if ($script:baseUri.Scheme -ne "https" -and -not $AllowInsecure) {
    throw "BaseUrl must use HTTPS unless -AllowInsecure is provided."
}
if (($script:baseUri.Host -match "localhost|127\.0\.0\.1|192\.168\.|^10\.") -and -not $AllowInsecure) {
    throw "BaseUrl points to a local/private host. Use -AllowInsecure only for local development checks."
}

$script:headers = @{ Authorization = "Bearer $BearerToken" }

Write-Step "Running UGC safety smoke test against $normalized"

try {
    Write-Step "Cleaning existing block state for target user $BlockedUserId"
    Invoke-JsonPost "members/$BlockedUserId/unblock" @{} | Out-Null

    Write-Step "Checking block/unblock safety endpoints"
    Invoke-JsonPost "members/$BlockedUserId/block" @{} | Out-Null
    $blocked = Invoke-JsonGet "me/blocked-members"
    $blockedIds = @($blocked.members | ForEach-Object { [string]$_.id })
    if ($blockedIds -notcontains [string]$BlockedUserId) {
        throw "Blocked members response did not include $BlockedUserId."
    }
    Write-Host "PASS block target appears in me/blocked-members"

    Invoke-JsonPost "members/$BlockedUserId/unblock" @{} | Out-Null
    $unblocked = Invoke-JsonGet "me/blocked-members"
    $unblockedIds = @($unblocked.members | ForEach-Object { [string]$_.id })
    if ($unblockedIds -contains [string]$BlockedUserId) {
        throw "Blocked members response still included $BlockedUserId after unblock."
    }
    Write-Host "PASS unblock removes target from me/blocked-members"

    Write-Step "Checking community terms status and acceptance"
    $terms = Invoke-JsonGet "me/terms"
    if (-not $terms.requiredVersion) {
        throw "Terms status did not include requiredVersion."
    }
    if ($terms.requiresAcceptance -eq $true) {
        Invoke-ExpectedHttpError "threads/$ThreadId/posts" @{ message = "UGC terms gate smoke" } 403 "Topluluk kurallarını"
    } else {
        Write-Host "SKIP pre-accept reply gate (account already accepted current terms)"
    }
    Invoke-JsonPost "me/terms/accept" @{ version = $terms.requiredVersion } | Out-Null
    $accepted = Invoke-JsonGet "me/terms"
    if ($accepted.requiresAcceptance -eq $true) {
        throw "Terms still require acceptance after accept call."
    }
    Write-Host "PASS terms acceptance round-trip"

    Write-Step "Checking unauthenticated reply is rejected"
    $uri = [Uri]::new($script:baseUri, "threads/$ThreadId/posts")
    try {
        $response = Invoke-WebRequest -Uri $uri -Method POST -Body @{ message = "UGC smoke unauthenticated reply" } -UseBasicParsing -TimeoutSec $TimeoutSec
        throw "Expected unauthenticated reply to fail but got HTTP $($response.StatusCode)."
    } catch {
        $status = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
        if ($status -lt 400) {
            throw "Expected unauthenticated reply to fail but got HTTP $status."
        }
        Write-Host "PASS POST threads/$ThreadId/posts without auth -> expected HTTP $status"
    }

    Write-Host "UGC safety smoke test completed."
} finally {
    try {
        Invoke-JsonPost "members/$BlockedUserId/unblock" @{} | Out-Null
    } catch {
        Write-Host "WARN cleanup unblock failed: $($_.Exception.Message)"
    }
}
