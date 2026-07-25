#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Utf8String {
    param([byte[]]$Bytes)
    [System.Text.Encoding]::UTF8.GetString($Bytes)
}

$IconWeb = Get-Utf8String 0xF0, 0x9F, 0x8C, 0x90
$IconDownload = Get-Utf8String 0xF0, 0x9F, 0x93, 0xB2
$IconRepo = Get-Utf8String 0xF0, 0x9F, 0x94, 0x97

$ActionPath = if ($env:ACTION_PATH) { $env:ACTION_PATH } else { Split-Path -Parent $PSScriptRoot }
$AppsJsonPath = Join-Path $ActionPath 'templates\apps.json'
$WelcomePath = Join-Path $ActionPath 'templates\channel-welcome.txt'
$IntroPath = Join-Path $ActionPath 'templates\channel-app-intro.txt'
$AccessLocalPath = Join-Path $ActionPath 'templates\channel-access-local.txt'
$EnvLocalPath = Join-Path $ActionPath '.env.local'

if (-not $env:TELEGRAM_BOT_TOKEN -and (Test-Path $EnvLocalPath)) {
    Get-Content $EnvLocalPath -Encoding UTF8 | ForEach-Object {
        if ($_ -match '^\s*([^#=]+)=(.*)$') {
            Set-Item -Path "env:$($matches[1].Trim())" -Value $matches[2].Trim()
        }
    }
}

if (-not $env:TELEGRAM_BOT_TOKEN) {
    throw 'TELEGRAM_BOT_TOKEN is required'
}

$ChannelId = if ($env:TELEGRAM_CHANNEL_ID) { $env:TELEGRAM_CHANNEL_ID } else { '@palmapps' }
$Mode = if ($env:MODE) { $env:MODE } else { 'all' }
$Apps = Get-Content $AppsJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
$AppOrder = @('costify', 'reservas', 'viajando', 'carta-restaurante', 'rensoli-commerce')

function Send-TelegramMessage {
    param([string]$Text)

    $payload = [ordered]@{
        chat_id = $ChannelId
        text = $Text
        disable_web_page_preview = $false
    }
    $json = ($payload | ConvertTo-Json -Compress)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)

    $response = Invoke-RestMethod `
        -Uri "https://api.telegram.org/bot$($env:TELEGRAM_BOT_TOKEN)/sendMessage" `
        -Method Post `
        -ContentType 'application/json; charset=utf-8' `
        -Body $bytes

    if (-not $response.ok) {
        throw "Telegram API error: $($response | ConvertTo-Json -Compress)"
    }
}

function Get-AccessBlock {
    param($App)

    $lines = @()
    if ($App.webUrl) { $lines += "$IconWeb Web: $($App.webUrl)" }
    if ($App.downloadUrl) { $lines += "$IconDownload Descarga / APK: $($App.downloadUrl)" }
    if ($lines.Count -eq 0) {
        $lines += (Get-Content $AccessLocalPath -Raw -Encoding UTF8).Trim()
    }
    return ($lines -join [Environment]::NewLine)
}

function Send-Welcome {
    $message = (Get-Content $WelcomePath -Raw -Encoding UTF8).Trim()
    Send-TelegramMessage $message
    Write-Host 'Welcome message sent'
}

function Send-AppIntro {
    param([string]$AppKey)

    $app = $Apps.$AppKey
    $accessBlock = Get-AccessBlock $app
    $repoBlock = if ($app.repoUrl) { "$IconRepo C$([char]0x00F3)digo: $($app.repoUrl)" } else { '' }
    $template = Get-Content $IntroPath -Raw -Encoding UTF8

    $message = $template `
        -replace '\$\{DISPLAY_NAME\}', $app.displayName `
        -replace '\$\{HASHTAG\}', $app.hashtag `
        -replace '\$\{SUMMARY\}', $app.summary `
        -replace '\$\{ACCESS_BLOCK\}', $accessBlock `
        -replace '\$\{REPO_BLOCK\}', $repoBlock

    $message = $message.Trim()
    Send-TelegramMessage $message
    Write-Host "Intro sent: $AppKey"
}

switch ($Mode) {
    'welcome' {
        Send-Welcome
    }
    'apps' {
        foreach ($appKey in $AppOrder) {
            Send-AppIntro $appKey
            Start-Sleep -Seconds 1
        }
    }
    default {
        Send-Welcome
        Start-Sleep -Seconds 1
        foreach ($appKey in $AppOrder) {
            Send-AppIntro $appKey
            Start-Sleep -Seconds 1
        }
    }
}

Write-Host "PalmApps channel intros complete ($ChannelId)"
