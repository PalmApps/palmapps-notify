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

CHANNEL_ID="${TELEGRAM_CHANNEL_ID:-@palmapps}"
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
  CHANGELOG="• Ver notas completas en el enlace de release"
fi

DOWNLOAD_BLOCK=""
if [[ -n "$DOWNLOAD_URL" && "$DOWNLOAD_URL" != "null" ]]; then
  DOWNLOAD_BLOCK="Página: $DOWNLOAD_URL"
fi
if [[ -n "$RELEASE_PAGE_URL" && "$RELEASE_PAGE_URL" != "null" ]]; then
  if [[ -n "$DOWNLOAD_BLOCK" ]]; then
    DOWNLOAD_BLOCK="${DOWNLOAD_BLOCK}"$'\n'"Release: $RELEASE_PAGE_URL"
  else
    DOWNLOAD_BLOCK="Release: $RELEASE_PAGE_URL"
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

RESPONSE=$(curl -sS -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${CHANNEL_ID}" \
  --data-urlencode "text=${MESSAGE}" \
  --data-urlencode "disable_web_page_preview=false")

if ! jq -e '.ok == true' <<<"$RESPONSE" >/dev/null 2>&1; then
  echo "Telegram API error:" >&2
  jq . <<<"$RESPONSE" >&2 || echo "$RESPONSE" >&2
  exit 1
fi

echo "PalmApps Telegram notification sent to ${CHANNEL_ID}"
