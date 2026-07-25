#!/usr/bin/env bash
set -euo pipefail

ACTION_PATH="${ACTION_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"
APPS_JSON="$ACTION_PATH/templates/apps.json"
WELCOME_FILE="$ACTION_PATH/templates/forum-welcome.txt"
INTRO_FILE="$ACTION_PATH/templates/forum-app-detail.txt"
ACCESS_LOCAL_FILE="$ACTION_PATH/templates/channel-access-local.txt"

if [[ -z "${TELEGRAM_BOT_TOKEN:-}" ]]; then
  echo "TELEGRAM_BOT_TOKEN is required" >&2
  exit 1
fi

FORUM_CHAT_ID="${TELEGRAM_FORUM_CHAT_ID:-@palmapps}"
MODE="${MODE:-setup}"
GENERAL_TOPIC_ID=0
APP_ORDER=(costify reservas viajando carta-restaurante rensoli-commerce)

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi

telegram_api() {
  local method="$1"
  local payload="$2"
  curl -sS -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/${method}" \
    -H "Content-Type: application/json; charset=utf-8" \
    --data-binary "$payload"
}

send_message() {
  local text="$1"
  local thread_id="${2:-0}"
  local payload response

  if [[ "$thread_id" -gt 0 ]]; then
    payload=$(jq -n \
      --arg chat_id "$FORUM_CHAT_ID" \
      --arg text "$text" \
      --argjson thread_id "$thread_id" \
      '{chat_id: $chat_id, message_thread_id: $thread_id, text: $text, disable_web_page_preview: false}')
  else
    payload=$(jq -n \
      --arg chat_id "$FORUM_CHAT_ID" \
      --arg text "$text" \
      '{chat_id: $chat_id, text: $text, disable_web_page_preview: false}')
  fi

  response=$(curl -sS -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -H "Content-Type: application/json; charset=utf-8" \
    --data-binary "$payload")

  if ! jq -e '.ok == true' <<<"$response" >/dev/null 2>&1; then
    echo "Telegram API error:" >&2
    jq . <<<"$response" >&2 || echo "$response" >&2
    exit 1
  fi
}

bot_can_manage_topics() {
  local bot_id member
  bot_id=$(curl -sS "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getMe" | jq -r '.result.id')
  member=$(curl -sS -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getChatMember" \
    -H "Content-Type: application/json; charset=utf-8" \
    --data-binary "$(jq -n --arg chat_id "$FORUM_CHAT_ID" --argjson user_id "$bot_id" '{chat_id: $chat_id, user_id: $user_id}')")
  jq -e '.result.can_manage_topics == true' <<<"$member" >/dev/null 2>&1
}

create_topics() {
  if ! bot_can_manage_topics; then
    echo "" >&2
    echo "BLOQUEADO: el bot no tiene permiso Manage Topics en ${FORUM_CHAT_ID}" >&2
    echo "Telegram -> Grupo -> Admins -> @PalmAppsNotify_bot -> activar Gestionar topics" >&2
    echo "Luego: bash scripts/setup-forum.sh" >&2
    echo "" >&2
    exit 2
  fi

  for app_key in "${APP_ORDER[@]}"; do
    local display_name existing topic_name response thread_id
    display_name=$(jq -r --arg k "$app_key" '.[$k].displayName' "$APPS_JSON")
    existing=$(jq -r --arg k "$app_key" '.[$k].forumTopicId // empty' "$APPS_JSON")

    if [[ -n "$existing" && "$existing" != "null" ]]; then
      echo "Topic ya configurado: ${app_key} (id ${existing})"
      continue
    fi

    topic_name="$display_name"
    response=$(curl -sS -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/createForumTopic" \
      -H "Content-Type: application/json; charset=utf-8" \
      --data-binary "$(jq -n --arg chat_id "$FORUM_CHAT_ID" --arg name "$topic_name" '{chat_id: $chat_id, name: $name}')")

    if ! jq -e '.ok == true' <<<"$response" >/dev/null 2>&1; then
      echo "createForumTopic failed for ${app_key}:" >&2
      jq . <<<"$response" >&2 || echo "$response" >&2
      exit 1
    fi

    thread_id=$(jq -r '.result.message_thread_id' <<<"$response")
    jq --arg k "$app_key" --argjson tid "$thread_id" '.[$k].forumTopicId = $tid' "$APPS_JSON" > "${APPS_JSON}.tmp"
    mv "${APPS_JSON}.tmp" "$APPS_JSON"
    echo "Topic creado: ${topic_name} -> thread ${thread_id}"
    sleep 1
  done

  echo "apps.json actualizado con forumTopicId"
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
    lines+=("$(tr -d '\r' < "$ACCESS_LOCAL_FILE")")
  fi

  printf '%s\n' "${lines[@]}"
}

build_features_block() {
  local app_key="$1"
  local lines
  lines=$(jq -r --arg k "$app_key" '.[$k].features[]? // empty' "$APPS_JSON")
  if [[ -z "$lines" ]]; then
    echo "• Ver resumen arriba"
    return
  fi
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    printf '• %s\n' "$line"
  done <<< "$lines"
}

build_stack_block() {
  local app_key="$1"
  local stack
  stack=$(jq -r --arg k "$app_key" '.[$k].stack // empty' "$APPS_JSON")
  if [[ -n "$stack" && "$stack" != "null" ]]; then
    printf 'Stack: %s' "$stack"
  fi
}

build_apps_catalog_block() {
  local app_key tagline display_name lines=()
  for app_key in "${APP_ORDER[@]}"; do
    display_name=$(jq -r --arg k "$app_key" '.[$k].displayName' "$APPS_JSON")
    tagline=$(jq -r --arg k "$app_key" '.[$k].forumTagline // empty' "$APPS_JSON")
    if [[ -z "$tagline" || "$tagline" == "null" ]]; then
      tagline=$(jq -r --arg k "$app_key" '.[$k].summary' "$APPS_JSON" | sed 's/\..*$//')
    fi
    lines+=("📱 ${display_name} — ${tagline}")
  done
  printf '%s\n' "${lines[@]}"
}

post_welcome() {
  local template catalog message
  if ! command -v envsubst >/dev/null 2>&1; then
    echo "envsubst is required for welcome mode" >&2
    exit 1
  fi
  template=$(cat "$WELCOME_FILE")
  catalog=$(build_apps_catalog_block)
  export APPS_CATALOG_BLOCK="$catalog"
  message=$(envsubst '$APPS_CATALOG_BLOCK' < "$WELCOME_FILE")
  message=$(printf '%s' "$message" | sed -e '${/^$/d;}')
  send_message "$message" "$GENERAL_TOPIC_ID"
  echo "Bienvenida marketing publicada en General"
}

post_intros() {
  local skip_welcome="${1:-false}"

  if [[ "$skip_welcome" != "true" ]]; then
    post_welcome
    sleep 1
  fi

  for app_key in "${APP_ORDER[@]}"; do
    local display_name hashtag summary audience platforms web_url download_url repo_url access_block repo_block features_block stack_block thread_id intro_message
    thread_id=$(jq -r --arg k "$app_key" '.[$k].forumTopicId // empty' "$APPS_JSON")

    if [[ -z "$thread_id" || "$thread_id" == "null" ]]; then
      echo "Omitido ${app_key} (sin forumTopicId)"
      continue
    fi

    display_name=$(jq -r --arg k "$app_key" '.[$k].displayName' "$APPS_JSON")
    hashtag=$(jq -r --arg k "$app_key" '.[$k].hashtag' "$APPS_JSON")
    summary=$(jq -r --arg k "$app_key" '.[$k].summary' "$APPS_JSON")
    audience=$(jq -r --arg k "$app_key" '.[$k].audience // .[$k].summary' "$APPS_JSON")
    platforms=$(jq -r --arg k "$app_key" '.[$k].platforms // "Web"' "$APPS_JSON")
    web_url=$(jq -r --arg k "$app_key" '.[$k].webUrl' "$APPS_JSON")
    download_url=$(jq -r --arg k "$app_key" '.[$k].downloadUrl' "$APPS_JSON")
    repo_url=$(jq -r --arg k "$app_key" '.[$k].repoUrl' "$APPS_JSON")

    access_block=$(build_access_block "$web_url" "$download_url")
    repo_block=""
    if [[ -n "$repo_url" && "$repo_url" != "null" ]]; then
      repo_block="🔗 Código: ${repo_url}"
    fi
    features_block=$(build_features_block "$app_key")
    stack_block=$(build_stack_block "$app_key")

    export DISPLAY_NAME="$display_name"
    export HASHTAG="$hashtag"
    export SUMMARY="$summary"
    export AUDIENCE="$audience"
    export FEATURES_BLOCK="$features_block"
    export PLATFORMS="$platforms"
    export STACK_BLOCK="$stack_block"
    export ACCESS_BLOCK="$access_block"
    export REPO_BLOCK="$repo_block"

    if ! command -v envsubst >/dev/null 2>&1; then
      echo "envsubst is required for post mode" >&2
      exit 1
    fi

    intro_message=$(envsubst '$DISPLAY_NAME $HASHTAG $SUMMARY $AUDIENCE $FEATURES_BLOCK $PLATFORMS $STACK_BLOCK $ACCESS_BLOCK $REPO_BLOCK' < "$INTRO_FILE")
    intro_message=$(printf '%s' "$intro_message" | sed -e '${/^$/d;}')
    send_message "$intro_message" "$thread_id"
    echo "Intro publicada: ${app_key} (thread ${thread_id})"
    sleep 1
  done
}

case "$MODE" in
  topics)
    create_topics
    ;;
  post)
    post_intros false
    ;;
  apps)
    post_intros true
    ;;
  welcome)
    post_welcome
    ;;
  setup)
    create_topics
    post_intros false
    ;;
  *)
    echo "Unknown MODE: ${MODE} (use setup | topics | post | apps | welcome)" >&2
    exit 1
    ;;
esac

echo "PalmApps forum setup complete (${FORUM_CHAT_ID})"
