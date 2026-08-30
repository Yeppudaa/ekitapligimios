param(
    [Parameter(Mandatory = $true)]
    [string]$BaseUrl,

    [Parameter(Mandatory = $true)]
    [string]$BearerToken,

    [int]$BlockedUserId = 0,

    [int]$ThreadId = 0,

    [int]$ForumId = 0,

    [int]$BookId = 0,

    [int]$AgendaPostId = 0,

    [int]$ForumPostId = 0,

    [int]$BookCommentId = 0,

    [int]$AgendaCommentId = 0,

    [int]$ChatMessageId = 0,

    [int]$ConversationMessageId = 0,

    [int]$ChatRoomId = 0,

    [int]$ConversationId = 0,

    [string]$BlockedTerm = "",

    [string]$BlockSourceType = "",

    [int]$BlockSourceId = 0,

    [switch]$ExerciseMutations,

    [switch]$AllowProductionMutations,

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

function Invoke-ExpectedPolicyViolation($Path, $Body) {
    $uri = [Uri]::new($script:baseUri, $Path)
    try {
        $response = Invoke-WebRequest -Uri $uri -Method POST -Headers $script:headers -Body $Body -UseBasicParsing -TimeoutSec $TimeoutSec
        throw "Expected HTTP 422 for $Path but got HTTP $($response.StatusCode)."
    } catch {
        $status = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
        if ($status -ne 422) {
            throw "Expected HTTP 422 for $Path but got HTTP $status."
        }
        $message = [string]$_.ErrorDetails.Message
        if ($message -notmatch 'content_policy_violation') {
            throw "Expected $Path to return content_policy_violation."
        }
        Write-Host "PASS POST $Path -> HTTP 422 content_policy_violation"
    }
}

function Assert-ResponseDoesNotContain($Path, $Needle) {
    $payload = Invoke-JsonGet $Path | ConvertTo-Json -Depth 30 -Compress
    if ($payload -like "*$Needle*") {
        throw "Response $Path still contains the rejected test phrase."
    }
    Write-Host "PASS GET $Path -> rejected phrase is absent"
}

function Assert-ReportCreated($Type, $ContentId) {
    $result = Invoke-JsonPost "safety/reports" @{
        content_type = $Type
        content_id = [string]$ContentId
        reason_code = "other"
        details = "Guideline 1.2 controlled safety test report."
    }
    if (-not $result.report_id -and -not $result.reportId) {
        throw "Report response for $Type/$ContentId did not contain report_id."
    }
    Write-Host "PASS POST safety/reports ($Type/$ContentId) -> report queued"
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

if ($ExerciseMutations -and $script:baseUri.Host -notmatch '(^|\.)staging\.|localhost|127\.0\.0\.1|^10\.|^192\.168\.' -and -not $AllowProductionMutations) {
    throw "Mutation tests against production require the explicit -AllowProductionMutations switch."
}

$script:headers = @{ Authorization = "Bearer $BearerToken" }

Write-Step "Running UGC safety smoke test against $normalized"

try {
    Write-Step "Checking community terms status"
    $terms = Invoke-JsonGet "me/terms"
    if ([string]::IsNullOrWhiteSpace([string]$terms.requiredVersion)) {
        throw "Terms status did not include requiredVersion."
    }

    if (-not $ExerciseMutations) {
        Write-Host "Read-only mode: mutation, report, filter, and SLA checks are skipped."
        Write-Host "Use -ExerciseMutations with a disposable staging account and explicit test IDs to run them."
        return
    }

    if ($BlockedUserId -le 0 -or $ThreadId -le 0 -or [string]::IsNullOrWhiteSpace($BlockedTerm)) {
        throw "-ExerciseMutations requires -BlockedUserId, -ThreadId, and the configured -BlockedTerm test phrase."
    }

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

    if ($BlockSourceType -and $BlockSourceId -gt 0) {
        Invoke-JsonPost "members/$BlockedUserId/block" @{
            source_type = $BlockSourceType
            source_id = [string]$BlockSourceId
            reason_code = "harassment"
            details = "Guideline 1.2 controlled block-and-report test."
        } | Out-Null
        Write-Host "PASS contextual block-and-report ($BlockSourceType/$BlockSourceId)"
        Invoke-JsonPost "members/$BlockedUserId/unblock" @{} | Out-Null
    } else {
        Write-Host "SKIP contextual block-and-report (pass -BlockSourceType and -BlockSourceId)"
    }

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

    Write-Step "Checking managed content filter before persistence"
    $forums = Invoke-JsonGet "forums"
    if ($ForumId -le 0 -and $forums.forums -and $forums.forums.Count -gt 0) {
        $ForumId = [int]$forums.forums[0].id
    }
    if ($ForumId -le 0) { throw "No forum ID is available for the filter test." }
    $rejectedTitle = "UGC filter probe $(Get-Date -Format 'yyyyMMddHHmmss')"
    Invoke-ExpectedPolicyViolation "forums/$ForumId/threads" @{
        title = $rejectedTitle
        message = $BlockedTerm
    }
    Assert-ResponseDoesNotContain "forums/$ForumId/threads?page=1" $rejectedTitle

    Invoke-ExpectedPolicyViolation "threads/$ThreadId/posts" @{ message = $BlockedTerm }
    Assert-ResponseDoesNotContain "threads/$ThreadId/posts?page=1" $BlockedTerm

    if ($BookId -gt 0) {
        Invoke-ExpectedPolicyViolation "books/$BookId/comments" @{ message = $BlockedTerm; rating = "4" }
        Assert-ResponseDoesNotContain "books/$BookId/comments?page=1" $BlockedTerm
    } else { Write-Host "SKIP book comment filter (pass -BookId)" }

    if ($AgendaPostId -gt 0) {
        Invoke-ExpectedPolicyViolation "book-agenda/$AgendaPostId/comments" @{ message = $BlockedTerm }
        Assert-ResponseDoesNotContain "book-agenda/$AgendaPostId/comments?page=1" $BlockedTerm
    } else { Write-Host "SKIP Book Agenda comment filter (pass -AgendaPostId)" }

    $agendaBody = @{ message = $BlockedTerm; post_type = "standard"; visibility = "public" }
    if ($BookId -gt 0) { $agendaBody.book_thread_id = [string]$BookId }
    Invoke-ExpectedPolicyViolation "book-agenda" $agendaBody
    Assert-ResponseDoesNotContain "book-agenda?page=1" $BlockedTerm

    if ($ChatRoomId -gt 0) {
        Invoke-ExpectedPolicyViolation "chat/rooms/$ChatRoomId/messages" @{ message = $BlockedTerm }
        Assert-ResponseDoesNotContain "chat/rooms/$ChatRoomId/messages?page=1" $BlockedTerm
    } else { Write-Host "SKIP chat filter (pass -ChatRoomId)" }

    if ($ConversationId -gt 0) {
        Invoke-ExpectedPolicyViolation "conversations/$ConversationId/reply" @{ message = $BlockedTerm }
        Assert-ResponseDoesNotContain "conversations/$ConversationId/messages?page=1" $BlockedTerm
    } else { Write-Host "SKIP private-message filter (pass -ConversationId)" }

    Write-Host "Managed filter checks completed; rejected content was never accepted by the write endpoints."

    Write-Step "Checking XenForo report queue integration"
    $reportInputs = @(
        @{ Type = "forum_post"; Id = $ForumPostId },
        @{ Type = "book_comment"; Id = $BookCommentId },
        @{ Type = "agenda_post"; Id = $AgendaPostId },
        @{ Type = "agenda_comment"; Id = $AgendaCommentId },
        @{ Type = "chat_message"; Id = $ChatMessageId },
        @{ Type = "conversation_message"; Id = $ConversationMessageId }
    )
    foreach ($input in $reportInputs) {
        if ([int]$input.Id -gt 0) {
            Assert-ReportCreated $input.Type ([int]$input.Id)
        } else {
            Write-Host "SKIP report test for $($input.Type) (pass its content ID)"
        }
    }

    Write-Host "UGC safety smoke test completed."
} finally {
    if ($ExerciseMutations -and $BlockedUserId -gt 0) {
        try {
            Invoke-JsonPost "members/$BlockedUserId/unblock" @{} | Out-Null
        } catch {
            Write-Host "WARN cleanup unblock failed: $($_.Exception.Message)"
        }
    }
}
