<#
.SYNOPSIS
    Install (or remove) the dsh-theme-sigrika theme in a DeepSeek Harness profile.

.DESCRIPTION
    Route B of the README: no npm, no publishing. The script copies the package
    into $DSH_HOME/themes/<name>/ and writes a marker-delimited row into

        $DSH_HOME/profiles/<profile>/cordis.patch.yml

    so repeated runs replace rather than duplicate, and your own patch entries are
    never touched.

    It then reproduces the Loader's own resolution of that row and rolls it back
    if it would not mount. This matters: a row that names a DIRECTORY instead of
    the entry file fails with ERR_UNSUPPORTED_DIR_IMPORT, and the failure is
    invisible in the UI -- no theme, no error, and the plugin's HTTP routes just
    keep returning 404.

    cordis.patch.yml is read at boot, so restart dsh afterwards.

.PARAMETER Profile
    Profile to install into. Defaults to `desktop`, which is what the packaged
    Electron app uses. A browser-launched `dsh --profile web` needs `-Profile web`.

.PARAMETER Uninstall
    Remove the row and the installed package directory.

.PARAMETER DshHome
    Override the harness config root. Defaults to $env:DSH_HOME, then ~/.dsh.

.EXAMPLE
    pwsh -File install.ps1
    Install into the desktop profile.

.EXAMPLE
    pwsh -File install.ps1 -Profile web
    Install into the web profile.

.EXAMPLE
    pwsh -File install.ps1 -Uninstall
    Remove it again.
#>
[CmdletBinding()]
param(
    [string]$Profile = 'desktop',
    [switch]$Uninstall,
    [string]$DshHome
)

$ErrorActionPreference = 'Stop'

# Keep this script ASCII-only: Windows PowerShell 5.1 reads a BOM-less script
# using the ANSI code page, so a non-ASCII character inside a string literal can
# be mangled into a syntax error.
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
function Write-TextNoBom {
    param([string]$Path, [string]$Text)
    [System.IO.File]::WriteAllText($Path, $Text, $utf8NoBom)
}

$repoDir = $PSScriptRoot
$manifestPath = Join-Path $repoDir 'package.json'
if (-not (Test-Path $manifestPath)) { throw "package.json not found next to this script: $manifestPath" }
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json

$pkgName = $manifest.name
if (-not $pkgName) { throw 'package.json has no name.' }
$rowId = 'theme-' + ($pkgName -replace '^dsh-theme-', '')

if (-not $DshHome) { $DshHome = if ($env:DSH_HOME) { $env:DSH_HOME } else { Join-Path $env:USERPROFILE '.dsh' } }
$profilesDir = Join-Path $DshHome 'profiles'
$themesDir = Join-Path $DshHome 'themes'
$destDir = Join-Path $themesDir $pkgName
$patchFile = Join-Path $profilesDir "$Profile\cordis.patch.yml"

$markerStart = "# >>> $pkgName >>>"
$markerEnd = "# <<< $pkgName <<<"

# -- patch-file surgery ---------------------------------------------------------
# DSH itself APPENDS entries to this file: a settings write-back persists rows
# such as `ui-theme` when the user changes a preference. A position-based marker
# block therefore ends up with someone else's entry inside it, and deleting the
# block deletes their setting along with yours. So this package's row is found by
# CONTENT, never by position, and the block is inserted at the TOP of the file so
# that later appends land outside the markers.
function Remove-ManagedRow {
    if (-not (Test-Path $patchFile)) { return }

    $lines = [System.IO.File]::ReadAllLines($patchFile)
    $kept = New-Object System.Collections.Generic.List[string]

    $i = 0
    while ($i -lt $lines.Count) {
        $line = $lines[$i]

        if ($line.Trim() -eq $markerStart -or $line.Trim() -eq $markerEnd) { $i++; continue }

        $m = [regex]::Match($line, '^(\s*)-\s+id:\s*' + [regex]::Escape($rowId) + '\s*$')
        if ($m.Success) {
            $indent = $m.Groups[1].Value.Length
            $i++
            # consume the entry's own continuation lines; a blank line ends it
            while ($i -lt $lines.Count) {
                $next = $lines[$i]
                if ($next.Trim() -eq '') { break }
                if (($next.Length - $next.TrimStart().Length) -le $indent) { break }
                $i++
            }
            continue
        }

        $kept.Add($line)
        $i++
    }

    # Drop an `- insert:` that no longer has any children.
    $result = New-Object System.Collections.Generic.List[string]
    for ($j = 0; $j -lt $kept.Count; $j++) {
        $line = $kept[$j]
        $m = [regex]::Match($line, '^(\s*)-\s*insert:\s*$')
        if ($m.Success) {
            $indent = $m.Groups[1].Value.Length
            $k = $j + 1
            while ($k -lt $kept.Count -and $kept[$k].Trim() -eq '') { $k++ }
            if ($k -ge $kept.Count) { continue }
            if (($kept[$k].Length - $kept[$k].TrimStart().Length) -le $indent) { continue }
        }
        $result.Add($line)
    }

    # Tidy up blank lines left at the very top by the removal.
    while ($result.Count -gt 0 -and $result[0].Trim() -eq '') { $result.RemoveAt(0) }

    $text = ($result -join "`n").TrimEnd()
    if ($text -eq '') { $text = '[]' }
    Write-TextNoBom -Path $patchFile -Text ($text + "`n")
}

function Write-ManagedRow {
    param([string[]]$Lines)

    # Replace rather than duplicate, without depending on where anything sits.
    Remove-ManagedRow

    $raw = Get-Content -LiteralPath $patchFile -Raw
    if ($null -eq $raw) { $raw = '' }

    # A fresh profile patch is the empty array `[]`; a sequence item placed after
    # it would be invalid YAML, so drop it.
    $effective = ($raw -split "`r?`n" | Where-Object { $_.Trim() -ne '' -and -not $_.Trim().StartsWith('#') }) -join "`n"
    if ($effective.Trim() -eq '[]') { $raw = '' }

    $body = (@($markerStart) + $Lines + @($markerEnd)) -join "`n"

    if ($raw.Trim() -eq '') {
        Write-TextNoBom -Path $patchFile -Text ($body + "`n")
        return
    }

    $lines = $raw -split "`r?`n"
    $at = 0
    while ($at -lt $lines.Count) {
        $t = $lines[$at].Trim()
        if ($t -eq '' -or $t.StartsWith('#')) { $at++ } else { break }
    }

    $head = @()
    if ($at -gt 0) { $head = $lines[0..($at - 1)] }
    $tail = @()
    if ($at -lt $lines.Count) { $tail = $lines[$at..($lines.Count - 1)] }

    $new = @()
    $new += $head
    $new += $body
    if ($tail.Count -gt 0) { $new += ''; $new += $tail }

    Write-TextNoBom -Path $patchFile -Text (($new -join "`n").TrimEnd() + "`n")
}

if ($Uninstall) {
    if (Test-Path $patchFile) { Remove-ManagedRow }
    if (Test-Path $destDir) { Remove-Item -LiteralPath $destDir -Recurse -Force }
    Write-Host "Removed $pkgName from profile '$Profile'."
    Write-Host 'Restart dsh to drop the theme.'
    return
}

if (-not (Test-Path $patchFile)) {
    $available = @()
    if (Test-Path $profilesDir) {
        $available = Get-ChildItem $profilesDir -Directory |
            Where-Object { Test-Path (Join-Path $_.FullName 'cordis.patch.yml') } |
            Select-Object -ExpandProperty Name
    }
    throw "No such profile: '$Profile' (looked for $patchFile).`nAvailable: $($available -join ', ')"
}

# -- the entry file the Loader must import --------------------------------------
# It must be a FILE. The Loader imports a relative row with a plain dynamic
# import(), and Node refuses a directory URL with ERR_UNSUPPORTED_DIR_IMPORT --
# for a file: URL it does not consult package.json exports or main.
$hostEntry = $manifest.exports.'.'
if (-not $hostEntry) { $hostEntry = $manifest.main }
if (-not $hostEntry) { throw "package.json declares neither exports['.'] nor main." }
if ($hostEntry -isnot [string]) { $hostEntry = $hostEntry.default }
if ($hostEntry.StartsWith('./')) { $hostEntry = $hostEntry.Substring(2) }
$hostEntry = $hostEntry -replace '/', '\'

# -- copy the package ----------------------------------------------------------
# Follow package.json `files` so the original multi-megabyte source artwork at the
# repository root never lands in the profile.
$include = @($manifest.files)
if ($include.Count -eq 0) { $include = @('package.json', 'cordis.patch.yml', 'lib', 'media') }
if ($include -notcontains 'package.json') { $include += 'package.json' }

New-Item -ItemType Directory -Force -Path $themesDir | Out-Null
if (Test-Path $destDir) { Remove-Item -LiteralPath $destDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $destDir | Out-Null

foreach ($item in $include) {
    $from = Join-Path $repoDir $item
    if (-not (Test-Path $from)) { continue }
    $to = Join-Path $destDir $item
    $parent = Split-Path -Parent $to
    if ($parent -and -not (Test-Path $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    Copy-Item -LiteralPath $from -Destination $to -Recurse -Force
}

if (-not (Test-Path (Join-Path $destDir $hostEntry))) {
    throw "Installed package is missing the entry file: $hostEntry"
}

# -- pre-flight: reproduce the Loader's resolution ------------------------------
$relSpec = "../../themes/$pkgName/$($hostEntry -replace '\\', '/')"
Write-Host ''
Write-Host 'Pre-flight resolution check:'

$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) {
    Write-Warning 'node not found on PATH, so the import check is skipped. The row was still written with a file specifier, which is the part that matters.'
} else {
    $probe = @'
const { pathToFileURL } = require('node:url');
(async () => {
  const [profileDir, spec] = process.argv.slice(2);
  const base = pathToFileURL(profileDir.replace(/[\\/]?$/, '/'));
  const url = new URL(spec, base).href;
  console.log('  resolved  ' + url);
  let mod;
  try { mod = await import(url); }
  catch (e) {
    console.log('  FAIL      import: ' + (e.code || e.message));
    process.exit(1);
  }
  console.log('  PASS      module imports');
  if (typeof mod.apply !== 'function') { console.log('  FAIL      host half exports apply()'); process.exit(1); }
  console.log('  PASS      host half exports apply()');
})();
'@
    $probeFile = Join-Path ([System.IO.Path]::GetTempPath()) ("dsh-theme-probe-" + [guid]::NewGuid().ToString('N') + '.cjs')
    Write-TextNoBom -Path $probeFile -Text $probe
    try {
        $out = & node $probeFile (Split-Path -Parent $patchFile) $relSpec 2>&1
        $code = $LASTEXITCODE
        $out | ForEach-Object { "  $_" }
    } finally {
        Remove-Item -LiteralPath $probeFile -Force -ErrorAction SilentlyContinue
    }
    if ($code -ne 0) {
        Remove-ManagedRow
        throw 'The row would not mount, so it has been rolled back. Nothing was installed.'
    }
}

# -- write the row -------------------------------------------------------------
Write-ManagedRow -Lines @(
    '- insert:',
    "    - id: $rowId",
    "      name: '$relSpec'"
)

Write-Host ''
Write-Host "Installed $pkgName"
Write-Host "  package : $destDir"
Write-Host "  row     : $rowId  (name: $relSpec)"
Write-Host "  patch   : $patchFile"
Write-Host ''
Write-Host 'RESTART dsh to activate it, then refresh the page. cordis.patch.yml is read'
Write-Host 'at boot; no installed package in this DSH version watches it.'
Write-Host ''
Write-Host 'Confirm the entry started:'
Write-Host '  cordis_inspect_query platform=host provider=Config method=listConfigs'
Write-Host "and look for entry id 'include:$rowId'."
