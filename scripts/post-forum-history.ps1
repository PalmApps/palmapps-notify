#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ActionPath = if ($env:ACTION_PATH) { $env:ACTION_PATH } else { Split-Path -Parent $PSScriptRoot }
$AppsJsonPath = Join-Path $ActionPath 'templates\apps.json'
$HistoryDir = Join-Path $ActionPath 'templates\history'
$EntryTemplatePath = Join-Path $ActionPath 'templates\forum-history-entry.txt'
$HistoryHeaderPath = Join-Path $ActionPath 'templates\forum-history-header.txt'
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

$ForumChatId = if ($env:TELEGRAM_FORUM_CHAT_ID) { $env:TELEGRAM_FORUM_CHAT_ID } else { '@palmapps' }
$AppFilter = $env:APP
$AppOrder = @('costify', 'reservas', 'viajando', 'carta-restaurante', 'rensoli-commerce')

function Get-ForumTopicId {
    param($App)
    $prop = $App.PSObject.Properties['forumTopicId']
    if ($null -eq $prop -or [string]::IsNullOrWhiteSpace([string]$prop.Value)) {
        return $null
    }
    return [int]$prop.Value
}

function Invoke-TelegramApi {
    param([string]$Method, [hashtable]$Body)
    $json = ($Body | ConvertTo-Json -Compress)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    try {
        return Invoke-RestMethod `
            -Uri "https://api.telegram.org/bot$($env:TELEGRAM_BOT_TOKEN)/$Method" `
            -Method Post `
            -ContentType 'application/json; charset=utf-8' `
            -Body $bytes
    }
    catch {
        $detail = $_.ErrorDetails.Message
        if ($detail) { throw "Telegram API $Method failed: $detail" }
        throw
    }
}

function Send-TelegramMessage {
    param([string]$Text, [int]$ThreadId)
    $payload = [ordered]@{
        chat_id = $ForumChatId
        text = $Text
        disable_web_page_preview = $false
        message_thread_id = $ThreadId
    }
    $response = Invoke-TelegramApi -Method 'sendMessage' -Body $payload
    if (-not $response.ok) {
        throw "Telegram sendMessage error: $($response | ConvertTo-Json -Compress)"
    }
}

function Get-Bullet {
    return [System.Text.Encoding]::UTF8.GetString([byte[]](0xE2, 0x80, 0xA2))
}

function Format-HistoryEntry {
    param($Entry, [string]$Template)

    $bullet = Get-Bullet
    $changes = @()
    foreach ($line in @($Entry.changes)) {
        if ([string]::IsNullOrWhiteSpace([string]$line)) { continue }
        $changes += "$bullet $line"
    }
    $changesBlock = if ($changes.Count -gt 0) { $changes -join [Environment]::NewLine } else { "$bullet Mejoras generales" }

    $dateBlock = ''
    if ($Entry.date) {
        $dateBlock = " · $($Entry.date)"
    }

    return $Template `
        -replace '\$\{TITLE\}', [string]$Entry.title `
        -replace '\$\{VERSION\}', [string]$Entry.version `
        -replace '\$\{DATE_BLOCK\}', $dateBlock `
        -replace '\$\{CHANGES_BLOCK\}', $changesBlock
}

$apps = Get-Content $AppsJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
$entryTemplate = Get-Content $EntryTemplatePath -Raw -Encoding UTF8
$targets = if ($AppFilter) { @($AppFilter) } else { $AppOrder }

foreach ($appKey in $targets) {
    $app = $apps.$appKey
    if (-not $app) {
        Write-Host "App desconocida: $appKey" -ForegroundColor Yellow
        continue
    }

    $topicId = Get-ForumTopicId $app
    if (-not $topicId) {
        Write-Host "Omitido $appKey (sin forumTopicId)" -ForegroundColor Yellow
        continue
    }

    $historyPath = Join-Path $HistoryDir "$appKey.json"
    if (-not (Test-Path $historyPath)) {
        Write-Host "Omitido $appKey (sin history/$appKey.json)" -ForegroundColor Yellow
        continue
    }

    $history = Get-Content $historyPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $entries = @($history.entries)
    if ($entries.Count -eq 0) {
        Write-Host "Omitido $appKey (historial vacio)" -ForegroundColor Yellow
        continue
    }

    $headerTemplate = Get-Content $HistoryHeaderPath -Raw -Encoding UTF8
    $header = $headerTemplate -replace '\$\{DISPLAY_NAME\}', $app.displayName
    Send-TelegramMessage -Text $header.Trim() -ThreadId $topicId
    Write-Host "Historial iniciado: $appKey"
    Start-Sleep -Seconds 1

    foreach ($entry in $entries) {
        $message = (Format-HistoryEntry -Entry $entry -Template $entryTemplate).Trim()
        Send-TelegramMessage -Text $message -ThreadId $topicId
        Write-Host "  -> $($entry.title)"
        Start-Sleep -Seconds 1
    }
}

Write-Host "Forum history complete ($ForumChatId)"
