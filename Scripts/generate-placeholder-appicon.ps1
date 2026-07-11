$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$assetRoot = Join-Path $root "App/Ekitapligim/Assets.xcassets"
$iconSet = Join-Path $assetRoot "AppIcon.appiconset"

New-Item -ItemType Directory -Force -Path $iconSet | Out-Null

Add-Type -AssemblyName System.Drawing

function New-IconPng {
    param(
        [int]$Size,
        [string]$Path
    )

    $bitmap = New-Object System.Drawing.Bitmap $Size, $Size
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

    $background = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.Rectangle 0, 0, $Size, $Size),
        [System.Drawing.Color]::FromArgb(30, 93, 141),
        [System.Drawing.Color]::FromArgb(242, 179, 71),
        [System.Drawing.Drawing2D.LinearGradientMode]::ForwardDiagonal
    )
    $graphics.FillRectangle($background, 0, 0, $Size, $Size)

    $margin = [Math]::Max(6, [int]($Size * 0.16))
    $bookRect = New-Object System.Drawing.Rectangle $margin, ([int]($Size * 0.22)), ($Size - 2 * $margin), ([int]($Size * 0.56))
    $whiteBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(245, 248, 250))
    $graphics.FillPie($whiteBrush, $bookRect.X, $bookRect.Y, $bookRect.Width, $bookRect.Height, 180, 180)
    $graphics.FillRectangle($whiteBrush, $bookRect.X, ($bookRect.Y + [int]($bookRect.Height / 2)), $bookRect.Width, [int]($bookRect.Height / 2))

    $linePen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(30, 93, 141)), ([Math]::Max(1, [int]($Size * 0.035)))
    $centerX = [int]($Size / 2)
    $graphics.DrawLine($linePen, $centerX, $bookRect.Y + 4, $centerX, $bookRect.Bottom - 4)
    $arcWidth = [int]($bookRect.Width / 2) - 8
    $arcHeight = $bookRect.Height - 8
    if ($arcWidth -gt 0 -and $arcHeight -gt 0) {
        $graphics.DrawArc($linePen, $bookRect.X + 4, $bookRect.Y + 4, $arcWidth, $arcHeight, 200, 130)
        $graphics.DrawArc($linePen, $centerX + 4, $bookRect.Y + 4, $arcWidth, $arcHeight, 210, 130)
    }

    if ($Size -ge 76) {
        $fontSize = [Math]::Max(14, [int]($Size * 0.18))
        $font = New-Object System.Drawing.Font "Segoe UI", $fontSize, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
        $textBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(30, 93, 141))
        $text = "E"
        $textSize = $graphics.MeasureString($text, $font)
        $graphics.DrawString($text, $font, $textBrush, (($Size - $textSize.Width) / 2), ([int]($Size * 0.39)))
        $font.Dispose()
        $textBrush.Dispose()
    }

    $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)

    $linePen.Dispose()
    $whiteBrush.Dispose()
    $background.Dispose()
    $graphics.Dispose()
    $bitmap.Dispose()
}

$images = @(
    @{ idiom = "iphone"; size = "20x20"; scale = "2x"; pixels = 40 },
    @{ idiom = "iphone"; size = "20x20"; scale = "3x"; pixels = 60 },
    @{ idiom = "iphone"; size = "29x29"; scale = "2x"; pixels = 58 },
    @{ idiom = "iphone"; size = "29x29"; scale = "3x"; pixels = 87 },
    @{ idiom = "iphone"; size = "40x40"; scale = "2x"; pixels = 80 },
    @{ idiom = "iphone"; size = "40x40"; scale = "3x"; pixels = 120 },
    @{ idiom = "iphone"; size = "60x60"; scale = "2x"; pixels = 120 },
    @{ idiom = "iphone"; size = "60x60"; scale = "3x"; pixels = 180 },
    @{ idiom = "ipad"; size = "20x20"; scale = "1x"; pixels = 20 },
    @{ idiom = "ipad"; size = "20x20"; scale = "2x"; pixels = 40 },
    @{ idiom = "ipad"; size = "29x29"; scale = "1x"; pixels = 29 },
    @{ idiom = "ipad"; size = "29x29"; scale = "2x"; pixels = 58 },
    @{ idiom = "ipad"; size = "40x40"; scale = "1x"; pixels = 40 },
    @{ idiom = "ipad"; size = "40x40"; scale = "2x"; pixels = 80 },
    @{ idiom = "ipad"; size = "76x76"; scale = "1x"; pixels = 76 },
    @{ idiom = "ipad"; size = "76x76"; scale = "2x"; pixels = 152 },
    @{ idiom = "ipad"; size = "83.5x83.5"; scale = "2x"; pixels = 167 },
    @{ idiom = "ios-marketing"; size = "1024x1024"; scale = "1x"; pixels = 1024 }
)

$jsonImages = @()
foreach ($image in $images) {
    $filename = "appicon-$($image.pixels).png"
    New-IconPng -Size $image.pixels -Path (Join-Path $iconSet $filename)
    $jsonImages += [ordered]@{
        idiom = $image.idiom
        size = $image.size
        scale = $image.scale
        filename = $filename
    }
}

$contents = [ordered]@{
    images = $jsonImages
    info = [ordered]@{
        author = "xcode"
        version = 1
    }
}

$contents | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $iconSet "Contents.json") -Encoding UTF8

$assetContents = [ordered]@{
    info = [ordered]@{
        author = "xcode"
        version = 1
    }
}
$assetContents | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $assetRoot "Contents.json") -Encoding UTF8

Write-Host "Generated placeholder AppIcon asset set at $iconSet"
