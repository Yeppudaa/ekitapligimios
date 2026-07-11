param(
    [Parameter(Mandatory = $true)]
    [string]$BaseUrl,

    [string]$BearerToken = "",

    [switch]$AllowInsecure,

    [switch]$ExerciseMutations,

    [int]$BookId = 1,

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

    try {
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method POST -Body $Body -TimeoutSec $TimeoutSec
        Write-Host "PASS POST $Path -> JSON"
        return $response
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if (-not $statusCode) {
            throw "FAIL POST $Path -> $($_.Exception.Message)"
        }
        throw "FAIL POST $Path -> HTTP $statusCode"
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

$normalized = Normalize-BaseUrl $BaseUrl
$script:baseUri = [Uri]$normalized

if ($script:baseUri.Scheme -ne "https" -and -not $AllowInsecure) {
    throw "BaseUrl must use HTTPS unless -AllowInsecure is provided."
}
if (($script:baseUri.Host -match "localhost|127\.0\.0\.1|192\.168\.|^10\.") -and -not $AllowInsecure) {
    throw "BaseUrl points to a local/private host. Use -AllowInsecure only for local development checks."
}

Write-Step "Running API smoke test against $normalized"
$booksResponse = Invoke-SmokeJsonGet "books?page=1"
if ($booksResponse -and $booksResponse.books -and $booksResponse.books.Count -gt 0) {
    $firstBook = $booksResponse.books | Select-Object -First 1
    $bookDetail = Invoke-SmokeJsonGet "book-detail/$($firstBook.id)"
    if (-not $bookDetail.book -or [string]$bookDetail.book.id -ne [string]$firstBook.id) {
        throw "FAIL book-detail/$($firstBook.id) -> response book id mismatch"
    }
    Invoke-SmokeJsonGet "books/$($firstBook.id)/comments?page=1" | Out-Null
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
        Invoke-SmokeJsonGet "threads/$($thread.id)/posts?page=1" | Out-Null
    } else {
        Write-Host "SKIP threads/{id}/posts (selected forum has no visible threads)"
    }
} else {
    Write-Host "SKIP forum thread/post smoke checks (no visible forums)"
}
Invoke-SmokeGet "book-stats"
Invoke-SmokeGet "me" -RequiresAuth
Invoke-SmokeGet "me/library" -RequiresAuth
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
        $session = Invoke-SmokePostJson "books/$mutationBookId/reader/session" @{} -RequiresAuth
        $sessionSourceUrl = if ($session.source_url) { [string]$session.source_url } else { [string]$session.sourceUrl }
        if (-not $sessionSourceUrl) {
            throw "FAIL books/$mutationBookId/reader/session -> response missing source URL"
        }
        if (-not $AllowInsecure -and -not $sessionSourceUrl.StartsWith("https://")) {
            throw "FAIL books/$mutationBookId/reader/session -> source URL must be HTTPS for App Store builds"
        }
        Invoke-SmokePut "me/library/$mutationBookId" @{
            shelf_state = "reading"
            progress_percent = "1"
            last_read_page = "1"
        } -RequiresAuth
    }
}

Write-Host "API smoke test completed."
