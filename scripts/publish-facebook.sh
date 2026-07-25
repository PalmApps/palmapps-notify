#!/usr/bin/env bash
set -euo pipefail

ACTION_PATH="${ACTION_PATH:?ACTION_PATH is required}"
APPS_JSON="$ACTION_PATH/templates/apps.json"
TEMPLATE_FILE="$ACTION_PATH/templates/facebook-page-release.txt"
GRAPH_API_VERSION="${META_GRAPH_API_VERSION:-v22.0}"

PAGE_ID="${META_PAGE_ID:-}"
PAGE_TOKEN="${META_PAGE_ACCESS_TOKEN:-}"
APP_KEY="${APP:?APP is required}"
VERSION="${VERSION:?VERSION is required}"
FORUM_LINK="${FORUM_LINK:-https://t.me/palmapps}"

if [[ -z "$PAGE_ID" || -z "$PAGE_TOKEN" ]]; then
  echo "META_PAGE_ID and META_PAGE_ACCESS_TOKEN are required for Facebook publish" >&2
  exit 1
fi

if [[ ! -f "$TEMPLATE_FILE" ]]; then
  echo "Missing template: $TEMPLATE_FILE" >&2
  exit 1
fi

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
PROMO_HOOK=$(jq -r --arg k "$APP_KEY" '.[$k].promoHook // .[$k].summary' "$APPS_JSON" | sed 's/\..*$//')
DEFAULT_WEB=$(jq -r --arg k "$APP_KEY" '.[$k].webUrl // empty' "$APPS_JSON")
DEFAULT_DOWNLOAD=$(jq -r --arg k "$APP_KEY" '.[$k].downloadUrl // empty' "$APPS_JSON")

WEB_URL="${WEB_URL:-}"
if [[ -z "$WEB_URL" || "$WEB_URL" == "null" ]]; then
  WEB_URL="$DEFAULT_WEB"
fi

DOWNLOAD_URL="${DOWNLOAD_URL:-}"
if [[ -z "$DOWNLOAD_URL" || "$DOWNLOAD_URL" == "null" ]]; then
  DOWNLOAD_URL="$DEFAULT_DOWNLOAD"
fi

ACCESS_LINES=()
if [[ -n "$WEB_URL" && "$WEB_URL" != "null" ]]; then
  ACCESS_LINES+=("$WEB_URL")
fi
if [[ -n "$DOWNLOAD_URL" && "$DOWNLOAD_URL" != "null" && "$DOWNLOAD_URL" != "$WEB_URL" ]]; then
  ACCESS_LINES+=("$DOWNLOAD_URL")
fi
if [[ ${#ACCESS_LINES[@]} -eq 0 ]]; then
  ACCESS_LINE="Consulta el foro PalmApps para mas detalles"
else
  ACCESS_LINE=$(printf '%s\n' "${ACCESS_LINES[@]}")
fi

CHANGELOG="${CHANGELOG:-}"
if [[ -n "$CHANGELOG" ]]; then
  CHANGELOG=$(printf '%s\n' "$CHANGELOG" | sed '/^[[:space:]]*$/d' | while IFS= read -r line; do
    line="${line#"${line%%[![:space:]]*}"}"
    if [[ "$line" =~ ^[-•*] ]]; then
      printf '%s\n' "$line"
    else
      printf '- %s\n' "$line"
    fi
  done)
else
  CHANGELOG="- Ver detalles en el foro PalmApps"
fi

export DISPLAY_NAME HASHTAG VERSION PROMO_HOOK CHANGELOG ACCESS_LINE FORUM_LINK

MESSAGE=$(envsubst '$DISPLAY_NAME $HASHTAG $VERSION $PROMO_HOOK $CHANGELOG $ACCESS_LINE $FORUM_LINK' < "$TEMPLATE_FILE")
MESSAGE=$(printf '%s' "$MESSAGE" | sed -e '${/^$/d;}')

LINK_URL="$FORUM_LINK"
if [[ -n "$WEB_URL" && "$WEB_URL" != "null" ]]; then
  LINK_URL="$WEB_URL"
fi

post_photo() {
  local image_path="$1"
  local response

  response=$(curl -sS -X POST "https://graph.facebook.com/${GRAPH_API_VERSION}/${PAGE_ID}/photos" \
    -F "message=${MESSAGE}" \
    -F "source=@${image_path}" \
    -F "access_token=${PAGE_TOKEN}")

  if ! jq -e '.id != null' <<<"$response" >/dev/null 2>&1; then
    echo "Facebook photo API error:" >&2
    jq . <<<"$response" >&2 || echo "$response" >&2
    return 1
  fi

  echo "Facebook photo post published (id: $(jq -r '.id // .post_id // empty' <<<"$response"))"
  return 0
}

post_feed() {
  local response

  response=$(curl -sS -G "https://graph.facebook.com/${GRAPH_API_VERSION}/${PAGE_ID}/feed" \
    --data-urlencode "message=${MESSAGE}" \
    --data-urlencode "link=${LINK_URL}" \
    --data-urlencode "access_token=${PAGE_TOKEN}" \
    -X POST)

  if ! jq -e '.id != null' <<<"$response" >/dev/null 2>&1; then
    echo "Facebook feed API error:" >&2
    jq . <<<"$response" >&2 || echo "$response" >&2
    return 1
  fi

  echo "Facebook feed post published (id: $(jq -r '.id' <<<"$response"))"
  return 0
}

IMAGE_PATH="${FACEBOOK_IMAGE_PATH:-}"
if [[ -n "$IMAGE_PATH" && -f "$IMAGE_PATH" ]]; then
  post_photo "$IMAGE_PATH"
else
  post_feed
fi
