# Publish.ps1 — pre-flight checks + publish this mod to Paradox Mods.
#
# Publishing needs the official CSII Modding Toolchain (it ships ModPublisher.exe and the
# Publish/NewVersion/Update targets) and a game session that is logged into your PDX account.
# Everything else — editing sources, local builds — works without it (see tools/BuildLocal.ps1).
#
# Usage:
#   pwsh -File tools/Publish.ps1                     # pre-flight checks only, publishes nothing
#   pwsh -File tools/Publish.ps1 -Mode NewMod        # FIRST upload ever  (ModId must be empty)
#   pwsh -File tools/Publish.ps1 -Mode NewVersion    # every later upload (ModId must be set)
#   pwsh -File tools/Publish.ps1 -Mode UpdateConfig  # metadata only, no new version
#   pwsh -File tools/Publish.ps1 -Mode NewVersion -SkipChecks

[CmdletBinding()]
param(
    [ValidateSet('Check', 'NewMod', 'NewVersion', 'UpdateConfig')]
    [string]$Mode = 'Check',
    [switch]$SkipChecks
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $root 'Properties\PublishConfiguration.xml'
$profiles = @{
    NewMod       = 'PublishNewMod'
    NewVersion   = 'PublishNewVersion'
    UpdateConfig = 'UpdatePublishedConfiguration'
}

$problems = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]
$infos = New-Object System.Collections.Generic.List[string]

# --- PublishConfiguration.xml -------------------------------------------------------------
if (-not (Test-Path $configPath)) { throw "Missing $configPath" }
[xml]$cfg = Get-Content $configPath -Raw
$pub = $cfg.Publish
$modId = if ($pub.ModId) { $pub.ModId.Value } else { '' }
$displayName = $pub.DisplayName.Value
$modVersion = $pub.ModVersion.Value
$gameVersion = $pub.GameVersion.Value

$infos.Add("mod          : $displayName")
$infos.Add("version      : $modVersion  (declared game version: $gameVersion)")
$infos.Add("ModId        : $(if ($modId) { $modId } else { '<empty>' })")

# --- the CSII toolchain -------------------------------------------------------------------
$toolPath = [Environment]::GetEnvironmentVariable('CSII_TOOLPATH', 'User')
if (-not $toolPath) { $toolPath = $env:CSII_TOOLPATH }
if (-not $toolPath) {
    $problems.Add('CSII_TOOLPATH is not set - the CSII Modding Toolchain is not installed.')
    $problems.Add('  Install it from the running game: Options -> Modding -> Install every row.')
} else {
    foreach ($f in 'Mod.props', 'Mod.targets') {
        if (-not (Test-Path (Join-Path $toolPath $f))) {
            $problems.Add("$f not found in CSII_TOOLPATH ($toolPath) - toolchain install is incomplete.")
        }
    }
    $infos.Add("toolchain    : $toolPath")
    # ModPublisher ships with the game (not inside CSII_TOOLPATH) and is located through its own variable.
    $publisherPath = [Environment]::GetEnvironmentVariable('CSII_MODPUBLISHERPATH', 'User')
    if (-not $publisherPath) { $publisherPath = $env:CSII_MODPUBLISHERPATH }
    if ($publisherPath -and (Test-Path $publisherPath)) {
        $infos.Add("publisher    : $publisherPath")
    } else {
        $found = Get-ChildItem $toolPath -Recurse -Filter 'ModPublisher.exe' -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($found) { $infos.Add("publisher    : $($found.FullName)") }
        else { $problems.Add('ModPublisher.exe not found (CSII_MODPUBLISHERPATH is unset or invalid).') }
    }
}

# --- metadata sanity ----------------------------------------------------------------------
switch ($Mode) {
    'NewMod' {
        if ($modId) {
            $problems.Add("ModId is '$modId'. A first upload must have an EMPTY <ModId Value=`"`" /> - " +
                'an existing id belongs to the account that published it and cannot be updated from yours.')
        }
    }
    { $_ -in 'NewVersion', 'UpdateConfig' } {
        if (-not $modId) {
            $problems.Add("ModId is empty but mode '$Mode' needs the id returned by the first upload " +
                '(publish with -Mode NewMod first, then copy the printed id into PublishConfiguration.xml).')
        }
    }
}

$longDesc = "$($pub.LongDescription)"
if ($longDesc -match 'REPLACE_WITH_YOUR_NAME') {
    $problems.Add('LongDescription still contains the REPLACE_WITH_YOUR_NAME placeholder.')
}
if ("$($pub.ExternalLink.Url)" -match 'Jimmyokok') {
    $warnings.Add('ExternalLink still points at the ORIGINAL author''s repository, not at your fork.')
}
if ("$($pub.Dependency.Id)" -eq '' -and $pub.Dependency) {
    $infos.Add('dependency   : none (upstream has no shared libraries)')
}

# --- field limits enforced by ModPublisher (learned from its validation errors) -----------
$shortDesc = "$($pub.ShortDescription.Value)"
if ($shortDesc.Length -lt 1 -or $shortDesc.Length -gt 200) {
    $problems.Add("ShortDescription is $($shortDesc.Length) characters. ModPublisher requires 1-200 " +
        '("shortDescription: Must be a string between 1 and 200 length").')
} elseif ($shortDesc.Length -gt 190) {
    $warnings.Add("ShortDescription is $($shortDesc.Length)/200 characters - very close to the limit.")
}
if (-not "$($pub.DisplayName.Value)") { $problems.Add('DisplayName is empty.') }
if (-not "$($pub.ModVersion.Value)") { $problems.Add('ModVersion is empty.') }
if (-not (Test-Path (Join-Path $root $pub.Thumbnail.Value))) {
    $problems.Add('Thumbnail file is missing - PDX Mods requires one.')
}

foreach ($asset in @($pub.Thumbnail.Value) + @($pub.Screenshot | ForEach-Object { $_.Value })) {
    if ($asset -and -not (Test-Path (Join-Path $root $asset))) {
        $problems.Add("Metadata references a missing file: $asset")
    }
}

# --- report -------------------------------------------------------------------------------
Write-Host ''
foreach ($i in $infos) { Write-Host "  $i" }
Write-Host ''
foreach ($w in $warnings) { Write-Host "  [warn]  $w" -ForegroundColor Yellow }
foreach ($p in $problems) { Write-Host "  [block] $p" -ForegroundColor Red }
if ($warnings.Count -eq 0 -and $problems.Count -eq 0) { Write-Host '  pre-flight: all good' -ForegroundColor Green }
Write-Host ''

if ($Mode -eq 'Check') {
    Write-Host 'Done (checks only). Re-run with -Mode NewMod / NewVersion / UpdateConfig to publish.'
    if ($problems.Count -eq 0) { exit 0 } else { exit 1 }
}
if ($problems.Count -gt 0) {
    Write-Host 'Aborting: fix the [block] items above first.' -ForegroundColor Red
    exit 1
}
if ($SkipChecks) { Write-Host 'Proceeding (checks skipped).' }

# --- publish ------------------------------------------------------------------------------
$profile = $profiles[$Mode]
Write-Host "Publishing via publish profile '$profile' ..." -ForegroundColor Cyan
Write-Host 'ModPublisher authenticates through the PDX account logged into the game.' -ForegroundColor DarkGray

Push-Location $root
try {
    & dotnet publish -c Release -p:PublishProfile=$profile
    $code = $LASTEXITCODE
} finally {
    Pop-Location
}

if ($code -ne 0) {
    Write-Host "`nPublish failed (exit $code). Check the ModPublisher output above for the real reason:" -ForegroundColor Red
    Write-Host '  * "Must be a string between 1 and 200 length"  -> a metadata field is too long' -ForegroundColor Gray
    Write-Host '  * "Could not auto log in: You were not logged in before"' -ForegroundColor Gray
    Write-Host '      -> start the game, log into your Paradox account, quit the game, run this again' -ForegroundColor Gray
    Write-Host '  * "ACCESS_DENIED" / "IOERR_103"' -ForegroundColor Gray
    Write-Host '      -> the game is still running and locking the Mods folder: close it first' -ForegroundColor Gray
    Write-Host '  * profile not recognised -> publish from the IDE instead:' -ForegroundColor Gray
    Write-Host "      Visual Studio 2022: right-click the project -> Publish -> $profile" -ForegroundColor Gray
    Write-Host "      Rider: select the '$profile' configuration in the toolbar" -ForegroundColor Gray
    exit $code
}

if ($Mode -eq 'NewMod') {
    Write-Host "`nNext: copy the ModId printed above into <ModId Value=`"...`" /> in" -ForegroundColor Yellow
    Write-Host 'Properties\PublishConfiguration.xml, then use -Mode NewVersion from now on.' -ForegroundColor Yellow
} else {
    Write-Host "`nPublished $displayName $modVersion." -ForegroundColor Green
}
