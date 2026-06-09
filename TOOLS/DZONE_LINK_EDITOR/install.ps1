#Requires -Version 5.1
<#
.SYNOPSIS
  Installs DCORE Zone Link Editor into the DCS World Mission Editor.
#>
param(
  [string]$DcsPath = "",
  [switch]$Pause
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SourceMod = Join-Path $ScriptDir "me-mod\lua\dcore_zone_linker"
$LogFile = Join-Path $ScriptDir "install.log"
$PathFile = Join-Path $ScriptDir "dcs-path.txt"
$SentinelBegin = "-- BEGIN DCORE ZONE LINKER"
$SentinelEnd = "-- END DCORE ZONE LINKER"
$RequireLine = "require('dcore_zone_linker.init')"
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false

function Write-Log {
  param([string]$Message)
  $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
  Write-Host $Message
  Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

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

function Append-TextNoBom {
  param(
    [string]$Path,
    [string]$Content
  )
  [System.IO.File]::AppendAllText($Path, $Content, $Utf8NoBom)
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
    "D:\Steam\steamapps\common\DCSWorld",
    "C:\Program Files (x86)\Steam\steamapps\common\DCSWorld OpenBeta",
    "E:\Games\DCS World OpenBeta",
    "E:\Games\DCS World",
    "L:\DCS World RC",
    "L:\DCS World OpenBeta",
    "L:\DCS World"
  )

  foreach ($path in $candidates) {
    if (Test-DcsRoot $path) {
      return $path
    }
  }

  return $null
}

function Copy-ModFiles {
  param(
    [string]$DcsRoot,
    [string]$Source
  )

  if (-not (Test-Path $Source)) {
    throw "Source mod folder not found: $Source`nMake sure the full DZONE_LINK_EDITOR folder was copied (including me-mod)."
  }

  $dest = Join-Path $DcsRoot "MissionEditor\modules\dcore_zone_linker"
  if (-not (Test-Path $dest)) {
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
  }

  Copy-Item -Path (Join-Path $Source "*") -Destination $dest -Recurse -Force
  Write-Log "Mod copied to: $dest"
}

function Patch-MissionEditorLua {
  param([string]$DcsRoot)

  $meLua = Join-Path $DcsRoot "MissionEditor\MissionEditor.lua"
  $backup = "$meLua.dcore-zone-linker.bak"

  if (-not (Test-Path $meLua)) {
    throw "MissionEditor.lua not found: $meLua"
  }

  $content = Read-TextNoBom -Path $meLua

  if ($content -match [regex]::Escape($SentinelBegin)) {
    Write-Log "Patch already present in MissionEditor.lua (skipped)."
    return
  }

  if (-not (Test-Path $backup)) {
    Copy-Item -Path $meLua -Destination $backup -Force
    Write-Log "Backup created: $backup"
  } else {
    Write-Log "Backup already exists: $backup"
  }

  $block = "`r`n$SentinelBegin`r`n$RequireLine`r`n$SentinelEnd`r`n"
  Append-TextNoBom -Path $meLua -Content $block
  Write-Log "Patch appended to MissionEditor.lua (UTF-8 no BOM)"
}

function Test-InstallResult {
  param([string]$DcsRoot)

  $errors = @()
  $modDir = Join-Path $DcsRoot "MissionEditor\modules\dcore_zone_linker"
  $initLua = Join-Path $modDir "init.lua"
  $meLua = Join-Path $DcsRoot "MissionEditor\MissionEditor.lua"

  if (-not (Test-Path $initLua)) {
    $errors += "Missing: $initLua"
  }

  if (-not (Test-Path $meLua)) {
    $errors += "Missing: $meLua"
  } else {
    $content = Read-TextNoBom -Path $meLua
    if ($content -notmatch [regex]::Escape($SentinelBegin)) {
      $errors += "MissionEditor.lua patch not found after install"
    }
  }

  return $errors
}

function Show-FailureHelp {
  param([string]$Reason)

  Write-Host ""
  Write-Host "INSTALL FAILED: $Reason" -ForegroundColor Red
  Write-Host ""
  Write-Host "What to do:"
  Write-Host "  1. Create or edit: $PathFile"
  Write-Host "     Put ONE line with your DCS folder, e.g.:"
  Write-Host "       L:\DCS World RC"
  Write-Host "  2. Double-click install.bat (not install.ps1)"
  Write-Host "  3. If DCS is under Program Files, right-click install.bat -> Run as administrator"
  Write-Host "  4. After success, fully quit DCS and start it again"
  Write-Host "  5. Open Mission Editor -> menu DCORE Tools -> Zone Link Editor"
  Write-Host ""
  Write-Host "Log file: $LogFile"
}

try {
  "" | Out-File -FilePath $LogFile -Encoding UTF8 -Force
  Write-Log "=== DCORE Zone Link Editor install started ==="
  Write-Log "Script dir: $ScriptDir"

  $dcs = Find-DcsInstall -Override $DcsPath
  if (-not $dcs) {
    $hint = ""
    if (Test-Path $PathFile) {
      $hint = " (dcs-path.txt exists but path is invalid - check spelling and folder name)"
    } else {
      $hint = " - create dcs-path.txt from dcs-path.txt.example"
    }
    throw "DCS installation not found$hint"
  }

  Write-Log "DCS path: $dcs"
  Copy-ModFiles -DcsRoot $dcs -Source $SourceMod
  Patch-MissionEditorLua -DcsRoot $dcs

  $verifyErrors = Test-InstallResult -DcsRoot $dcs
  if ($verifyErrors.Count -gt 0) {
    throw ("Verification failed:`n - " + ($verifyErrors -join "`n - "))
  }

  Write-Log "Install completed successfully."
  Write-Host ""
  Write-Host "SUCCESS. Fully restart DCS, then open Mission Editor -> DCORE Tools -> Zone Link Editor." -ForegroundColor Green
  exit 0
}
catch {
  Write-Log ("ERROR: " + $_.Exception.Message)
  if ($_.ScriptStackTrace) {
    Write-Log $_.ScriptStackTrace
  }
  Show-FailureHelp -Reason $_.Exception.Message
  exit 1
}
finally {
  if ($Pause) {
    Write-Host ""
    Write-Host "Press Enter to close..."
    Read-Host | Out-Null
  }
}
