[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Find-SwiftExecutable {
    $command = Get-Command swift.exe -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $candidates = Get-ChildItem "$env:LOCALAPPDATA\Programs\Swift\Toolchains\*\usr\bin\swift.exe" -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending
    if ($candidates) {
        return $candidates[0].FullName
    }

    throw "Swift for Windows was not found. Install the official Swift toolchain first."
}

function Find-VsDevCmd {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path -LiteralPath $vswhere) {
        $installationPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
        if ($installationPath) {
            $candidate = Join-Path $installationPath "Common7\Tools\VsDevCmd.bat"
            if (Test-Path -LiteralPath $candidate) {
                return $candidate
            }
        }
    }

    $candidate = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\VsDevCmd.bat"
    if (Test-Path -LiteralPath $candidate) {
        return $candidate
    }

    throw "Visual Studio C++ build tools were not found. Install the x64 MSVC toolchain first."
}

$swift = Find-SwiftExecutable
$swiftBin = Split-Path $swift
$toolchainRoot = Resolve-Path (Join-Path $swiftBin "..\..")
$swiftRoot = Resolve-Path (Join-Path $toolchainRoot "..\..")
$runtimeBin = Join-Path $swiftRoot "Runtimes\$((Split-Path $toolchainRoot -Leaf) -replace '\+Asserts$','')\usr\bin"
$sdkRoot = [Environment]::GetEnvironmentVariable("SDKROOT", "User")

if (-not $sdkRoot) {
    $sdkCandidates = Get-ChildItem (Join-Path $swiftRoot "Platforms\*\Windows.platform\Developer\SDKs\Windows.sdk") -Directory -ErrorAction SilentlyContinue
    if ($sdkCandidates) {
        $sdkRoot = $sdkCandidates[0].FullName
    }
}
if (-not $sdkRoot -or -not (Test-Path -LiteralPath $sdkRoot)) {
    throw "Swift Windows SDKROOT was not found."
}
if (-not (Test-Path -LiteralPath $runtimeBin)) {
    throw "Swift runtime directory was not found: $runtimeBin"
}

$vsDevCmd = Find-VsDevCmd
$command = '"{0}" -arch=amd64 -host_arch=amd64 && set "PATH={1};{2};!PATH!" && set "SDKROOT={3}" && swift test --parallel' -f $vsDevCmd, $swiftBin, $runtimeBin, $sdkRoot

Push-Location $root
try {
    & cmd.exe /v:on /d /s /c $command
    if ($LASTEXITCODE -ne 0) {
        throw "swift test failed with exit code $LASTEXITCODE"
    }
} finally {
    Pop-Location
}

Write-Host "Swift core test suite passed."
