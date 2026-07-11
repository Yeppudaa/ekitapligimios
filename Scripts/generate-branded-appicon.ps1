param(
    [Parameter(Mandatory = $true)]
    [string]$SourcePath
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$iconSet = Join-Path $repoRoot "App/Ekitapligim/Assets.xcassets/AppIcon.appiconset"
$source = Resolve-Path -LiteralPath $SourcePath
$sizes = @(20, 29, 40, 58, 60, 76, 80, 87, 120, 152, 167, 180, 1024)

function Write-OpaqueIcon([System.Drawing.Image]$Image, [int]$Size, [string]$Path) {
    $bitmap = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.Clear([System.Drawing.Color]::White)
        $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.DrawImage($Image, 0, 0, $Size, $Size)
        $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

$image = [System.Drawing.Image]::FromFile($source.Path)
try {
    if ($image.Width -ne $image.Height -or $image.Width -lt 512) {
        throw "Brand icon source must be square and at least 512 pixels: $($image.Width)x$($image.Height)"
    }
    foreach ($size in $sizes) {
        Write-OpaqueIcon -Image $image -Size $size -Path (Join-Path $iconSet "appicon-$size.png")
    }
} finally {
    $image.Dispose()
}

$hash = (Get-FileHash -LiteralPath $source.Path -Algorithm SHA256).Hash.ToLowerInvariant()
$evidence = @"
# App Icon Source

- Source: Android brand asset `drawable-nodpi/app_logo_round.png`
- Source dimensions: 512 x 512
- Source SHA-256: `$hash`
- Output: opaque PNGs generated on white using high-quality bicubic scaling
- Brand approval: required from the Ekitapligim rights holder before App Store submission
"@
Set-Content -LiteralPath (Join-Path $repoRoot "APP_ICON_SOURCE.md") -Value $evidence -Encoding UTF8

Write-Host "Generated branded AppIcon set from $($source.Path)"
