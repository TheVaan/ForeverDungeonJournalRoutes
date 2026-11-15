<#
.SYNOPSIS
    Builds the addon like the release packager would and copies it into the WoW AddOns folder (local testing).

.DESCRIPTION
    - copies the addon files, leaving out everything in the .pkgmeta "ignore" list, dotfiles and this script
    - replaces @project-version@ in the .toc with the output of `git describe`
    - replaces <AddOns>\<package-as> with the result

    The AddOns folder is taken from (first match wins):
      1. -Destination
      2. the environment variable WOW_ADDONS_DIR
      3. WOW_ADDONS_DIR=... in a .env file next to this script (.env is git-ignored)

    Example .env:
      WOW_ADDONS_DIR=C:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns

.EXAMPLE
    .\build.ps1
.EXAMPLE
    .\build.ps1 -Destination "D:\WoW\_retail_\Interface\AddOns"
.EXAMPLE
    .\build.ps1 -Version 0.2.0-test
#>
[CmdletBinding()]
param(
    [string]$Destination,
    [string]$Version
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

# --- destination -------------------------------------------------------------
if (-not $Destination) { $Destination = $env:WOW_ADDONS_DIR }
if (-not $Destination -and (Test-Path (Join-Path $root '.env'))) {
    foreach ($line in Get-Content (Join-Path $root '.env')) {
        if ($line -match '^\s*WOW_ADDONS_DIR\s*=\s*(.+?)\s*$') { $Destination = $Matches[1].Trim('"', "'") }
    }
}
if (-not $Destination) {
    throw "No AddOns folder set. Pass -Destination, set WOW_ADDONS_DIR, or add 'WOW_ADDONS_DIR=<path>' to .env (see the header of build.ps1)."
}
if (-not (Test-Path -LiteralPath $Destination -PathType Container)) {
    throw "AddOns folder does not exist: $Destination"
}

# --- package name and ignore list from .pkgmeta --------------------------------
$name = 'ForeverDungeonJournalRoutes'
$ignore = @()
$pkgmeta = Join-Path $root '.pkgmeta'
if (Test-Path $pkgmeta) {
    $section = ''
    foreach ($line in Get-Content $pkgmeta) {
        if ($line -match '^package-as:\s*(\S+)') { $name = $Matches[1]; continue }
        if ($line -match '^(\S[^:]*):') { $section = $Matches[1]; continue }
        if ($section -eq 'ignore' -and $line -match '^\s+-\s*(\S+)') { $ignore += $Matches[1] }
    }
}
# never part of the addon: this script, repo/dev files
$ignore += 'build.ps1'

# --- version -------------------------------------------------------------------
if (-not $Version) {
    $Version = (& git -C $root describe --tags --always --dirty 2>$null)
    if (-not $Version) { $Version = 'dev' }
}

# --- stage -----------------------------------------------------------------------
$stage = Join-Path ([IO.Path]::GetTempPath()) "$name-build-$([guid]::NewGuid().ToString('N'))"
$stageAddon = Join-Path $stage $name
New-Item -ItemType Directory -Path $stageAddon | Out-Null

try {
    $rootFull = (Resolve-Path $root).Path.TrimEnd('\')
    Get-ChildItem -LiteralPath $root -Recurse -File -Force | ForEach-Object {
        $rel = $_.FullName.Substring($rootFull.Length + 1)
        $parts = $rel -split '\\'
        if ($parts | Where-Object { $_.StartsWith('.') }) { return }   # .git, .github, .pkgmeta, .env, ...
        foreach ($pattern in $ignore) {
            $p = $pattern.TrimEnd('/')
            if ($rel -like $p -or $rel -like "$p\*" -or $parts[0] -like $p) { return }
        }
        $target = Join-Path $stageAddon $rel
        New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
        Copy-Item -LiteralPath $_.FullName -Destination $target
    }

    # packager keyword replacement (LF line endings, UTF-8 without BOM)
    foreach ($toc in Get-ChildItem -LiteralPath $stageAddon -Filter *.toc) {
        $text = [IO.File]::ReadAllText($toc.FullName).Replace('@project-version@', $Version)
        [IO.File]::WriteAllText($toc.FullName, $text, (New-Object Text.UTF8Encoding $false))
    }

    # --- install ------------------------------------------------------------------
    $target = Join-Path $Destination $name
    if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
    Copy-Item -LiteralPath $stageAddon -Destination $target -Recurse

    $count = (Get-ChildItem -LiteralPath $target -Recurse -File).Count
    Write-Host "Built $name $Version -> $target ($count files)"
}
finally {
    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
}
