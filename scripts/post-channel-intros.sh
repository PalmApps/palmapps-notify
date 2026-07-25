#!/usr/bin/env bash
set -euo pipefail

ACTION_PATH="${ACTION_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"
APPS_JSON="$ACTION_PATH/templates/apps.json"
WELCOME_FILE="$ACTION_PATH/templates/channel-welcome.txt"
INTRO_FILE="$ACTION_PATH/templates/channel-app-intro.txt"

if [[ -z "${TELEGRAM_BOT_TOKEN:-}" ]]; then
  echo "TELEGRAM_BOT_TOKEN is required" >&2
  exit 1
fi

CHANNEL_ID="${TELEGRAM_CHANNEL_ID:-@palmapps}"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi

if ! command -v envsubst >/dev/null 2>&1; then
  echo "envsubst is required (gettext)" >&2
  exit 1
fi

send_message() {
  local message="$1"
  local payload response
  payload=$(jq -n \
    --arg chat_id "$CHANNEL_ID" \
    --arg text "$message" \
    '{chat_id: $chat_id, text: $text, disable_web_page_preview: false}')
  response=$(curl -sS -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -H "Content-Type: application/json; charset=utf-8" \
    --data-binary "$payload")

  if ! jq -e '.ok == true' <<<"$response" >/dev/null 2>&1; then
    echo "Telegram API error:" >&2
    jq . <<<"$response" >&2 || echo "$response" >&2
    exit 1
  fi
}

build_access_block() {
  local web_url="$1"
  local download_url="$2"
  local lines=()

  if [[ -n "$web_url" && "$web_url" != "null" ]]; then
    lines+=("🌐 Web: ${web_url}")
  fi
  if [[ -n "$download_url" && "$download_url" != "null" ]]; then
    lines+=("📲 Descarga / APK: ${download_url}")
  fi
  if [[ ${#lines[@]} -eq 0 ]]; then
    lines+=("$(tr -d '\r' < "$ACTION_PATH/templates/channel-access-local.txt")")
  fi

  printf '%s\n' "${lines[@]}"
}

post_welcome() {
  local message
  message=$(cat "$WELCOME_FILE" | sed -e '${/^$/d;}')
  send_message "$message"
  echo "Welcome message sent"
}

post_app_intro() {
  local app_key="$1"
  local display_name hashtag summary web_url download_url repo_url access_block repo_block message

  display_name=$(jq -r --arg k "$app_key" '.[$k].displayName' "$APPS_JSON")
  hashtag=$(jq -r --arg k "$app_key" '.[$k].hashtag' "$APPS_JSON")
  summary=$(jq -r --arg k "$app_key" '.[$k].summary' "$APPS_JSON")
  web_url=$(jq -r --arg k "$app_key" '.[$k].webUrl' "$APPS_JSON")
  download_url=$(jq -r --arg k "$app_key" '.[$k].downloadUrl' "$APPS_JSON")
  repo_url=$(jq -r --arg k "$app_key" '.[$k].repoUrl' "$APPS_JSON")

  access_block=$(build_access_block "$web_url" "$download_url")
  repo_block=""
  if [[ -n "$repo_url" && "$repo_url" != "null" ]]; then
    repo_block="🔗 Código: ${repo_url}"
  fi

  export DISPLAY_NAME="$display_name"
  export HASHTAG="$hashtag"
  export SUMMARY="$summary"
  export ACCESS_BLOCK="$access_block"
  export REPO_BLOCK="$repo_block"

  message=$(envsubst '$DISPLAY_NAME $HASHTAG $SUMMARY $ACCESS_BLOCK $REPO_BLOCK' < "$INTRO_FILE")
  message=$(printf '%s' "$message" | sed -e '${/^$/d;}')
  send_message "$message"
  echo "Intro sent: ${app_key}"
}

APP_ORDER=(costify reservas viajando carta-restaurante rensoli-commerce)

case "${MODE:-all}" in
  welcome)
    post_welcome
    ;;
  apps)
    for app_key in "${APP_ORDER[@]}"; do
      post_app_intro "$app_key"
      sleep 1
    done
    ;;
  all|*)
    post_welcome
    sleep 1
    for app_key in "${APP_ORDER[@]}"; do
      post_app_intro "$app_key"
      sleep 1
    done
    ;;
esac

echo "PalmApps channel intros complete (${CHANNEL_ID})"
