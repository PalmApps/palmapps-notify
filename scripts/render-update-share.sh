#!/usr/bin/env bash
# Renderiza el resumen compartible (topic General + WhatsApp / Facebook / Instagram).
# Uso: APP=costify VERSION=1.0.21 CHANGELOG=$'...\n...' ACTION_PATH=. bash scripts/render-update-share.sh

set -euo pipefail

ACTION_PATH="${ACTION_PATH:?ACTION_PATH is required}"
APPS_JSON="$ACTION_PATH/templates/apps.json"
TEMPLATE_FILE="$ACTION_PATH/templates/forum-general-update.txt"
APP_KEY="${APP:?APP is required}"
VERSION="${VERSION:?VERSION is required}"
FORUM_CHAT_ID="${TELEGRAM_FORUM_CHAT_ID:-@palmapps}"
FORUM_LINK="${FORUM_LINK:-https://t.me/palmapps}"

if [[ ! -f "$TEMPLATE_FILE" ]]; then
  echo "Missing template: $TEMPLATE_FILE" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi

if ! jq -e --arg k "$APP_KEY" '.[$k]' "$APPS_JSON" >/dev/null; then
  echo "Unknown app key: $APP_KEY" >&2
  exit 1
fi

DISPLAY_NAME=$(jq -r --arg k "$APP_KEY" '.[$k].displayName' "$APPS_JSON")
HASHTAG=$(jq -r --arg k "$APP_KEY" '.[$k].hashtag' "$APPS_JSON")
DEFAULT_WEB=$(jq -r --arg k "$APP_KEY" '.[$k].webUrl' "$APPS_JSON")
FORUM_TOPIC_ID=$(jq -r --arg k "$APP_KEY" '.[$k].forumTopicId // empty' "$APPS_JSON")

WEB_URL="${WEB_URL:-}"
if [[ -z "$WEB_URL" || "$WEB_URL" == "null" ]]; then
  WEB_URL="$DEFAULT_WEB"
fi

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
  CHANGELOG="• Ver detalles en el topic de la app"
fi

CHANGELOG_SUMMARY=$(printf '%s\n' "$CHANGELOG" | head -n 3)
if [[ $(printf '%s\n' "$CHANGELOG" | sed '/^$/d' | wc -l | tr -d ' ') -gt 3 ]]; then
  CHANGELOG_SUMMARY="${CHANGELOG_SUMMARY}"$'\n'"• … y más en el topic"
fi

WEB_BLOCK=""
if [[ -n "$WEB_URL" && "$WEB_URL" != "null" ]]; then
  WEB_BLOCK=$'🌐 Probar ahora: '"${WEB_URL}"$'\n\n'
fi

FORUM_USERNAME="${FORUM_CHAT_ID#@}"
if [[ "$FORUM_USERNAME" == "$FORUM_CHAT_ID" || -z "$FORUM_USERNAME" ]]; then
  FORUM_USERNAME="palmapps"
fi

TOPIC_LINK="${FORUM_LINK}"
if [[ -n "$FORUM_TOPIC_ID" && "$FORUM_TOPIC_ID" != "null" ]]; then
  TOPIC_LINK="https://t.me/${FORUM_USERNAME}/${FORUM_TOPIC_ID}"
fi

export DISPLAY_NAME HASHTAG VERSION CHANGELOG_SUMMARY TOPIC_LINK WEB_BLOCK FORUM_LINK

MESSAGE=$(envsubst '$DISPLAY_NAME $HASHTAG $VERSION $CHANGELOG_SUMMARY $TOPIC_LINK $WEB_BLOCK $FORUM_LINK' < "$TEMPLATE_FILE")
printf '%s' "$MESSAGE" | sed -e '${/^$/d;}'
