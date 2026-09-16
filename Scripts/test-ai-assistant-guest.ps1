[CmdletBinding()]
param(
    [uri]$BaseUrl = 'https://ekitapligim.com/mobile-api/v1/ai/',
    [string]$OutputPath = '.codex-artifacts/ai-assistant/guest-smoke.json'
)
$ErrorActionPreference = 'Stop'
if ($BaseUrl.Scheme -ne 'https' -or $BaseUrl.UserInfo) { throw 'A public HTTPS AI endpoint is required.' }
$bytes = New-Object byte[] 32
[System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
$key = [Convert]::ToHexString($bytes).ToLowerInvariant()
$headers = @{ 'X-Guest-Key' = $key; 'Accept' = 'application/json' }
$conversationId = 0
$report = [ordered]@{ date = (Get-Date).ToUniversalTime().ToString('o'); endpoint = $BaseUrl.AbsoluteUri; passed = $false }
try {
    $before = Invoke-RestMethod -Uri ([uri]::new($BaseUrl, 'bootstrap')) -Headers $headers -TimeoutSec 30
    if ($before.authenticated -or -not $before.enabled -or $before.usage.remaining -le 0) { throw 'Guest assistant is unavailable or has no remaining quota.' }
    $created = Invoke-RestMethod -Uri ([uri]::new($BaseUrl, 'conversations')) -Method Post -Headers $headers -Body @{ title = 'iOS integration validation'; entry_point = 'ios' } -TimeoutSec 30
    $conversationId = [int]$created.conversation.conversation_id
    if ($conversationId -le 0) { throw 'Missing conversation identifier.' }
    Write-Output 'Guest conversation created; requesting one synthetic book recommendation.'
    $reply = Invoke-RestMethod -Uri ([uri]::new($BaseUrl, "conversations/$conversationId")) -Method Post -Headers $headers -Body @{ message = 'Kütüphaneden kısa ve umut veren bir kitap öner. Yanıtı iki cümleyle sınırla.'; entry_point = 'ios' } -TimeoutSec 180
    if ([int]$reply.conversation_id -ne $conversationId -or [string]::IsNullOrWhiteSpace($reply.answer)) { throw 'Invalid AI response.' }
    $after = Invoke-RestMethod -Uri ([uri]::new($BaseUrl, 'bootstrap')) -Headers $headers -TimeoutSec 30
    if ([int]$after.usage.used -ne ([int]$before.usage.used + 1)) { throw 'Server quota did not advance by exactly one.' }
    $loaded = Invoke-RestMethod -Uri ([uri]::new($BaseUrl, "conversations/$conversationId")) -Headers $headers -TimeoutSec 30
    if (@($loaded.conversation.messages).Count -lt 2) { throw 'Conversation did not retain request and answer.' }
    $deleted = Invoke-RestMethod -Uri ([uri]::new($BaseUrl, "conversations/$conversationId")) -Method Delete -Headers $headers -TimeoutSec 30
    if (-not $deleted.success) { throw 'Conversation cleanup failed.' }
    $conversationId = 0
    $afterDelete = Invoke-RestMethod -Uri ([uri]::new($BaseUrl, 'bootstrap')) -Headers $headers -TimeoutSec 30
    if ([int]$afterDelete.usage.used -ne [int]$after.usage.used) { throw 'Deleting conversation unexpectedly changed quota.' }
    $report.limit = [int]$before.usage.limit
    $report.usedBefore = [int]$before.usage.used
    $report.usedAfter = [int]$after.usage.used
    $report.usedAfterDelete = [int]$afterDelete.usage.used
    $report.passed = $true
    Write-Output 'Guest send, history, stable identity, quota consumption and deletion checks passed.'
} finally {
    if ($conversationId -gt 0) {
        try { $null = Invoke-RestMethod -Uri ([uri]::new($BaseUrl, "conversations/$conversationId")) -Method Delete -Headers $headers -TimeoutSec 30 }
        catch { Write-Warning 'The disposable test conversation could not be removed; server retention still applies.' }
    }
    $report | ConvertTo-Json | Set-Content -LiteralPath $OutputPath -Encoding utf8
}
