#Requires -Version 5.1
<#
.SYNOPSIS
  Disinstalla DCORE Zone Link Editor dal Mission Editor di DCS World.
#>
param(
  [string]$DcsPath = ""
)

$ErrorActionPreference = "Stop"

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

$dcs = Find-DcsInstall -Override $DcsPath
if (-not $dcs) {
  Write-Error "Installazione DCS non trovata. Usa -DcsPath 'C:\percorso\DCS World'"
}

Write-Host "DCS path: $dcs"

$modDir = Join-Path $dcs "MissionEditor\modules\dcore_zone_linker"
if (Test-Path $modDir) {
  Remove-Item -Path $modDir -Recurse -Force
  Write-Host "Rimosso: $modDir"
} else {
  Write-Host "Mod directory non presente: $modDir"
}

Remove-Patch -DcsRoot $dcs

Write-Host ""
Write-Host "Disinstallazione completata. Riavvia DCS."
