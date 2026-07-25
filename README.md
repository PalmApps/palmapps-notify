# palmapps-notify

GitHub Action reutilizable para publicar **releases y deploys** en el canal Telegram [PalmApps](https://t.me/palmapps).

Centraliza plantillas, catálogo de apps y envío a Telegram. Cada repo solo invoca la action con `app`, `version` y `changelog`.

## Requisitos

1. Canal Telegram `@palmapps` con el bot como administrador (permiso **Publicar mensajes**).
2. Secrets en el repo que dispara el workflow (o en la organización):

| Secret | Valor |
|--------|--------|
| `TELEGRAM_BOT_TOKEN` | Token de @BotFather |
| `TELEGRAM_CHANNEL_ID` | `@palmapps` (o ID `-100…`) |

## Uso — Android APK (Costify)

```yaml
- name: Notify PalmApps Telegram
  uses: ypvaldivia88/palmapps-notify@v1
  with:
    telegram_bot_token: ${{ secrets.TELEGRAM_BOT_TOKEN }}
    telegram_channel_id: ${{ secrets.TELEGRAM_CHANNEL_ID }}
    app: costify
    version: ${{ steps.meta.outputs.version }}
    template: android-release
    release_page_url: https://github.com/ypvaldivia88/Costify/releases/tag/v${{ steps.meta.outputs.version }}
    changelog: |
      Inicio con KPIs y alertas
      Brand v3 y navegación reagrupada
    extra_lines: |
      API: https://costify-iota.vercel.app
      Arquitectura: arm64-v8a
    commit: ${{ github.sha }}
```

`download_url` y `web_url` se rellenan desde `templates/apps.json` si no los pasas.

## Uso — solo web (Vercel production)

```yaml
- name: Notify PalmApps Telegram
  uses: ypvaldivia88/palmapps-notify@v1
  with:
    telegram_bot_token: ${{ secrets.TELEGRAM_BOT_TOKEN }}
    telegram_channel_id: ${{ secrets.TELEGRAM_CHANNEL_ID }}
    app: reservas
    version: ${{ github.sha }}
    template: web-deploy
    changelog: |
      Mejoras en el wizard de reserva
```

## Apps registradas

| `app` | Nombre | Web por defecto |
|-------|--------|-----------------|
| `costify` | Costify | https://costify-iota.vercel.app |
| `reservas` | Reservas | https://reservas-taupe.vercel.app |
| `viajando` | Viajando | (configurar en `apps.json`) |
| `carta-restaurante` | Carta Restaurante | (configurar en `apps.json`) |
| `rensoli-commerce` | Rensoli Commerce | https://rensoli-commerce.vercel.app |

Edita `templates/apps.json` para URLs y añadir apps nuevas.

## Plantillas

| Archivo | Uso |
|---------|-----|
| `templates/android-release.txt` | APK + web |
| `templates/web-deploy.txt` | Deploy web sin APK |

Variables en plantillas: `$DISPLAY_NAME`, `$VERSION`, `$HASHTAG`, `$CHANGELOG`, `$DOWNLOAD_BLOCK`, `$WEB_URL`, `$EXTRA_BLOCK`.

## Publicar la action

Tras push al repo GitHub, crea el tag para que otros repos puedan usar `@v1`:

```bash
git tag v1
git push origin main
git push origin v1
```

## Desarrollo local

```bash
export TELEGRAM_BOT_TOKEN=...
export TELEGRAM_CHANNEL_ID=@palmapps
export APP=costify
export VERSION=1.0.18
export TEMPLATE=android-release
export CHANGELOG=$'Inicio con KPIs\nBrand v3'
export ACTION_PATH="$(pwd)"
bash scripts/notify.sh
```

## Licencia

MIT
