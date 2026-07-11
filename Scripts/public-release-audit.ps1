[CmdletBinding()]
param(
    [Uri]$SiteBaseUrl = "https://ekitapligim.com/",
    [Uri]$ApiBaseUrl = "https://ekitapligim.com/mobile-api/v1/",
    [string]$TeamId,
    [string]$BundleId = "com.ekitapligim.app"
)

$ErrorActionPreference = "Stop"
$failures = [System.Collections.Generic.List[string]]::new()

function Join-PublicUrl([Uri]$BaseUrl, [string]$RelativePath) {
    return [Uri]::new($BaseUrl, $RelativePath)
}

function Get-PublicResponse([Uri]$Url, [string]$Label) {
    try {
        return Invoke-WebRequest -Uri $Url -Method Get -MaximumRedirection 5 -TimeoutSec 30 -UseBasicParsing
    } catch {
        $status = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { "network error" }
        $failures.Add("$Label failed at $Url (HTTP $status).")
        return $null
    }
}

if ($SiteBaseUrl.Scheme -ne "https" -or $ApiBaseUrl.Scheme -ne "https") {
    throw "Public release endpoints must use HTTPS."
}

Write-Host "==> Checking public legal and support pages"
foreach ($page in @(
    @{ Label = "Support page"; Path = "diger/iletisim" },
    @{ Label = "Privacy policy"; Path = "yardim/gizlilik-politikasi/" },
    @{ Label = "Terms and community rules"; Path = "yardim/kurallar/" }
)) {
    $response = Get-PublicResponse (Join-PublicUrl $SiteBaseUrl $page.Path) $page.Label
    if ($response -and $response.Headers["Content-Type"] -notmatch "text/html") {
        $failures.Add("$($page.Label) must return HTML, got '$($response.Headers['Content-Type'])'.")
    }
}

Write-Host "==> Checking public Mobile API"
$booksResponse = Get-PublicResponse (Join-PublicUrl $ApiBaseUrl "books?page=1") "Mobile API books endpoint"
if ($booksResponse) {
    if ($booksResponse.Headers["Content-Type"] -notmatch "application/json") {
        $failures.Add("Mobile API books endpoint must return JSON, got '$($booksResponse.Headers['Content-Type'])'.")
    }
    try {
        $booksPayload = $booksResponse.Content | ConvertFrom-Json
        if ($null -eq $booksPayload.books -and $null -eq $booksPayload.items) {
            $failures.Add("Mobile API books response has neither a books nor items collection.")
        }
    } catch {
        $failures.Add("Mobile API books response is not valid JSON.")
    }
}

Write-Host "==> Checking universal-link association"
$aasaUrl = Join-PublicUrl $SiteBaseUrl ".well-known/apple-app-site-association"
$aasaResponse = Get-PublicResponse $aasaUrl "Apple App Site Association"
if ($aasaResponse) {
    if ($aasaResponse.Headers["Content-Type"] -notmatch "application/json") {
        $failures.Add("Apple App Site Association must use an application/json content type, got '$($aasaResponse.Headers['Content-Type'])'.")
    }
    try {
        $aasa = $aasaResponse.Content | ConvertFrom-Json
        $details = @($aasa.applinks.details)
        if ($details.Count -eq 0) {
            $failures.Add("Apple App Site Association has no applinks details.")
        } elseif ($TeamId) {
            $expectedAppId = "$TeamId.$BundleId"
            $deployedAppIds = @($details | ForEach-Object { @($_.appID) + @($_.appIDs) })
            if ($deployedAppIds -notcontains $expectedAppId) {
                $failures.Add("Apple App Site Association does not include appID '$expectedAppId'.")
            }
        } elseif ((@($details | ForEach-Object { @($_.appID) + @($_.appIDs) }) -join " ") -match "TEAMID") {
            $failures.Add("Apple App Site Association still contains the TEAMID placeholder.")
        }
    } catch {
        $failures.Add("Apple App Site Association is not valid JSON.")
    }
}

if ($failures.Count -gt 0) {
    throw "Public release audit failed:`n- $($failures -join "`n- ")"
}

Write-Host "Public release audit completed."
