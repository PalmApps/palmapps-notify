#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $env:APP -or -not $env:MESSAGE_ID) {
    throw 'Uso: $env:APP=''costify''; $env:MESSAGE_ID=123; .\scripts\set-forum-message-id.ps1'
}

$ActionPath = if ($env:ACTION_PATH) { $env:ACTION_PATH } else { Split-Path -Parent $PSScriptRoot }
$MessageIdsPath = Join-Path $ActionPath 'data\forum-message-ids.json'
$AppsJsonPath = Join-Path $ActionPath 'templates\apps.json'

$apps = Get-Content $AppsJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
$app = $apps.($env:APP)
if (-not $app) { throw "App desconocida: $($env:APP)" }

$topicId = [int]$app.forumTopicId
$messageId = [int]$env:MESSAGE_ID

if (Test-Path $MessageIdsPath) {
    $messageIds = Get-Content $MessageIdsPath -Raw -Encoding UTF8 | ConvertFrom-Json
}
else {
    $messageIds = [pscustomobject]@{}
}

if (-not $messageIds.($env:APP)) {
    $messageIds | Add-Member -NotePropertyName $env:APP -NotePropertyValue ([pscustomobject]@{}) -Force
}

$messageIds.($env:APP).topicId = $topicId
$messageIds.($env:APP).historyMessageId = $messageId

$json = ($messageIds | ConvertTo-Json -Depth 5)
$dir = Split-Path $MessageIdsPath -Parent
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
[System.IO.File]::WriteAllText($MessageIdsPath, "$json`n", [System.Text.UTF8Encoding]::new($false))

Write-Host "Guardado $($env:APP) -> message_id $messageId (topic $topicId)"
Write-Host "Ejecuta: `$env:MODE='edit'; `$env:APP='$($env:APP)'; .\scripts\post-forum-history.ps1"
