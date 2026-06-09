#Requires -Version 5.1
<#
.SYNOPSIS
  Installa DCORE Zone Link Editor nel Mission Editor di DCS World.
#>
param(
  [string]$DcsPath = ""
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SourceMod = Join-Path $ScriptDir "me-mod\lua\dcore_zone_linker"
$SentinelBegin = "-- BEGIN DCORE ZONE LINKER"
$SentinelEnd = "-- END DCORE ZONE LINKER"
$RequireLine = "require('dcore_zone_linker.init')"
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

function Append-TextNoBom {
  param(
    [string]$Path,
    [string]$Content
  )
  [System.IO.File]::AppendAllText($Path, $Content, $Utf8NoBom)
}

function Find-DcsInstall {
  param([string]$Override)

  if ($Override -and (Test-Path (Join-Path $Override "MissionEditor\MissionEditor.lua"))) {
    return $Override
  }

  $candidates = @(
    "F:\DCS World OpenBeta",
    "C:\Program Files\Eagle Dynamics\DCS World",
    "D:\Program Files\Eagle Dynamics\DCS World",
    "C:\Program Files\Eagle Dynamics\DCS World OpenBeta",
    "D:\Program Files\Eagle Dynamics\DCS World OpenBeta"
  )

  foreach ($path in $candidates) {
    if (Test-Path (Join-Path $path "MissionEditor\MissionEditor.lua")) {
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

  $dest = Join-Path $DcsRoot "MissionEditor\modules\dcore_zone_linker"
  if (-not (Test-Path $dest)) {
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
  }

  Copy-Item -Path (Join-Path $Source "*") -Destination $dest -Recurse -Force
  Write-Host "Mod copiato in: $dest"
}

function Patch-MissionEditorLua {
  param([string]$DcsRoot)

  $meLua = Join-Path $DcsRoot "MissionEditor\MissionEditor.lua"
  $backup = "$meLua.dcore-zone-linker.bak"

  if (-not (Test-Path $meLua)) {
    throw "MissionEditor.lua non trovato: $meLua"
  }

  $content = Read-TextNoBom -Path $meLua

  if ($content -match [regex]::Escape($SentinelBegin)) {
    Write-Host "Patch gia presente in MissionEditor.lua (skip)."
    return
  }

  if (-not (Test-Path $backup)) {
    Copy-Item -Path $meLua -Destination $backup -Force
    Write-Host "Backup creato: $backup"
  } else {
    Write-Host "Backup esistente: $backup"
  }

  $block = "`r`n$SentinelBegin`r`n$RequireLine`r`n$SentinelEnd`r`n"
  Append-TextNoBom -Path $meLua -Content $block
  Write-Host "Patch aggiunta a MissionEditor.lua (UTF-8 senza BOM)"
}

$dcs = Find-DcsInstall -Override $DcsPath
if (-not $dcs) {
  Write-Error "Installazione DCS non trovata. Usa -DcsPath 'C:\percorso\DCS World'"
}

Write-Host "DCS path: $dcs"
Copy-ModFiles -DcsRoot $dcs -Source $SourceMod
Patch-MissionEditorLua -DcsRoot $dcs

Write-Host ""
Write-Host "Installazione completata."
Write-Host "Riavvia DCS completamente, poi apri Mission Editor -> menu DCORE Tools -> Zone Link Editor."
