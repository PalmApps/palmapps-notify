#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ActionPath = if ($env:ACTION_PATH) { $env:ACTION_PATH } else { Split-Path -Parent $PSScriptRoot }
$AppsJsonPath = Join-Path $ActionPath 'templates\apps.json'
$HistoryDir = Join-Path $ActionPath 'templates\history'
$EntryTemplatePath = Join-Path $ActionPath 'templates\forum-history-entry.txt'
$HeaderTemplatePath = Join-Path $ActionPath 'templates\forum-history-header.txt'
$MetaSemverPath = Join-Path $ActionPath 'templates\forum-history-meta-semver.txt'
$MetaPeriodPath = Join-Path $ActionPath 'templates\forum-history-meta-period.txt'
$MessageIdsPath = Join-Path $ActionPath 'data\forum-message-ids.json'
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
$Mode = if ($env:MODE) { $env:MODE } else { 'sync' }
$AppOrder = @('costify', 'reservas', 'viajando', 'carta-restaurante', 'rensoli-commerce', 'ofertas-cuba')

function Resolve-ForumChatId {
    param([string]$ChatId)
    if ($ChatId -match '^-?\d+$') { return $ChatId }
    $response = Invoke-TelegramApi -Method 'getChat' -Body @{ chat_id = $ChatId }
    if (-not $response.ok) { throw 'getChat failed' }
    return [string]$response.result.id
}

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
    return [int]$response.result.message_id
}

function Edit-TelegramMessage {
    param([string]$Text, [int]$ThreadId, [int]$MessageId)
    $payload = [ordered]@{
        chat_id = $ForumChatId
        message_id = $MessageId
        text = $Text
        disable_web_page_preview = $false
        message_thread_id = $ThreadId
    }
    $response = Invoke-TelegramApi -Method 'editMessageText' -Body $payload
    if (-not $response.ok) {
        throw "Telegram editMessageText error: $($response | ConvertTo-Json -Compress)"
    }
}

function Get-Bullet {
    return [System.Text.Encoding]::UTF8.GetString([byte[]](0xE2, 0x80, 0xA2))
}

function Test-SemverVersion {
    param([string]$Version)
    return $Version -match '^\d+\.\d+'
}

function Get-EntryProperty {
    param($Entry, [string]$Name)
    $prop = $Entry.PSObject.Properties[$Name]
    if ($null -eq $prop) { return '' }
    return [string]$prop.Value
}

function Get-VersionLine {
    param($Entry)

    $version = Get-EntryProperty $Entry 'version'
    $date = Get-EntryProperty $Entry 'date'
    $period = Get-EntryProperty $Entry 'period'

    if (-not [string]::IsNullOrWhiteSpace($period)) {
        $template = Get-Content $MetaPeriodPath -Raw -Encoding UTF8
        return ($template -replace '\$\{PERIOD\}', $period).Trim()
    }

    if (Test-SemverVersion $version) {
        $template = Get-Content $MetaSemverPath -Raw -Encoding UTF8
        $dateValue = if (-not [string]::IsNullOrWhiteSpace($date)) { $date } else { $version }
        return ($template -replace '\$\{VERSION\}', $version -replace '\$\{DATE\}', $dateValue).Trim()
    }

    if (-not [string]::IsNullOrWhiteSpace($version)) {
        $template = Get-Content $MetaPeriodPath -Raw -Encoding UTF8
        return ($template -replace '\$\{PERIOD\}', $version).Trim()
    }

    return ''
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
    $versionLine = Get-VersionLine $Entry

    return ($Template `
        -replace '\$\{TITLE\}', [string]$Entry.title `
        -replace '\$\{VERSION_LINE\}', $versionLine `
        -replace '\$\{CHANGES_BLOCK\}', $changesBlock).Trim()
}

function Build-HistoryMessage {
    param($App, $Entries, [string]$EntryTemplate, [string]$HeaderTemplate)

    $header = ($HeaderTemplate -replace '\$\{DISPLAY_NAME\}', $App.displayName).Trim()
    $blocks = @($header)
    foreach ($entry in $Entries) {
        $blocks += Format-HistoryEntry -Entry $entry -Template $EntryTemplate
    }
    return ($blocks -join ([Environment]::NewLine + [Environment]::NewLine)).Trim()
}

function Load-MessageIds {
    if (-not (Test-Path $MessageIdsPath)) {
        return @{}
    }
    return Get-Content $MessageIdsPath -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Save-MessageIds {
    param($IdsObject)
    $json = ($IdsObject | ConvertTo-Json -Depth 5)
    $dir = Split-Path $MessageIdsPath -Parent
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    [System.IO.File]::WriteAllText($MessageIdsPath, "$json`n", [System.Text.UTF8Encoding]::new($false))
}

$apps = Get-Content $AppsJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
$entryTemplate = Get-Content $EntryTemplatePath -Raw -Encoding UTF8
$headerTemplate = Get-Content $HeaderTemplatePath -Raw -Encoding UTF8
$messageIds = Load-MessageIds
$targets = if ($AppFilter) { @($AppFilter) } else { $AppOrder }

# Numeric chat_id required for reliable editMessageText
$ForumChatId = Resolve-ForumChatId $ForumChatId

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

    $message = Build-HistoryMessage -App $app -Entries $entries -EntryTemplate $entryTemplate -HeaderTemplate $headerTemplate

    $stored = $null
    if ($null -ne $messageIds.PSObject.Properties[$appKey]) {
        $stored = $messageIds.$appKey
    }
    $existingId = $null
    if ($null -ne $stored -and $null -ne $stored.PSObject.Properties['historyMessageId']) {
        $rawId = $stored.historyMessageId
        if ($null -ne $rawId -and [string]$rawId -ne '' -and [string]$rawId -ne 'null') {
            $existingId = [int]$rawId
        }
    }

    if (($Mode -eq 'edit' -or $Mode -eq 'sync') -and $existingId) {
        try {
            Edit-TelegramMessage -Text $message -ThreadId $topicId -MessageId $existingId
            Write-Host "Historial editado: $appKey (message $existingId)"
            continue
        }
        catch {
            Write-Host "Edit fallo para $appKey ($existingId), republicando..." -ForegroundColor Yellow
        }
    }

    if ($Mode -eq 'edit') {
        Write-Host "Sin message_id valido para $appKey" -ForegroundColor Yellow
        continue
    }

    $newId = Send-TelegramMessage -Text $message -ThreadId $topicId
    if ($null -eq $messageIds.PSObject.Properties[$appKey]) {
        $messageIds | Add-Member -NotePropertyName $appKey -NotePropertyValue ([pscustomobject]@{ topicId = $topicId; historyMessageId = $newId }) -Force
    }
    else {
        $messageIds.$appKey.topicId = $topicId
        $messageIds.$appKey.historyMessageId = $newId
    }
    Save-MessageIds $messageIds
    Write-Host "Historial publicado: $appKey (message $newId) - borra mensajes viejos duplicados en el topic"
    Start-Sleep -Seconds 1
}

Write-Host "Forum history complete ($ForumChatId) mode=$Mode"
