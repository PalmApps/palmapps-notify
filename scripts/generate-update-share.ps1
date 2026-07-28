#Requires -Version 5.1
<#
.SYNOPSIS
  Genera el texto compartible de una actualizacion (General + WhatsApp / Facebook / Instagram).

.EXAMPLE
  $env:APP='reservas'; $env:VERSION='abc1234'; $env:CHANGELOG="Mejora 1`nMejora 2"; .\scripts\generate-update-share.ps1
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ActionPath = if ($env:ACTION_PATH) { $env:ACTION_PATH } else { Split-Path -Parent $PSScriptRoot }
$OutputDir = Join-Path $ActionPath 'output\shares'

if (-not $env:APP) { throw 'APP is required (ej. reservas, costify)' }
if (-not $env:VERSION) { throw 'VERSION is required' }

$env:ACTION_PATH = $ActionPath
if (-not $env:FORUM_LINK) { $env:FORUM_LINK = 'https://t.me/palmapps' }
if (-not $env:TELEGRAM_FORUM_CHAT_ID) { $env:TELEGRAM_FORUM_CHAT_ID = '@palmapps' }

$bash = Get-Command bash -ErrorAction SilentlyContinue
if (-not $bash) {
    throw 'bash is required (Git Bash o WSL)'
}

$message = & bash (Join-Path $ActionPath 'scripts\render-update-share.sh')
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$safeVersion = $env:VERSION -replace '[/:\\]', '_'
$outPath = Join-Path $OutputDir "$($env:APP)-$safeVersion.txt"
[System.IO.File]::WriteAllText($outPath, "$message`n", [System.Text.UTF8Encoding]::new($false))

Write-Host $message
Write-Host ''
Write-Host "Guardado: $outPath" -ForegroundColor Green
Write-Host 'Copia y pega en WhatsApp Status, Facebook o Instagram.' -ForegroundColor DarkGray
