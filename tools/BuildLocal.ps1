# BuildLocal.ps1 — build this mod for local use *without* the CSII Modding Toolchain, then
# install it into the game's local Mods folder.
#
# Why this works: the mod contains no [BurstCompile] code, so the toolchain's
# ModPostProcessor.exe (IL post-processing + Burst) is not required. All that is needed is a
# compile against the game's own managed assemblies, plus 0Harmony.dll next to the result.
#
# What this script does NOT replace: publishing to PDX Mods. That goes through the toolchain's
# Publish targets and ModPublisher, so a release still needs the toolchain (Options -> Modding).
# The .csproj in this repo is the toolchain-based build and stays the source of truth for releases.
#
# Usage:
#   pwsh -File tools/BuildLocal.ps1              # compile + install into Mods\ConfigurableElevatedRoad
#   pwsh -File tools/BuildLocal.ps1 -NoDeploy    # compile only (quick API-compatibility check)
#   pwsh -File tools/BuildLocal.ps1 -ModsDir D:\tmp\Mods -Force

[CmdletBinding()]
param(
    [string]$GamePath = '',
    [string]$ModsDir = '',
    [string]$OutDir = '',
    [switch]$NoDeploy,
    [switch]$Force,
    [switch]$DebugBuild
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$modName = 'ConfigurableElevatedRoad'
if (-not $OutDir) { $OutDir = Join-Path $root 'bin\local' }
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }

function Find-GamePath {
    param([string]$Explicit)
    if ($Explicit) { return $Explicit }
    foreach ($v in 'CSII_INSTALLATIONPATH', 'CSII_MANAGEDPATH') {
        $p = [System.Environment]::GetEnvironmentVariable($v, 'User')
        if ($p) {
            if (Test-Path (Join-Path $p 'Cities2_Data\Managed\Game.dll')) { return $p }
            if (Test-Path (Join-Path $p 'Game.dll')) { return (Split-Path -Parent (Split-Path -Parent $p)) }
        }
    }
    $libs = @()
    foreach ($reg in 'HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam') {
        if (Test-Path $reg) {
            $steam = (Get-ItemProperty $reg).SteamPath
            if ($steam) {
                $libs += $steam
                $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
                if (Test-Path $vdf) {
                    foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"')) {
                        $libs += ($m.Groups[1].Value -replace '\\\\', '\')
                    }
                }
            }
        }
    }
    foreach ($l in ($libs | Select-Object -Unique)) {
        $candidate = Join-Path $l 'steamapps\common\Cities Skylines II'
        if (Test-Path (Join-Path $candidate 'Cities2_Data\Managed\Game.dll')) { return $candidate }
    }
    return ''
}

function Find-ModsDir {
    param([string]$Explicit)
    if ($Explicit) { return $Explicit }
    $p = [System.Environment]::GetEnvironmentVariable('CSII_LOCALMODSPATH', 'User')
    if ($p) { return $p }
    return (Join-Path $env:USERPROFILE 'AppData\LocalLow\Colossal Order\Cities Skylines II\Mods')
}

$game = Find-GamePath $GamePath
if (-not $game) { throw 'Cities Skylines II install not found. Pass -GamePath "<game install>".' }
$managed = Join-Path $game 'Cities2_Data\Managed'
Write-Host "game    : $game"

# Locate Roslyn's csc.dll inside the newest installed .NET SDK.
$sdkLine = (& dotnet --list-sdks 2>$null) |
    Where-Object { $_ -match '^\s*(?<ver>\d+\.\d+\.\d+)\s+\[(?<root>.+)\]\s*$' } |
    Select-Object -Last 1
if (-not $sdkLine) { throw 'No .NET SDK found. Install one from https://dotnet.microsoft.com/download/dotnet' }
$null = $sdkLine -match '^\s*(?<ver>\d+\.\d+\.\d+)\s+\[(?<root>.+)\]\s*$'
$csc = Join-Path $Matches['root'] "$($Matches['ver'])\Roslyn\bincore\csc.dll"
if (-not (Test-Path $csc)) { throw "csc.dll not found at $csc" }
Write-Host "compiler: $csc"

$sources = Get-ChildItem -Path $root -Recurse -Filter *.cs |
    Where-Object { $_.FullName -notmatch '\\(\.apibrowse|obj|bin|tools)\\' } |
    ForEach-Object { $_.FullName }
Write-Host "sources : $($sources.Count) file(s)"

# The game's own managed folder is the complete reference set (BCL + engine + Colossal.*).
$refs = @()
foreach ($dll in (Get-ChildItem $managed -Filter *.dll)) { $refs += "/r:`"$($dll.FullName)`"" }
$harmony = Join-Path $root 'PMOD_Release\0Harmony.dll'
if (Test-Path $harmony) { $refs += "/r:`"$harmony`"" }
else { Write-Warning 'PMOD_Release\0Harmony.dll not found; Harmony references will not resolve.' }

$out = Join-Path $OutDir "$modName.dll"
$optArgs = if ($DebugBuild) { @('/define:DEBUG;TRACE', '/optimize-') } else { @('/define:TRACE', '/optimize+') }
$rsp = Join-Path $OutDir 'csc.rsp'
$lines = @(
    '/nostdlib+', '/nologo', '/target:library', '/langversion:latest', '/unsafe+', '/deterministic+',
    '/warn:4', '/nowarn:1701,1702', "/out:`"$out`""
) + $optArgs + $refs + $sources
Set-Content -Path $rsp -Value $lines -Encoding utf8

& dotnet $csc "@$rsp"
if ($LASTEXITCODE -ne 0) {
    # A compile failure after a game update almost always means a changed/hidden API surface.
    Write-Host "`nCOMPILE FAILED (exit $LASTEXITCODE). If the game was just updated, the API this mod" -ForegroundColor Red
    Write-Host 'binds to most likely changed. Compare the errors against the current Game.dll.' -ForegroundColor Red
    exit $LASTEXITCODE
}
Write-Host "`nCOMPILE OK -> $out" -ForegroundColor Green

if ($NoDeploy) { exit 0 }

if (-not $Force -and (Get-Process Cities2 -ErrorAction SilentlyContinue)) {
    Write-Warning 'Cities Skylines II is running. Close the game before deploying, or pass -Force to copy anyway.'
    exit 1
}

$target = Join-Path (Find-ModsDir $ModsDir) $modName
New-Item -ItemType Directory -Force -Path $target | Out-Null
Copy-Item $out $target -Force
if (Test-Path $harmony) { Copy-Item $harmony $target -Force }
# Kept for layout parity with a toolchain/PDX build; the mod has no Burst code, so it stays inert.
$nativeStub = Join-Path $root "PMOD_Release\${modName}_win_x86_64.dll"
if (Test-Path $nativeStub) { Copy-Item $nativeStub $target -Force }

Write-Host "`nDEPLOYED -> $target" -ForegroundColor Green
Get-ChildItem $target | Select-Object Name, Length | Format-Table -AutoSize
Write-Host 'Start the game and check Logs\ConfigurableElevatedRoad.log for "OnLoad".'
Write-Host 'If both a PDX subscription and this local copy are enabled, disable the PDX one first.'
