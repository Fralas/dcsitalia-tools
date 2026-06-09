#Requires -Version 5.1
<#
.SYNOPSIS
  Disinstalla DCORE Zone Link Editor dal Mission Editor di DCS World.
#>
param(
  [string]$DcsPath = "",
  [switch]$Pause
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogFile = Join-Path $ScriptDir "uninstall.log"
$PathFile = Join-Path $ScriptDir "dcs-path.txt"

$SentinelBegin = "-- BEGIN DCORE ZONE LINKER"
$SentinelEnd = "-- END DCORE ZONE LINKER"
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false

function Read-TextNoBom {
  param([string]$Path)
  $bytes = [System.IO.File]::ReadAllBytes($Path)
  $offset = 0
  if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    $offset = 3
  }
  return $Utf8NoBom.GetString($bytes, $offset, $bytes.Length - $offset)
}

function Write-TextNoBom {
  param(
    [string]$Path,
    [string]$Content
  )
  [System.IO.File]::WriteAllText($Path, $Content, $Utf8NoBom)
}

function Normalize-DcsPath {
  param([string]$Path)
  if (-not $Path) { return $null }
  $p = $Path.Trim().Trim('"').Trim("'")
  $p = $p -replace '/', '\'
  $p = $p.TrimEnd('\')
  if ($p -eq "") { return $null }
  return $p
}

function Read-DcsPathFromFile {
  if (-not (Test-Path $PathFile)) { return $null }
  $raw = Get-Content -Path $PathFile -ErrorAction SilentlyContinue | Where-Object { $_ -and $_.Trim() -ne "" -and $_.Trim() -notmatch '^\s*#' } | Select-Object -First 1
  return Normalize-DcsPath $raw
}

function Test-DcsRoot {
  param([string]$Root)
  if (-not $Root) { return $false }
  return Test-Path (Join-Path $Root "MissionEditor\MissionEditor.lua")
}

function Find-DcsInstall {
  param([string]$Override)

  $override = Normalize-DcsPath $Override
  if ($override -and (Test-DcsRoot $override)) {
    return $override
  }

  $fromFile = Read-DcsPathFromFile
  if ($fromFile -and (Test-DcsRoot $fromFile)) {
    return $fromFile
  }

  $candidates = @(
    "F:\DCS World OpenBeta",
    "C:\Program Files\Eagle Dynamics\DCS World OpenBeta",
    "D:\Program Files\Eagle Dynamics\DCS World OpenBeta",
    "C:\Program Files\Eagle Dynamics\DCS World",
    "D:\Program Files\Eagle Dynamics\DCS World",
    "C:\Program Files (x86)\Steam\steamapps\common\DCSWorld",
    "D:\Steam\steamapps\common\DCSWorld"
  )

  foreach ($path in $candidates) {
    if (Test-DcsRoot $path) {
      return $path
    }
  }

  return $null
}

function Remove-Patch {
  param([string]$DcsRoot)

  $meLua = Join-Path $DcsRoot "MissionEditor\MissionEditor.lua"
  if (-not (Test-Path $meLua)) {
    throw "MissionEditor.lua non trovato: $meLua"
  }

  $content = Read-TextNoBom -Path $meLua
  $pattern = "(?s)\r?\n" + [regex]::Escape($SentinelBegin) + ".*?" + [regex]::Escape($SentinelEnd) + "\r?\n?"
  $newContent = [regex]::Replace($content, $pattern, "`n")

  if ($newContent -eq $content) {
    Write-Host "Nessuna patch DCORE Zone Linker trovata in MissionEditor.lua"
    return
  }

  Write-TextNoBom -Path $meLua -Content $newContent
  Write-Host "Patch rimossa da MissionEditor.lua (UTF-8 senza BOM)"
}

try {
  $dcs = Find-DcsInstall -Override $DcsPath
  if (-not $dcs) {
    throw "DCS installation not found. Create dcs-path.txt or use -DcsPath"
  }

  Write-Host "DCS path: $dcs"

  $modDir = Join-Path $dcs "MissionEditor\modules\dcore_zone_linker"
  if (Test-Path $modDir) {
    Remove-Item -Path $modDir -Recurse -Force
    Write-Host "Removed: $modDir"
  } else {
    Write-Host "Mod directory not present: $modDir"
  }

  Remove-Patch -DcsRoot $dcs

  Write-Host ""
  Write-Host "Uninstall completed. Fully restart DCS."
  exit 0
}
catch {
  Write-Host "UNINSTALL FAILED: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}
finally {
  if ($Pause) {
    Write-Host ""
    Write-Host "Press Enter to close..."
    Read-Host | Out-Null
  }
}
