#!/usr/bin/env bash
set -euo pipefail

ACTION_PATH="${ACTION_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"
APPS_JSON="$ACTION_PATH/templates/apps.json"
OUTPUT_DIR="$ACTION_PATH/output/promos"
FORUM_LINK="${FORUM_LINK:-https://t.me/palmapps}"
APP_ORDER=(costify reservas viajando carta-restaurante rensoli-commerce)

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi
if ! command -v envsubst >/dev/null 2>&1; then
  echo "envsubst is required" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

build_access_line() {
  local app_key="$1"
  local web download lines=()
  web=$(jq -r --arg k "$app_key" '.[$k].webUrl // empty' "$APPS_JSON")
  download=$(jq -r --arg k "$app_key" '.[$k].downloadUrl // empty' "$APPS_JSON")
  if [[ -n "$web" && "$web" != "null" ]]; then lines+=("Web: ${web}"); fi
  if [[ -n "$download" && "$download" != "null" ]]; then lines+=("APK: ${download}"); fi
  if [[ ${#lines[@]} -eq 0 ]]; then
    echo "Disponible en red local del negocio (consulta el topic del foro)"
    return
  fi
  printf '%s\n' "${lines[@]}"
}

render_promo() {
  local app_key="$1"
  local channel="$2"
  local template_path="$ACTION_PATH/templates/social-promo-${channel}.txt"
  local display_name hashtag promo_hook access_line
  display_name=$(jq -r --arg k "$app_key" '.[$k].displayName' "$APPS_JSON")
  hashtag=$(jq -r --arg k "$app_key" '.[$k].hashtag' "$APPS_JSON")
  promo_hook=$(jq -r --arg k "$app_key" '.[$k].promoHook // .[$k].summary' "$APPS_JSON" | sed 's/\..*$//')
  access_line=$(build_access_line "$app_key")
  export DISPLAY_NAME="$display_name" HASHTAG="$hashtag" PROMO_HOOK="$promo_hook"
  export ACCESS_LINE="$access_line" FORUM_LINK="$FORUM_LINK"
  export CTA_LINE="Guardalo y comparte con quien le sirva."
  envsubst '$DISPLAY_NAME $HASHTAG $PROMO_HOOK $ACCESS_LINE $FORUM_LINK $CTA_LINE' < "$template_path"
}

if [[ -n "${APP:-}" ]]; then
  targets=("$APP")
elif [[ "${ALL:-}" == "true" ]]; then
  targets=("${APP_ORDER[@]}")
else
  mapfile -t targets < <(jq -r 'to_entries[] | select(.value.promoPriority == true) | .key' "$APPS_JSON")
fi

if [[ ${#targets[@]} -eq 0 ]]; then
  echo "No hay apps objetivo. Usa APP=costify o ALL=true" >&2
  exit 1
fi

for app_key in "${targets[@]}"; do
  for channel in instagram whatsapp x generic facebook-page; do
    content=$(render_promo "$app_key" "$channel" | sed -e '${/^$/d;}')
    out_path="$OUTPUT_DIR/${app_key}-${channel}.txt"
    printf '%s\n' "$content" > "$out_path"
    echo "Generado: $out_path"
  done
done

echo "Promos en ${OUTPUT_DIR} (${#targets[@]} apps x 5 canales)"
