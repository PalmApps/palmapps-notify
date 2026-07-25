#!/usr/bin/env bash
set -euo pipefail

ACTION_PATH="${ACTION_PATH:?ACTION_PATH is required}"
APPS_JSON="$ACTION_PATH/templates/apps.json"
TEMPLATE_NAME="${TEMPLATE:-android-release}"
TEMPLATE_FILE="$ACTION_PATH/templates/${TEMPLATE_NAME}.txt"

if [[ ! -f "$TEMPLATE_FILE" ]]; then
  echo "Unknown template: $TEMPLATE_NAME" >&2
  exit 1
fi

if [[ -z "${TELEGRAM_BOT_TOKEN:-}" ]]; then
  echo "TELEGRAM_BOT_TOKEN is required" >&2
  exit 1
fi

CHANNEL_ID="${TELEGRAM_CHANNEL_ID:-}"
FORUM_CHAT_ID="${TELEGRAM_FORUM_CHAT_ID:-}"
NOTIFY_FORUM="${NOTIFY_FORUM:-true}"
NOTIFY_CHANNEL="${NOTIFY_CHANNEL:-false}"
APP_KEY="${APP:?APP is required}"
VERSION="${VERSION:?VERSION is required}"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required on the runner" >&2
  exit 1
fi

if ! jq -e --arg k "$APP_KEY" '.[$k]' "$APPS_JSON" >/dev/null; then
  echo "Unknown app key: $APP_KEY (see templates/apps.json)" >&2
  exit 1
fi

DISPLAY_NAME=$(jq -r --arg k "$APP_KEY" '.[$k].displayName' "$APPS_JSON")
HASHTAG=$(jq -r --arg k "$APP_KEY" '.[$k].hashtag' "$APPS_JSON")
DEFAULT_WEB=$(jq -r --arg k "$APP_KEY" '.[$k].webUrl' "$APPS_JSON")
DEFAULT_DOWNLOAD=$(jq -r --arg k "$APP_KEY" '.[$k].downloadUrl' "$APPS_JSON")
FORUM_TOPIC_ID=$(jq -r --arg k "$APP_KEY" '.[$k].forumTopicId // empty' "$APPS_JSON")

WEB_URL="${WEB_URL:-}"
if [[ -z "$WEB_URL" || "$WEB_URL" == "null" ]]; then
  WEB_URL="$DEFAULT_WEB"
fi

DOWNLOAD_URL="${DOWNLOAD_URL:-}"
if [[ -z "$DOWNLOAD_URL" || "$DOWNLOAD_URL" == "null" ]]; then
  DOWNLOAD_URL="$DEFAULT_DOWNLOAD"
fi

RELEASE_PAGE_URL="${RELEASE_PAGE_URL:-}"

# Changelog: ensure bullet lines
CHANGELOG="${CHANGELOG:-}"
if [[ -n "$CHANGELOG" ]]; then
  CHANGELOG=$(printf '%s\n' "$CHANGELOG" | sed '/^[[:space:]]*$/d' | while IFS= read -r line; do
    line="${line#"${line%%[![:space:]]*}"}"
    if [[ "$line" =~ ^[-•*] ]]; then
      printf '%s\n' "$line"
    else
      printf '• %s\n' "$line"
    fi
  done)
else
  CHANGELOG="• Ver detalles en el enlace de la version"
fi

DOWNLOAD_BLOCK=""
if [[ -n "$DOWNLOAD_URL" && "$DOWNLOAD_URL" != "null" ]]; then
  DOWNLOAD_BLOCK="Página: $DOWNLOAD_URL"
fi
if [[ -n "$RELEASE_PAGE_URL" && "$RELEASE_PAGE_URL" != "null" ]]; then
  if [[ -n "$DOWNLOAD_BLOCK" ]]; then
    DOWNLOAD_BLOCK="${DOWNLOAD_BLOCK}"$'\n'"Mas info: $RELEASE_PAGE_URL"
  else
    DOWNLOAD_BLOCK="Mas info: $RELEASE_PAGE_URL"
  fi
fi
if [[ -z "$DOWNLOAD_BLOCK" ]]; then
  DOWNLOAD_BLOCK="(sin enlace de descarga configurado)"
fi

EXTRA_BLOCK=""
EXTRA_LINES="${EXTRA_LINES:-}"
if [[ -n "$COMMIT" && "$COMMIT" != "null" ]]; then
  if [[ "$EXTRA_LINES" != *"$COMMIT"* ]]; then
    if [[ -n "$EXTRA_LINES" ]]; then
      EXTRA_LINES="${EXTRA_LINES}"$'\n'"Commit: ${COMMIT}"
    else
      EXTRA_LINES="Commit: ${COMMIT}"
    fi
  fi
fi
if [[ -n "$EXTRA_LINES" ]]; then
  EXTRA_BLOCK="$EXTRA_LINES"
fi

export DISPLAY_NAME HASHTAG VERSION CHANGELOG DOWNLOAD_BLOCK WEB_URL EXTRA_BLOCK

MESSAGE=$(envsubst '$DISPLAY_NAME $HASHTAG $VERSION $CHANGELOG $DOWNLOAD_BLOCK $WEB_URL $EXTRA_BLOCK' < "$TEMPLATE_FILE")
MESSAGE=$(printf '%s' "$MESSAGE" | sed -e '${/^$/d;}')

send_telegram_message() {
  local chat_id="$1"
  local text="$2"
  local thread_id="${3:-}"
  local payload response

  if [[ -n "$thread_id" && "$thread_id" != "null" ]]; then
    payload=$(jq -n \
      --arg chat_id "$chat_id" \
      --arg text "$text" \
      --argjson thread_id "$thread_id" \
      '{chat_id: $chat_id, message_thread_id: $thread_id, text: $text, disable_web_page_preview: false}')
  else
    payload=$(jq -n \
      --arg chat_id "$chat_id" \
      --arg text "$text" \
      '{chat_id: $chat_id, text: $text, disable_web_page_preview: false}')
  fi

  response=$(curl -sS -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -H "Content-Type: application/json; charset=utf-8" \
    --data-binary "$payload")

  if ! jq -e '.ok == true' <<<"$response" >/dev/null 2>&1; then
    echo "Telegram API error (${chat_id}):" >&2
    jq . <<<"$response" >&2 || echo "$response" >&2
    return 1
  fi

  return 0
}

sent_any=false

if [[ -n "$FORUM_CHAT_ID" && "$NOTIFY_FORUM" != "false" && -n "$FORUM_TOPIC_ID" && "$FORUM_TOPIC_ID" != "null" ]]; then
  if send_telegram_message "$FORUM_CHAT_ID" "$MESSAGE" "$FORUM_TOPIC_ID"; then
    echo "PalmApps notification sent to ${FORUM_CHAT_ID} (topic ${FORUM_TOPIC_ID})"
    sent_any=true
  else
    echo "Forum notification failed for ${FORUM_CHAT_ID} (topic ${FORUM_TOPIC_ID})" >&2
  fi
elif [[ -n "$FORUM_CHAT_ID" && "$NOTIFY_FORUM" != "false" ]]; then
  echo "No forumTopicId for app ${APP_KEY} in apps.json — run scripts/setup-forum.ps1" >&2
fi

if [[ "$NOTIFY_CHANNEL" == "true" && -n "$CHANNEL_ID" ]]; then
  if send_telegram_message "$CHANNEL_ID" "$MESSAGE"; then
    echo "PalmApps notification sent to channel ${CHANNEL_ID}"
    sent_any=true
  else
    echo "Channel notification failed for ${CHANNEL_ID}" >&2
  fi
elif [[ "$sent_any" == false && -n "$CHANNEL_ID" ]]; then
  if send_telegram_message "$CHANNEL_ID" "$MESSAGE"; then
    echo "PalmApps notification sent to channel ${CHANNEL_ID}"
    sent_any=true
  else
    echo "Channel notification failed for ${CHANNEL_ID}" >&2
  fi
fi

if [[ "$sent_any" == false ]]; then
  echo "No notification sent. Configure TELEGRAM_FORUM_CHAT_ID (@palmapps) + forumTopicId, or TELEGRAM_CHANNEL_ID for legacy mode." >&2
  exit 1
fi
