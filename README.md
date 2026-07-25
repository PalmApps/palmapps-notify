# palmapps-notify

GitHub Action reutilizable para publicar **releases y deploys** en el foro Telegram [PalmApps](https://t.me/palmapps) (un topic por app).

Centraliza plantillas, catálogo de apps y envío a Telegram. Cada repo solo invoca la action con `app`, `version` y `changelog`.

## Arquitectura Telegram

| Destino | Username | Rol |
|---------|----------|-----|
| **Foro (principal)** | [@palmapps](https://t.me/palmapps) | Hub de releases con topics por app |
| Canal legacy (opcional) | [@palmappschannel](https://t.me/palmappschannel) | Broadcast duplicado; ya no hace falta si usas solo el foro |

**Recomendación:** deja de publicar releases en el canal. Pon un mensaje anclado en `@palmappschannel` con enlace a `@palmapps` y archívalo o bórralo cuando nadie lo use. En redes promociona solo `t.me/palmapps`.

## Requisitos

1. Foro `@palmapps` con el bot como admin (**Publicar mensajes** + **Gestionar topics**).
2. Topics creados (`.\scripts\setup-forum.ps1`) → `forumTopicId` en `templates/apps.json`.
3. Secrets en la org o repo CI:

| Secret | Valor |
|--------|--------|
| `TELEGRAM_BOT_TOKEN` | Token de @BotFather |
| `TELEGRAM_FORUM_CHAT_ID` | `@palmapps` |
| `TELEGRAM_CHANNEL_ID` | `@palmappschannel` (solo si `notify_channel: true`) |

## Uso — Android APK (Costify)

Recomendado (`@v2`, solo foro):

```yaml
- name: Notify PalmApps Telegram
  uses: PalmApps/palmapps-notify@v2
  with:
    telegram_bot_token: ${{ secrets.TELEGRAM_BOT_TOKEN }}
    telegram_forum_chat_id: ${{ secrets.TELEGRAM_FORUM_CHAT_ID }}
    app: costify
    version: ${{ steps.meta.outputs.version }}
    template: android-release
    release_page_url: https://github.com/PalmApps/Costify/releases/tag/v${{ steps.meta.outputs.version }}
    changelog: |
      Inicio con KPIs y alertas
      Brand v3 y navegación reagrupada
    extra_lines: |
      API: https://costify-iota.vercel.app
      Arquitectura: arm64-v8a
    commit: ${{ github.sha }}
```

Duplicar también al canal legacy:

```yaml
    telegram_channel_id: ${{ secrets.TELEGRAM_CHANNEL_ID }}
    notify_channel: true
```

Legacy solo canal (`@v1`, sin foro):

```yaml
- name: Notify PalmApps Telegram
  uses: PalmApps/palmapps-notify@v1
  with:
    telegram_bot_token: ${{ secrets.TELEGRAM_BOT_TOKEN }}
    telegram_channel_id: ${{ secrets.TELEGRAM_CHANNEL_ID }}
    app: costify
    ...
```

`download_url` y `web_url` se rellenan desde `templates/apps.json` si no los pasas.

## Uso — solo web (Vercel production)

```yaml
- name: Notify PalmApps Telegram
  uses: PalmApps/palmapps-notify@v2
  with:
    telegram_bot_token: ${{ secrets.TELEGRAM_BOT_TOKEN }}
    telegram_forum_chat_id: ${{ secrets.TELEGRAM_FORUM_CHAT_ID }}
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
| `viajando` | Viajando | https://viajando-nine.vercel.app |
| `carta-restaurante` | Carta Restaurante | (LAN / sin URL pública) |
| `rensoli-commerce` | Rendesigns | https://rensoli-commerce.vercel.app |

Edita `templates/apps.json` para URLs, resúmenes (`summary`), audiencia (`audience`), funciones (`features`), stack (`platforms`, `stack`), `forumTopicId` y apps nuevas.

Plantilla de ficha detallada por topic: `templates/forum-app-detail.txt`. Republicar:

```powershell
$env:MODE='post'; .\scripts\setup-forum.ps1
```

## Setup del foro (@palmapps)

### 1. Permiso del bot (manual en Telegram)

En `@palmapps` → **Administradores** → `@PalmAppsNotify_bot` → activar **Gestionar topics** (*Manage Topics*).

### 2. Crear topics + intros

```powershell
cd D:\Devops\Repos\palmapps-notify
.\scripts\setup-forum.ps1
```

Linux / Git Bash:

```bash
export TELEGRAM_BOT_TOKEN=...
export TELEGRAM_FORUM_CHAT_ID=@palmapps
export ACTION_PATH="$(pwd)"
bash scripts/setup-forum.sh
```

Modos: `MODE=topics` (solo crear topics), `MODE=post` (solo publicar bienvenida + fichas), `MODE=apps` (solo fichas), `MODE=welcome` (solo General).

### Historial de novedades por topic

Edita `templates/history/{app}.json` y publica:

```powershell
.\scripts\post-forum-history.ps1          # todas las apps
$env:APP='costify'; .\scripts\post-forum-history.ps1   # una app
```

### Textos promocionales (redes sociales)

Genera copys desde `apps.json` (prioridad: Costify, Reservas, Carta Restaurante):

```powershell
.\scripts\generate-promo.ps1
# output/promos/costify-instagram.txt, costify-whatsapp.txt, ...
$env:APP='reservas'; .\scripts\generate-promo.ps1
$env:ALL='true'; .\scripts\generate-promo.ps1   # todas las apps
```

Plantillas: `templates/social-promo-*.txt` (instagram, whatsapp, x, generic).

### 3. CI

Secret org `TELEGRAM_FORUM_CHAT_ID=@palmapps`. Publica tag **`v2`** tras push (`git tag v2 && git push origin v2`).

## Canal legacy (@palmappschannel)

Scripts antiguos de intro del canal (si aún lo usas para redirigir):

```powershell
$env:TELEGRAM_CHANNEL_ID='@palmappschannel'
.\scripts\post-channel-intros.ps1
```

## Plantillas

| Archivo | Uso |
|---------|-----|
| `templates/android-release.txt` | APK + web |
| `templates/web-deploy.txt` | Deploy web sin APK |
| `templates/forum-welcome.txt` | Bienvenida al topic General |
| `templates/forum-app-detail.txt` | Ficha detallada por app (foro) |
| `templates/channel-app-intro.txt` | Ficha breve (canal legacy) |
| `templates/forum-history-entry.txt` | Entrada del historial en un topic |
| `templates/history/*.json` | Historial de novedades por app |
| `templates/social-promo-*.txt` | Promo para Instagram, WhatsApp, X, genérico |

Variables en plantillas de release: `$DISPLAY_NAME`, `$VERSION`, `$HASHTAG`, `$CHANGELOG`, `$DOWNLOAD_BLOCK`, `$WEB_URL`, `$EXTRA_BLOCK`.

## Publicar la action

```bash
git tag v2   # foro @palmapps (recomendado)
git push origin main
git push origin v2
```

## Desarrollo local

```bash
export TELEGRAM_BOT_TOKEN=...
export TELEGRAM_FORUM_CHAT_ID=@palmapps
export APP=costify
export VERSION=1.0.18
export TEMPLATE=android-release
export CHANGELOG=$'Inicio con KPIs\nBrand v3'
export ACTION_PATH="$(pwd)"
bash scripts/notify.sh
```

## Licencia

MIT
