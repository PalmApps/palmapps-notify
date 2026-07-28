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

$IconApp = Get-Utf8String 0xF0, 0x9F, 0x93, 0xB1

$ActionPath = if ($env:ACTION_PATH) { $env:ACTION_PATH } else { Split-Path -Parent $PSScriptRoot }
$AppsJsonPath = Join-Path $ActionPath 'templates\apps.json'
$WelcomePath = Join-Path $ActionPath 'templates\forum-welcome.txt'
$IntroPath = Join-Path $ActionPath 'templates\forum-app-detail.txt'
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

$ForumChatId = if ($env:TELEGRAM_FORUM_CHAT_ID) { $env:TELEGRAM_FORUM_CHAT_ID } else { '@palmapps' }
$Mode = if ($env:MODE) { $env:MODE } else { 'setup' }
$AppFilter = $env:APP
$AppOrder = @('costify', 'reservas', 'viajando', 'carta-restaurante', 'rensoli-commerce', 'ofertas-cuba')
$GeneralTopicId = 0

function Invoke-TelegramApi {
    param(
        [string]$Method,
        [hashtable]$Body
    )

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
        if ($detail) {
            throw "Telegram API $Method failed: $detail"
        }
        throw
    }
}

function Send-TelegramMessage {
    param(
        [string]$Text,
        [int]$ThreadId = 0
    )

    $payload = [ordered]@{
        chat_id = $ForumChatId
        text = $Text
        disable_web_page_preview = $false
    }
    if ($ThreadId -gt 0) {
        $payload.message_thread_id = $ThreadId
    }

    $response = Invoke-TelegramApi -Method 'sendMessage' -Body $payload
    if (-not $response.ok) {
        throw "Telegram sendMessage error: $($response | ConvertTo-Json -Compress)"
    }
}

function Get-BotCanManageTopics {
    $me = Invoke-TelegramApi -Method 'getMe' -Body @{}
    if (-not $me.ok) {
        throw 'getMe failed'
    }

    $member = Invoke-TelegramApi -Method 'getChatMember' -Body @{
        chat_id = $ForumChatId
        user_id = $me.result.id
    }

    if (-not $member.ok) {
        throw 'getChatMember failed'
    }

    return [bool]$member.result.can_manage_topics
}

function Save-AppsJson {
    param($AppsObject)

    $json = ($AppsObject | ConvertTo-Json -Depth 10)
    [System.IO.File]::WriteAllText($AppsJsonPath, "$json`n", [System.Text.UTF8Encoding]::new($false))
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

function Get-AppProperty {
    param(
        $App,
        [string]$Name
    )

    $prop = $App.PSObject.Properties[$Name]
    if ($null -eq $prop) {
        return ''
    }

    return [string]$prop.Value
}

function Get-FeaturesBlock {
    param($App)

    $features = $App.PSObject.Properties['features']
    if ($null -eq $features -or $null -eq $features.Value) {
        return '• Ver resumen arriba'
    }

    $lines = @()
    foreach ($feature in @($features.Value)) {
        if ([string]::IsNullOrWhiteSpace([string]$feature)) { continue }
        $lines += "• $feature"
    }

    if ($lines.Count -eq 0) {
        return '• Ver resumen arriba'
    }

    return ($lines -join [Environment]::NewLine)
}

function Get-StackBlock {
    param($App)

    $stack = Get-AppProperty $App 'stack'
    if ([string]::IsNullOrWhiteSpace($stack)) {
        return ''
    }

    return "Stack: $stack"
}

function Get-ForumTopicId {
    param($App)

    $prop = $App.PSObject.Properties['forumTopicId']
    if ($null -eq $prop -or [string]::IsNullOrWhiteSpace([string]$prop.Value)) {
        return $null
    }

    return [int]$prop.Value
}

function New-ForumTopics {
    param($AppsObject)

    $canManage = Get-BotCanManageTopics
    if (-not $canManage) {
        Write-Host ''
        Write-Host 'BLOQUEADO: el bot no tiene permiso "Manage Topics" en' $ForumChatId -ForegroundColor Yellow
        Write-Host 'Telegram -> Grupo -> Admins -> @PalmAppsNotify_bot -> activar "Gestionar topics"' -ForegroundColor Yellow
        Write-Host 'Luego vuelve a ejecutar: .\scripts\setup-forum.ps1' -ForegroundColor Yellow
        Write-Host ''
        exit 2
    }

    foreach ($appKey in $AppOrder) {
        $app = $AppsObject.$appKey
        $existingTopicId = Get-ForumTopicId $app
        if ($existingTopicId) {
            Write-Host "Topic ya configurado: $appKey (id $existingTopicId)"
            continue
        }

        $topicName = $app.displayName
        $response = Invoke-TelegramApi -Method 'createForumTopic' -Body @{
            chat_id = $ForumChatId
            name = $topicName
        }

        if (-not $response.ok) {
            throw "createForumTopic failed for $appKey"
        }

        $threadId = [int]$response.result.message_thread_id
        $app | Add-Member -NotePropertyName forumTopicId -NotePropertyValue $threadId -Force
        Write-Host "Topic creado: $topicName -> thread $threadId"
        Start-Sleep -Seconds 1
    }

    Save-AppsJson $AppsObject
    Write-Host "apps.json actualizado con forumTopicId"
}

function Get-AppsCatalogBlock {
    param($AppsObject)

    $lines = @()
    foreach ($appKey in $AppOrder) {
        $app = $AppsObject.$appKey
        $tagline = Get-AppProperty $app 'forumTagline'
        if ([string]::IsNullOrWhiteSpace($tagline)) {
            $tagline = ($app.summary -replace '\..*$', '').Trim()
        }
        $lines += "$IconApp $($app.displayName) - $tagline"
    }

    return ($lines -join [Environment]::NewLine)
}

function Send-ForumWelcome {
    param($AppsObject)

    $template = (Get-Content $WelcomePath -Raw -Encoding UTF8).Trim()
    $catalog = Get-AppsCatalogBlock $AppsObject
    $message = $template -replace '\$\{APPS_CATALOG_BLOCK\}', $catalog
    Send-TelegramMessage -Text $message -ThreadId $GeneralTopicId
    Write-Host 'Bienvenida marketing publicada en General'
}

function Send-ForumIntros {
    param(
        $AppsObject,
        [switch]$SkipWelcome
    )

    if (-not $SkipWelcome) {
        Send-ForumWelcome $AppsObject
        Start-Sleep -Seconds 1
    }

    $introTemplate = Get-Content $IntroPath -Raw -Encoding UTF8
    $targets = if ($AppFilter) { @($AppFilter) } else { $AppOrder }
    foreach ($appKey in $targets) {
        $app = $AppsObject.$appKey
        $topicId = Get-ForumTopicId $app
        if (-not $topicId) {
            Write-Host "Omitido $appKey (sin forumTopicId)" -ForegroundColor Yellow
            continue
        }

        $accessBlock = Get-AccessBlock $app
        $repoBlock = if ($app.repoUrl) { "$IconRepo C$([char]0x00F3)digo: $($app.repoUrl)" } else { '' }
        $featuresBlock = Get-FeaturesBlock $app
        $platforms = Get-AppProperty $app 'platforms'
        if ([string]::IsNullOrWhiteSpace($platforms)) { $platforms = 'Web' }
        $stackBlock = Get-StackBlock $app
        $audience = Get-AppProperty $app 'audience'
        if ([string]::IsNullOrWhiteSpace($audience)) { $audience = $app.summary }

        $message = $introTemplate `
            -replace '\$\{DISPLAY_NAME\}', $app.displayName `
            -replace '\$\{HASHTAG\}', $app.hashtag `
            -replace '\$\{SUMMARY\}', $app.summary `
            -replace '\$\{AUDIENCE\}', $audience `
            -replace '\$\{FEATURES_BLOCK\}', $featuresBlock `
            -replace '\$\{PLATFORMS\}', $platforms `
            -replace '\$\{STACK_BLOCK\}', $stackBlock `
            -replace '\$\{ACCESS_BLOCK\}', $accessBlock `
            -replace '\$\{REPO_BLOCK\}', $repoBlock

        Send-TelegramMessage -Text $message.Trim() -ThreadId $topicId
        Write-Host "Intro publicada: $appKey (thread $topicId)"
        Start-Sleep -Seconds 1
    }
}

$apps = Get-Content $AppsJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json

switch ($Mode) {
    'topics' {
        New-ForumTopics $apps
    }
    'post' {
        Send-ForumIntros $apps
    }
    'apps' {
        Send-ForumIntros $apps -SkipWelcome
    }
    'welcome' {
        Send-ForumWelcome $apps
    }
    'setup' {
        New-ForumTopics $apps
        Send-ForumIntros $apps
    }
    default {
        throw "Unknown MODE: $Mode (use setup | topics | post | apps | welcome)"
    }
}

Write-Host "PalmApps forum setup complete ($ForumChatId)"
