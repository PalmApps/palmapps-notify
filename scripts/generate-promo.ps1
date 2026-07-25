#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ActionPath = if ($env:ACTION_PATH) { $env:ACTION_PATH } else { Split-Path -Parent $PSScriptRoot }
$AppsJsonPath = Join-Path $ActionPath 'templates\apps.json'
$OutputDir = Join-Path $ActionPath 'output\promos'
$ForumLink = if ($env:FORUM_LINK) { $env:FORUM_LINK } else { 'https://t.me/palmapps' }

$ChannelTemplates = [ordered]@{
    instagram = 'social-promo-instagram.txt'
    whatsapp  = 'social-promo-whatsapp.txt'
    x         = 'social-promo-x.txt'
    generic   = 'social-promo-generic.txt'
}

function Get-AppProperty {
    param($App, [string]$Name)
    $prop = $App.PSObject.Properties[$Name]
    if ($null -eq $prop) { return '' }
    return [string]$prop.Value
}

function Get-AccessLine {
    param($App)
    $lines = @()
    if ($App.webUrl) { $lines += "Web: $($App.webUrl)" }
    if ($App.downloadUrl) { $lines += "APK: $($App.downloadUrl)" }
    if ($lines.Count -eq 0) {
        $lines += 'Disponible en red local del negocio (consulta el topic del foro)'
    }
    return ($lines -join [Environment]::NewLine)
}

function Render-Promo {
    param([string]$Template, $App)

    $promoHook = Get-AppProperty $App 'promoHook'
    if ([string]::IsNullOrWhiteSpace($promoHook)) {
        $promoHook = ($App.summary -replace '\..*$', '').Trim()
    }

    $ctaLine = 'Guardalo y comparte con quien le sirva.'

    return $Template `
        -replace '\$\{DISPLAY_NAME\}', $App.displayName `
        -replace '\$\{HASHTAG\}', $App.hashtag `
        -replace '\$\{PROMO_HOOK\}', $promoHook `
        -replace '\$\{ACCESS_LINE\}', (Get-AccessLine $App) `
        -replace '\$\{FORUM_LINK\}', $ForumLink `
        -replace '\$\{CTA_LINE\}', $ctaLine
}

$apps = Get-Content $AppsJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
$allKeys = @('costify', 'reservas', 'viajando', 'carta-restaurante', 'rensoli-commerce')

if ($env:APP) {
    $targetKeys = @($env:APP)
}
elseif ($env:ALL -eq 'true') {
    $targetKeys = $allKeys
}
else {
    $targetKeys = @()
    foreach ($key in $allKeys) {
        $app = $apps.$key
        $priority = Get-AppProperty $app 'promoPriority'
        if ($priority -eq 'True' -or $priority -eq 'true') {
            $targetKeys += $key
        }
    }
}

if ($targetKeys.Count -eq 0) {
    throw 'No hay apps objetivo. Usa APP=costify o ALL=true'
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

foreach ($appKey in $targetKeys) {
    $app = $apps.$appKey
    if (-not $app) {
        Write-Host "App desconocida: $appKey" -ForegroundColor Yellow
        continue
    }

    foreach ($channel in $ChannelTemplates.Keys) {
        $templatePath = Join-Path $ActionPath ("templates\" + $ChannelTemplates[$channel])
        $template = Get-Content $templatePath -Raw -Encoding UTF8
        $content = (Render-Promo -Template $template -App $app).Trim()
        $outPath = Join-Path $OutputDir "$appKey-$channel.txt"
        [System.IO.File]::WriteAllText($outPath, "$content`n", [System.Text.UTF8Encoding]::new($false))
        Write-Host "Generado: $outPath"
    }
}

Write-Host "Promos en $OutputDir ($($targetKeys.Count) apps x $($ChannelTemplates.Count) canales)"
