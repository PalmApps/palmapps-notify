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
$AppsJsonPath = Join-Path $ActionPath 'templates\apps.json'
$TemplatePath = Join-Path $ActionPath 'templates\forum-general-update.txt'
$OutputDir = Join-Path $ActionPath 'output\shares'
$ForumLink = if ($env:FORUM_LINK) { $env:FORUM_LINK } else { 'https://t.me/palmapps' }
$ForumChatId = if ($env:TELEGRAM_FORUM_CHAT_ID) { $env:TELEGRAM_FORUM_CHAT_ID } else { '@palmapps' }

if (-not $env:APP) { throw 'APP is required (ej. reservas, costify)' }
if (-not $env:VERSION) { throw 'VERSION is required' }

$apps = Get-Content $AppsJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
$app = $apps.($env:APP)
if (-not $app) { throw "App desconocida: $($env:APP)" }

$bullet = [System.Text.Encoding]::UTF8.GetString([byte[]](0xE2, 0x80, 0xA2))
$changelogLines = @()
foreach ($line in ($env:CHANGELOG -split "`n")) {
    $trimmed = $line.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
    if ($trimmed -match '^[-•*]\s*') {
        $changelogLines += $trimmed
    }
    else {
        $changelogLines += "$bullet $trimmed"
    }
}
if ($changelogLines.Count -eq 0) {
    $changelogLines = @("$bullet Ver detalles en el topic de la app")
}

$summaryLines = @($changelogLines | Select-Object -First 3)
if ($changelogLines.Count -gt 3) {
    $summaryLines += "$bullet … y más en el topic"
}
$changelogSummary = $summaryLines -join [Environment]::NewLine

$webUrl = if ($env:WEB_URL) { $env:WEB_URL } elseif ($app.webUrl) { $app.webUrl } else { '' }
$webBlock = ''
if (-not [string]::IsNullOrWhiteSpace($webUrl)) {
    $webBlock = "🌐 Probar ahora: $webUrl`n`n"
}

$forumUsername = $ForumChatId.TrimStart('@')
if ([string]::IsNullOrWhiteSpace($forumUsername) -or $forumUsername -eq $ForumChatId) {
    $forumUsername = 'palmapps'
}

$topicLink = $ForumLink
$topicIdProp = $app.PSObject.Properties['forumTopicId']
if ($null -ne $topicIdProp -and -not [string]::IsNullOrWhiteSpace([string]$topicIdProp.Value)) {
    $topicLink = "https://t.me/$forumUsername/$($topicIdProp.Value)"
}

$template = Get-Content $TemplatePath -Raw -Encoding UTF8
$message = $template `
    -replace '\$\{DISPLAY_NAME\}', $app.displayName `
    -replace '\$\{HASHTAG\}', $app.hashtag `
    -replace '\$\{CHANGELOG_SUMMARY\}', $changelogSummary `
    -replace '\$\{TOPIC_LINK\}', $topicLink `
    -replace '\$\{WEB_BLOCK\}', $webBlock `
    -replace '\$\{FORUM_LINK\}', $ForumLink
$message = $message.Trim()

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$safeVersion = $env:VERSION -replace '[/:\\]', '_'
$outPath = Join-Path $OutputDir "$($env:APP)-$safeVersion.txt"
[System.IO.File]::WriteAllText($outPath, "$message`n", [System.Text.UTF8Encoding]::new($false))

Write-Host $message
Write-Host ''
Write-Host "Guardado: $outPath" -ForegroundColor Green
Write-Host 'Copia y pega en WhatsApp Status, Facebook o Instagram.' -ForegroundColor DarkGray
