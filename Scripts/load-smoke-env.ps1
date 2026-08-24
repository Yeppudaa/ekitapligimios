param(
    [string]$Root = ""
)

$ErrorActionPreference = "Stop"

if (-not $Root) {
    $Root = Resolve-Path (Join-Path $PSScriptRoot "..")
}

function Import-DotEnvFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }

    Get-Content -LiteralPath $Path | ForEach-Object {
        $line = $_.Trim()
        if (-not $line -or $line.StartsWith("#")) {
            return
        }

        $equalsIndex = $line.IndexOf("=")
        if ($equalsIndex -lt 1) {
            return
        }

        $name = $line.Substring(0, $equalsIndex).Trim()
        $value = $line.Substring($equalsIndex + 1).Trim()
        if (
            ($value.StartsWith('"') -and $value.EndsWith('"')) -or
            ($value.StartsWith("'") -and $value.EndsWith("'"))
        ) {
            $value = $value.Substring(1, $value.Length - 2)
        }

        if ($name -match '^EKITAPLIGIM_SMOKE_') {
            Set-Item -Path "Env:$name" -Value $value
        }
    }

    return $true
}

$loaded = Import-DotEnvFile -Path (Join-Path $Root ".env")
if ($loaded) {
    Write-Verbose "Loaded smoke credentials from $(Join-Path $Root '.env')"
}
