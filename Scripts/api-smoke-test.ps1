param(
    [Parameter(Mandatory = $true)]
    [string]$BaseUrl,

    [string]$BearerToken = "",

    [string]$Login = "",

    [string]$Password = "",

    [switch]$AllowInsecure,

    [switch]$ExerciseMutations,

    [int]$BookId = 1,

    [int]$TimeoutSec = 15
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
. (Join-Path $PSScriptRoot "load-smoke-env.ps1") -Root $repoRoot

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

function Invoke-SmokeGet($Path, [switch]$RequiresAuth) {
    $uri = [Uri]::new($script:baseUri, $Path)
    $headers = @{}
    if ($RequiresAuth) {
        if ([string]::IsNullOrWhiteSpace($BearerToken)) {
            Write-Host "SKIP $Path (requires auth token)"
            return
        }
        $headers["Authorization"] = "Bearer $BearerToken"
    }

    try {
        $response = Invoke-WebRequest -Uri $uri -Headers $headers -Method GET -UseBasicParsing -TimeoutSec $TimeoutSec
        Write-Host "PASS GET $Path -> HTTP $($response.StatusCode)"
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if (-not $statusCode) {
            throw "FAIL GET $Path -> $($_.Exception.Message)"
        }
        throw "FAIL GET $Path -> HTTP $statusCode"
    }
}

function Invoke-SmokeJsonGet($Path, [switch]$RequiresAuth) {
    $uri = [Uri]::new($script:baseUri, $Path)
    $headers = @{}
    if ($RequiresAuth) {
        if ([string]::IsNullOrWhiteSpace($BearerToken)) {
            Write-Host "SKIP $Path (requires auth token)"
            return $null
        }
        $headers["Authorization"] = "Bearer $BearerToken"
    }

    try {
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method GET -TimeoutSec $TimeoutSec
        Write-Host "PASS GET $Path -> JSON"
        return $response
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if (-not $statusCode) {
            throw "FAIL GET $Path -> $($_.Exception.Message)"
        }
        throw "FAIL GET $Path -> HTTP $statusCode"
    }
}

function Invoke-SmokePost($Path, $Body, [switch]$RequiresAuth) {
    $uri = [Uri]::new($script:baseUri, $Path)
    $headers = @{}
    if ($RequiresAuth) {
        if ([string]::IsNullOrWhiteSpace($BearerToken)) {
            Write-Host "SKIP $Path (requires auth token)"
            return
        }
        $headers["Authorization"] = "Bearer $BearerToken"
    }

    try {
        $response = Invoke-WebRequest -Uri $uri -Headers $headers -Method POST -Body $Body -UseBasicParsing -TimeoutSec $TimeoutSec
        Write-Host "PASS POST $Path -> HTTP $($response.StatusCode)"
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if (-not $statusCode) {
            throw "FAIL POST $Path -> $($_.Exception.Message)"
        }
        throw "FAIL POST $Path -> HTTP $statusCode"
    }
}

function Invoke-SmokePostJson($Path, $Body, [switch]$RequiresAuth) {
    $uri = [Uri]::new($script:baseUri, $Path)
    $headers = @{}
    if ($RequiresAuth) {
        if ([string]::IsNullOrWhiteSpace($BearerToken)) {
            Write-Host "SKIP $Path (requires auth token)"
            return $null
        }
        $headers["Authorization"] = "Bearer $BearerToken"
    }

    $attempt = 0
    while ($true) {
        try {
            $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method POST -Body $Body -TimeoutSec $TimeoutSec
            Write-Host "PASS POST $Path -> JSON"
            return $response
        } catch {
            $statusCode = $_.Exception.Response.StatusCode.value__
            if ($statusCode -eq 429 -and $attempt -lt 2) {
                $attempt++
                Write-Host "WAIT POST $Path -> HTTP 429; retry $attempt in 20s"
                Start-Sleep -Seconds 20
                continue
            }
            if (-not $statusCode) {
                throw "FAIL POST $Path -> $($_.Exception.Message)"
            }
            throw "FAIL POST $Path -> HTTP $statusCode"
        }
    }
}

function Assert-SmokeUnauthorizedPost($Path) {
    $uri = [Uri]::new($script:baseUri, $Path)
    try {
        Invoke-WebRequest -Uri $uri -Method POST -UseBasicParsing -TimeoutSec $TimeoutSec | Out-Null
        throw "FAIL POST $Path without authorization unexpectedly succeeded"
    } catch {
        if ($_.Exception.Message -eq "FAIL POST $Path without authorization unexpectedly succeeded") {
            throw
        }
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -notin 401, 403) {
            throw "FAIL POST $Path without authorization -> expected HTTP 401/403, got HTTP $statusCode"
        }
        Write-Host "PASS POST $Path without authorization -> HTTP $statusCode"
    }
}

function Assert-SmokeUnauthorizedPut($Path, $Body) {
    $uri = [Uri]::new($script:baseUri, $Path)
    try {
        Invoke-WebRequest -Uri $uri -Method PUT -Body $Body -UseBasicParsing -TimeoutSec $TimeoutSec | Out-Null
        throw "FAIL PUT $Path without authorization unexpectedly succeeded"
    } catch {
        if ($_.Exception.Message -eq "FAIL PUT $Path without authorization unexpectedly succeeded") {
            throw
        }
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -notin 401, 403) {
            throw "FAIL PUT $Path without authorization -> expected HTTP 401/403, got HTTP $statusCode"
        }
        Write-Host "PASS PUT $Path without authorization -> HTTP $statusCode"
    }
}

function Assert-SmokeProtectedPost($Path, $Body) {
    $uri = [Uri]::new($script:baseUri, $Path)
    try {
        Invoke-WebRequest -Uri $uri -Method POST -Body $Body -ContentType "application/x-www-form-urlencoded" -UseBasicParsing -TimeoutSec $TimeoutSec | Out-Null
        throw "FAIL POST $Path without authorization unexpectedly succeeded"
    } catch {
        if ($_.Exception.Message -eq "FAIL POST $Path without authorization unexpectedly succeeded") {
            throw
        }
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -in 401, 403) {
            Write-Host "PASS POST $Path without authorization -> HTTP $statusCode"
        } elseif ($statusCode -in 404, 405) {
            Write-Host "WARN POST $Path without authorization -> HTTP $statusCode (route missing on server; deploy IosApi add-on)"
        } else {
            throw "FAIL POST $Path without authorization -> expected HTTP 401/403 or deploy-gap 404/405, got HTTP $statusCode"
        }
    }
}

function Invoke-SmokePut($Path, $Body, [switch]$RequiresAuth) {
    $uri = [Uri]::new($script:baseUri, $Path)
    $headers = @{}
    if ($RequiresAuth) {
        if ([string]::IsNullOrWhiteSpace($BearerToken)) {
            Write-Host "SKIP $Path (requires auth token)"
            return
        }
        $headers["Authorization"] = "Bearer $BearerToken"
    }

    try {
        $response = Invoke-WebRequest -Uri $uri -Headers $headers -Method PUT -Body $Body -UseBasicParsing -TimeoutSec $TimeoutSec
        Write-Host "PASS PUT $Path -> HTTP $($response.StatusCode)"
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if (-not $statusCode) {
            throw "FAIL PUT $Path -> $($_.Exception.Message)"
        }
        throw "FAIL PUT $Path -> HTTP $statusCode"
    }
}

function Resolve-SmokeAccessToken() {
    if (-not [string]::IsNullOrWhiteSpace($BearerToken)) {
        return $BearerToken
    }

    $resolvedLogin = if ([string]::IsNullOrWhiteSpace($Login)) { [string]$env:EKITAPLIGIM_SMOKE_LOGIN } else { $Login }
    $resolvedPassword = if ([string]::IsNullOrWhiteSpace($Password)) { [string]$env:EKITAPLIGIM_SMOKE_PASSWORD } else { $Password }
    if ([string]::IsNullOrWhiteSpace($resolvedLogin) -and [string]::IsNullOrWhiteSpace($resolvedPassword)) {
        return ""
    }
    if ([string]::IsNullOrWhiteSpace($resolvedLogin) -or [string]::IsNullOrWhiteSpace($resolvedPassword)) {
        throw "Provide both Login and Password, or set both EKITAPLIGIM_SMOKE_LOGIN and EKITAPLIGIM_SMOKE_PASSWORD."
    }

    $uri = [Uri]::new($script:baseUri, "auth/login")
    try {
        $response = Invoke-RestMethod -Uri $uri -Method POST -Body @{ login = $resolvedLogin; password = $resolvedPassword } -TimeoutSec $TimeoutSec
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode) {
            throw "FAIL POST auth/login -> HTTP $statusCode"
        }
        throw "FAIL POST auth/login -> $($_.Exception.Message)"
    }

    $accessToken = [string]$response.access_token
    if (-not $accessToken.StartsWith("ms_at_")) {
        throw "FAIL POST auth/login -> response is missing a valid mobile access token"
    }
    Write-Host "PASS POST auth/login -> authenticated smoke session"
    return $accessToken
}

$normalized = Normalize-BaseUrl $BaseUrl
$script:baseUri = [Uri]$normalized

if ($script:baseUri.Scheme -ne "https" -and -not $AllowInsecure) {
    throw "BaseUrl must use HTTPS unless -AllowInsecure is provided."
}
if (($script:baseUri.Host -match "localhost|127\.0\.0\.1|192\.168\.|^10\.") -and -not $AllowInsecure) {
    throw "BaseUrl points to a local/private host. Use -AllowInsecure only for local development checks."
}

$BearerToken = Resolve-SmokeAccessToken

Write-Step "Running API smoke test against $normalized"
$booksResponse = Invoke-SmokeJsonGet "books?page=1"
if ($booksResponse -and $booksResponse.books -and $booksResponse.books.Count -gt 0) {
    $firstBook = $booksResponse.books | Select-Object -First 1
    $bookDetail = Invoke-SmokeJsonGet "book-detail/$($firstBook.id)"
    if (-not $bookDetail.book -or [string]$bookDetail.book.id -ne [string]$firstBook.id) {
        throw "FAIL book-detail/$($firstBook.id) -> response book id mismatch"
    }
    Invoke-SmokeJsonGet "books/$($firstBook.id)/comments?page=1" | Out-Null
    $readerAccess = Invoke-SmokeJsonGet "books/$($firstBook.id)/reader/access"
    if ($readerAccess.access.can_read_online -ne $false -or
        $readerAccess.access.can_download -ne $false -or
        $readerAccess.access.denial_code -ne "login_required") {
        throw "FAIL books/$($firstBook.id)/reader/access -> guest access must fail closed"
    }
    Write-Host "PASS GET books/$($firstBook.id)/reader/access -> guest access fails closed"
    Assert-SmokeUnauthorizedPost "books/$($firstBook.id)/reader/session"
} else {
    Write-Host "SKIP book-detail/{id} smoke check (no visible books)"
}
$authorsResponse = Invoke-SmokeJsonGet "authors?page=1"
if ($authorsResponse -and $authorsResponse.authors -and $authorsResponse.authors.Count -gt 0) {
    $author = $authorsResponse.authors | Select-Object -First 1
    if (-not $author.slug) {
        throw "FAIL authors -> first author is missing slug"
    }
    Invoke-SmokeJsonGet "authors/$($author.slug)/books?page=1" | Out-Null
} else {
    Write-Host "SKIP author books smoke check (no visible authors)"
}
$publishersResponse = Invoke-SmokeJsonGet "publishers?page=1"
if ($publishersResponse -and $publishersResponse.publishers -and $publishersResponse.publishers.Count -gt 0) {
    $publisher = $publishersResponse.publishers | Select-Object -First 1
    if (-not $publisher.slug) {
        throw "FAIL publishers -> first publisher is missing slug"
    }
    Invoke-SmokeJsonGet "publishers/$($publisher.slug)/books?page=1" | Out-Null
} else {
    Write-Host "SKIP publisher books smoke check (no visible publishers)"
}
$bookRequestsResponse = Invoke-SmokeJsonGet "book-requests?page=1"
if ($bookRequestsResponse -and -not $bookRequestsResponse.book_requests -and -not $bookRequestsResponse.items) {
    throw "FAIL book-requests -> response missing request collection"
}
$membersResponse = Invoke-SmokeJsonGet "members?page=1&per_page=2&sort=alphabetical"
if ($membersResponse -and $membersResponse.members -and $membersResponse.members.Count -gt 0) {
    $member = $membersResponse.members | Select-Object -First 1
    Invoke-SmokeJsonGet "member-detail/$($member.id)" | Out-Null
}
$forumsResponse = Invoke-SmokeJsonGet "forums"
$probeThreadId = $null
if ($forumsResponse -and $forumsResponse.forums -and $forumsResponse.forums.Count -gt 0) {
    $forum = $forumsResponse.forums | Where-Object { $_.threadCount -gt 0 } | Select-Object -First 1
    if (-not $forum) {
        $forum = $forumsResponse.forums | Select-Object -First 1
    }

    if (-not $forum.url) {
        throw "FAIL forums -> first forum is missing url"
    }

    $threadsResponse = Invoke-SmokeJsonGet "forums/$($forum.id)/threads?page=1"
    if ($threadsResponse -and $threadsResponse.threads -and $threadsResponse.threads.Count -gt 0) {
        $thread = $threadsResponse.threads | Select-Object -First 1
        $probeThreadId = [string]$thread.id
        try {
            Invoke-SmokeJsonGet "threads/$probeThreadId/posts?page=1" | Out-Null
        } catch {
            if ("$($_.Exception.Message)" -match "HTTP 404") {
                Write-Host "WARN GET threads/$probeThreadId/posts?page=1 -> HTTP 404 (deploy IosApi ThreadPosts Pub wrapper)"
            } else {
                throw
            }
        }
    } else {
        Write-Host "SKIP threads/{id}/posts (selected forum has no visible threads)"
    }
} else {
    Write-Host "SKIP forum thread/post smoke checks (no visible forums)"
}

Write-Step "Probing UGC write routes fail closed without auth"
Assert-SmokeUnauthorizedPost "book-requests" @{
    title = "parity probe"
    author = "probe"
}
Assert-SmokeUnauthorizedPost "book-agenda" @{
    message = "parity probe"
    post_type = "standard"
    visibility = "public"
}
if ($booksResponse -and $booksResponse.books -and $booksResponse.books.Count -gt 0) {
    $probeBookId = [string]($booksResponse.books | Select-Object -First 1).id
    Assert-SmokeUnauthorizedPost "books/$probeBookId/comments" @{
        message = "parity probe"
        rating = "4"
    }
    Assert-SmokeUnauthorizedPut "me/library/$probeBookId" @{
        shelf_state = "OKUYORUM"
        progress_percent = "0"
        last_read_page = "0"
    }
} else {
    Write-Host "SKIP books/{id}/comments and me/library/{id} write probes (no visible books)"
}
$chatRoomsProbe = Invoke-SmokeJsonGet "chat/rooms"
if ($chatRoomsProbe -and $chatRoomsProbe.rooms -and $chatRoomsProbe.rooms.Count -gt 0) {
    $probeRoomId = [string]$chatRoomsProbe.rooms[0].id
    Assert-SmokeUnauthorizedPost "chat/rooms/$probeRoomId/messages" @{
        message = "parity probe"
    }
} else {
    Write-Host "SKIP chat/rooms/{id}/messages write probe (no visible chat rooms)"
}
if ($probeThreadId) {
    Assert-SmokeProtectedPost "threads/$probeThreadId/posts" @{
        message = "parity probe"
    }
} else {
    Write-Host "SKIP threads/{id}/posts write probe (no visible thread)"
}
if ($forumsResponse -and $forumsResponse.forums -and $forumsResponse.forums.Count -gt 0) {
    $probeForumId = [string]$forumsResponse.forums[0].id
    Assert-SmokeProtectedPost "forums/$probeForumId/threads" @{
        title = "parity probe"
        message = "parity probe"
    }
} else {
    Write-Host "SKIP forums/{id}/threads write probe (no visible forums)"
}

Invoke-SmokeGet "book-stats"
Invoke-SmokeGet "me" -RequiresAuth
Invoke-SmokeGet "me/library" -RequiresAuth
Invoke-SmokeGet "me/comments?page=1" -RequiresAuth
Invoke-SmokeGet "me/subscription" -RequiresAuth
Invoke-SmokeGet "me/terms" -RequiresAuth
Invoke-SmokePost "me/terms/accept" @{ version = "2026-07" } -RequiresAuth
Invoke-SmokeGet "me/notifications/counts" -RequiresAuth
$conversationsResponse = Invoke-SmokeJsonGet "conversations?page=1" -RequiresAuth
if ($conversationsResponse -and $conversationsResponse.conversations -and $conversationsResponse.conversations.Count -gt 0) {
    $conversation = $conversationsResponse.conversations | Select-Object -First 1
    Invoke-SmokeJsonGet "conversation-detail/$($conversation.id)" -RequiresAuth | Out-Null
}

if ($ExerciseMutations) {
    if ([string]::IsNullOrWhiteSpace($BearerToken)) {
        Write-Host "SKIP mutation smoke checks (requires auth token)"
    } else {
        $mutationBookId = $BookId
        if ($mutationBookId -le 1 -and $booksResponse -and $booksResponse.books -and $booksResponse.books.Count -gt 0) {
            $mutationBookId = [int]($booksResponse.books | Select-Object -First 1).id
        }
        Write-Step "Running authenticated mutation smoke checks for book $mutationBookId"
        Invoke-SmokePost "books/$mutationBookId/reader/progress" @{
            position_type = "page"
            position_value = "1"
            progress_percent = "1"
        } -RequiresAuth
        $readerAccess = Invoke-SmokeJsonGet "books/$mutationBookId/reader/access" -RequiresAuth
        $canReadOnline = $false
        if ($readerAccess.access) {
            $canReadOnline = [bool]$readerAccess.access.can_read_online
            if (-not $canReadOnline) { $canReadOnline = [bool]$readerAccess.access.canReadOnline }
        }
        if (-not $canReadOnline) {
            Write-Host "SKIP books/$mutationBookId/reader/session (authenticated user cannot read this catalog book)"
        } else {
        $session = Invoke-SmokePostJson "books/$mutationBookId/reader/session" @{ purpose = "read" } -RequiresAuth
        $sessionSourceUrl = if ($session.source_url) { [string]$session.source_url } else { [string]$session.sourceUrl }
        if (-not $sessionSourceUrl) {
            throw "FAIL books/$mutationBookId/reader/session -> response missing source URL"
        }
        if (-not $AllowInsecure -and -not $sessionSourceUrl.StartsWith("https://")) {
            throw "FAIL books/$mutationBookId/reader/session -> source URL must be HTTPS for App Store builds"
        }
        Write-Host "PASS POST books/$mutationBookId/reader/session (read) -> authorized reader session"

        if ($readerAccess.access.can_download -eq $true) {
            $downloadSession = Invoke-SmokePostJson "books/$mutationBookId/reader/session" @{ purpose = "download" } -RequiresAuth
            $downloadSourceUrl = if ($downloadSession.source_url) { [string]$downloadSession.source_url } else { [string]$downloadSession.sourceUrl }
            if (-not $downloadSourceUrl) {
                throw "FAIL books/$mutationBookId/reader/session (download) -> response missing source URL"
            }
            if (-not $AllowInsecure -and -not $downloadSourceUrl.StartsWith("https://")) {
                throw "FAIL books/$mutationBookId/reader/session (download) -> source URL must be HTTPS for App Store builds"
            }
            Write-Host "PASS POST books/$mutationBookId/reader/session (download) -> authorized download session"
        } else {
            Write-Host "SKIP download reader session (disposable user lacks download entitlement)"
        }
        }

        Invoke-SmokePut "me/library/$mutationBookId" @{
            shelf_state = "OKUYORUM"
            progress_percent = "1"
            last_read_page = "1"
        } -RequiresAuth

        Write-Step "Running authenticated UGC mutation smoke checks"
        $stamp = Get-Date -Format "yyyyMMddHHmmss"

        $bookRequest = Invoke-SmokePostJson "book-requests" @{
            title = "iOS Smoke Request $stamp"
            author = "Smoke Author"
        } -RequiresAuth
        if (-not $bookRequest) {
            throw "FAIL POST book-requests -> empty response"
        }
        Write-Host "PASS POST book-requests -> created request"
        $requestId = $null
        if ($bookRequest.request) { $requestId = [string]$bookRequest.request.id }
        if (-not $requestId -and $bookRequest.id) { $requestId = [string]$bookRequest.id }
        if ($requestId) {
            Invoke-SmokePostJson "book-requests/$requestId/vote" @{} -RequiresAuth | Out-Null
            Write-Host "PASS POST book-requests/$requestId/vote -> toggled vote"
        } else {
            Write-Host "SKIP book-request vote (create response missing id)"
        }

        Invoke-SmokePostJson "books/$mutationBookId/comments" @{
            message = "iOS smoke comment $stamp"
            rating = "4"
        } -RequiresAuth | Out-Null
        Write-Host "PASS POST books/$mutationBookId/comments -> created comment"

        $agendaPost = Invoke-SmokePostJson "book-agenda" @{
            message = "iOS smoke agenda $stamp"
            post_type = "standard"
            visibility = "public"
        } -RequiresAuth
        if (-not $agendaPost) {
            throw "FAIL POST book-agenda -> empty response"
        }
        Write-Host "PASS POST book-agenda -> created post"

        $chatRooms = Invoke-SmokeJsonGet "chat/rooms"
        if ($chatRooms -and $chatRooms.rooms -and $chatRooms.rooms.Count -gt 0) {
            $roomId = [string]$chatRooms.rooms[0].id
            Invoke-SmokePostJson "chat/rooms/$roomId/messages" @{
                message = "iOS smoke chat $stamp"
            } -RequiresAuth | Out-Null
            Write-Host "PASS POST chat/rooms/$roomId/messages -> sent message"
        } else {
            Write-Host "SKIP chat message mutation (no visible chat rooms)"
        }

        if ($forumsResponse -and $forumsResponse.forums -and $forumsResponse.forums.Count -gt 0) {
            $forumId = [string]$forumsResponse.forums[0].id
            try {
                $createdThread = Invoke-SmokePostJson "forums/$forumId/threads" @{
                    title = "iOS Smoke Thread $stamp"
                    message = "Automated UGC smoke test message."
                } -RequiresAuth
                if (-not $createdThread.thread -and -not $createdThread.id) {
                    throw "response missing thread payload"
                }
                Write-Host "PASS POST forums/$forumId/threads -> created thread"
                $threadId = $null
                if ($createdThread.thread) { $threadId = [string]$createdThread.thread.id }
                if (-not $threadId) { $threadId = [string]$createdThread.id }
                if ($threadId) {
                    Invoke-SmokePostJson "threads/$threadId/posts" @{
                        message = "iOS smoke reply $stamp"
                    } -RequiresAuth | Out-Null
                    Write-Host "PASS POST threads/$threadId/posts -> created reply"
                }
            } catch {
                $statusCode = $_.Exception.Response.StatusCode.value__
                if ($statusCode -eq 404 -or $statusCode -eq 405) {
                    Write-Host "WARN POST forums/$forumId/threads -> HTTP $statusCode (deploy IosApi ForumThreads actionPost to enable)"
                } else {
                    throw
                }
            }
        } else {
            Write-Host "SKIP forum thread mutation (no visible forums)"
        }
    }
}

Write-Host "API smoke test completed."
