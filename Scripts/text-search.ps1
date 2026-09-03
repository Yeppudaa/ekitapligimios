function Find-TextMatches {
    param(
        [Parameter(Mandatory)]
        [string]$Pattern,

        [Parameter(Mandatory)]
        [string[]]$Paths,

        [switch]$SimpleMatch,
        [switch]$IgnoreCase,
        [string]$Include
    )

    $files = foreach ($path in $Paths) {
        if (Test-Path -LiteralPath $path -PathType Container) {
            Get-ChildItem -LiteralPath $path -File -Recurse |
                Where-Object { -not $Include -or $_.Name -like $Include }
        } elseif (Test-Path -LiteralPath $path -PathType Leaf) {
            Get-Item -LiteralPath $path
        }
    }

    $selectStringArguments = @{
        Pattern = $Pattern
        Path = @($files.FullName)
        ErrorAction = "SilentlyContinue"
    }
    if ($SimpleMatch) {
        $selectStringArguments.SimpleMatch = $true
    }
    if (-not $IgnoreCase) {
        $selectStringArguments.CaseSensitive = $true
    }

    $rootPath = (Get-Location).Path.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    @(Select-String @selectStringArguments | ForEach-Object {
        $displayPath = if ($_.Path.StartsWith($rootPath, [StringComparison]::OrdinalIgnoreCase)) {
            $_.Path.Substring($rootPath.Length)
        } else {
            $_.Path
        }
        "{0}:{1}:{2}" -f $displayPath, $_.LineNumber, $_.Line.Trim()
    })
}
