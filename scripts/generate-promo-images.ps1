#Requires -Version 5.1
<#
.SYNOPSIS
  Genera imagenes PNG de promo (feed 1080x1080 + story 1080x1920) para redes sociales.

.EXAMPLE
  .\scripts\generate-promo-images.ps1
  $env:APP='costify'; .\scripts\generate-promo-images.ps1
  $env:APP='costify'; $env:VERSION='1.0.21'; .\scripts\generate-promo-images.ps1
  $env:ALL='true'; .\scripts\generate-promo-images.ps1
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ActionPath = if ($env:ACTION_PATH) { $env:ACTION_PATH } else { Split-Path -Parent $PSScriptRoot }
$PromoImagesDir = Join-Path $ActionPath 'scripts\promo-images'
$NodeModules = Join-Path $PromoImagesDir 'node_modules'

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    throw 'Node.js no esta instalado. Instala LTS desde https://nodejs.org y vuelve a ejecutar.'
}

if (-not (Test-Path $NodeModules)) {
    Write-Host 'Instalando dependencias (playwright)...' -ForegroundColor Cyan
    Push-Location $PromoImagesDir
    try {
        npm install --no-fund --no-audit
        npx playwright install chromium
    }
    finally {
        Pop-Location
    }
}

$env:ACTION_PATH = $ActionPath
Push-Location $PromoImagesDir
try {
    node .\generate.mjs
}
finally {
    Pop-Location
}

Write-Host ''
Write-Host 'Salida: output\promos\images\' -ForegroundColor Green
Write-Host '  *-feed.png   -> Facebook Page, Instagram feed' -ForegroundColor DarkGray
Write-Host '  *-story.png  -> Instagram Stories, WhatsApp Status' -ForegroundColor DarkGray
