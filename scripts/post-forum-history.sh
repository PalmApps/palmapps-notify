#!/usr/bin/env bash
set -euo pipefail

ACTION_PATH="${ACTION_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"
APPS_JSON="$ACTION_PATH/templates/apps.json"
HISTORY_DIR="$ACTION_PATH/templates/history"
ENTRY_TEMPLATE="$ACTION_PATH/templates/forum-history-entry.txt"
HEADER_TEMPLATE="$ACTION_PATH/templates/forum-history-header.txt"

if [[ -z "${TELEGRAM_BOT_TOKEN:-}" ]]; then
  echo "TELEGRAM_BOT_TOKEN is required" >&2
  exit 1
fi

FORUM_CHAT_ID="${TELEGRAM_FORUM_CHAT_ID:-@palmapps}"
APP_FILTER="${APP:-}"
APP_ORDER=(costify reservas viajando carta-restaurante rensoli-commerce)

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi

send_message() {
  local text="$1"
  local thread_id="$2"
  local payload response
  payload=$(jq -n \
    --arg chat_id "$FORUM_CHAT_ID" \
    --arg text "$text" \
    --argjson thread_id "$thread_id" \
    '{chat_id: $chat_id, message_thread_id: $thread_id, text: $text, disable_web_page_preview: false}')
  response=$(curl -sS -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -H "Content-Type: application/json; charset=utf-8" \
    --data-binary "$payload")
  if ! jq -e '.ok == true' <<<"$response" >/dev/null 2>&1; then
    echo "Telegram API error:" >&2
    jq . <<<"$response" >&2 || echo "$response" >&2
    exit 1
  fi
}

format_entry() {
  local entry_json="$1"
  local title version date date_block changes_block line
  title=$(jq -r '.title' <<<"$entry_json")
  version=$(jq -r '.version' <<<"$entry_json")
  date=$(jq -r '.date // empty' <<<"$entry_json")
  date_block=""
  if [[ -n "$date" && "$date" != "null" ]]; then
    date_block=" · ${date}"
  fi
  changes_block=$(jq -r '.changes[]? // empty' <<<"$entry_json" | sed '/^$/d' | while IFS= read -r line; do
    printf '• %s\n' "$line"
  done)
  if [[ -z "$changes_block" ]]; then
    changes_block="• Mejoras generales"
  fi
  export TITLE="$title" VERSION="$version" DATE_BLOCK="$date_block" CHANGES_BLOCK="$changes_block"
  envsubst '$TITLE $VERSION $DATE_BLOCK $CHANGES_BLOCK' < "$ENTRY_TEMPLATE"
}

targets=("${APP_ORDER[@]}")
if [[ -n "$APP_FILTER" ]]; then
  targets=("$APP_FILTER")
fi

for app_key in "${targets[@]}"; do
  history_file="$HISTORY_DIR/${app_key}.json"
  thread_id=$(jq -r --arg k "$app_key" '.[$k].forumTopicId // empty' "$APPS_JSON")
  display_name=$(jq -r --arg k "$app_key" '.[$k].displayName' "$APPS_JSON")

  if [[ -z "$thread_id" || "$thread_id" == "null" ]]; then
    echo "Omitido ${app_key} (sin forumTopicId)"
    continue
  fi
  if [[ ! -f "$history_file" ]]; then
    echo "Omitido ${app_key} (sin history)"
    continue
  fi

  header=$(export DISPLAY_NAME="$display_name"; envsubst '$DISPLAY_NAME' < "$HEADER_TEMPLATE")
  header=$(printf '%s' "$header" | sed -e '${/^$/d;}')
  send_message "$header" "$thread_id"
  echo "Historial iniciado: ${app_key}"
  sleep 1

  while IFS= read -r entry; do
    message=$(format_entry "$entry")
    message=$(printf '%s' "$message" | sed -e '${/^$/d;}')
    send_message "$message" "$thread_id"
    echo "  -> $(jq -r '.title' <<<"$entry")"
    sleep 1
  done < <(jq -c '.entries[]' "$history_file")
done

echo "Forum history complete (${FORUM_CHAT_ID})"
