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

Un **solo mensaje** por topic (editable, sin duplicar). Datos en `templates/history/{app}.json`. IDs en `data/forum-message-ids.json`.

```powershell
.\scripts\post-forum-history.ps1              # sync: edita si hay ID, si no publica
$env:MODE='edit'; .\scripts\post-forum-history.ps1   # solo editar
$env:APP='costify'; .\scripts\post-forum-history.ps1
```

Si ya tienes el mensaje correcto en Telegram y solo quieres enlazarlo para futuras ediciones:

```powershell
$env:APP='costify'; $env:MESSAGE_ID=123; .\scripts\set-forum-message-id.ps1
```

Tras la primera publicacion consolidada, **borra** los mensajes viejos rotos en el topic y **ancla** el nuevo.

### Textos promocionales (redes sociales)

Genera copys desde `apps.json` (prioridad: Costify, Reservas, Carta Restaurante):

```powershell
.\scripts\generate-promo.ps1
# output/promos/costify-instagram.txt, costify-facebook-page.txt, ...
$env:APP='reservas'; .\scripts\generate-promo.ps1
$env:ALL='true'; .\scripts\generate-promo.ps1   # todas las apps
```

Plantillas: `templates/social-promo-*.txt` (instagram, whatsapp, x, generic, facebook-page).

### Imagenes promocionales (feed + story)

Genera PNG elegantes para **Facebook Page**, **Instagram feed** y **Stories / WhatsApp Status**:

```powershell
.\scripts\generate-promo-images.ps1
$env:APP='costify'; .\scripts\generate-promo-images.ps1
$env:APP='costify'; $env:VERSION='1.0.21'; .\scripts\generate-promo-images.ps1
$env:ALL='true'; .\scripts\generate-promo-images.ps1
```

Salida en `output/promos/images/`:

| Archivo | Uso |
|---------|-----|
| `{app}-feed.png` | Facebook Page, Instagram feed (1080×1080) |
| `{app}-story.png` | Instagram Stories, WhatsApp Status (1080×1920) |

Requisitos: Node.js LTS. La primera ejecución instala Playwright + Chromium.

Colores por app: `templates/promo-themes.json`. Logo: `assets/palmapps-logo-transparent.png`.

Flujo recomendado tras un release:

1. CI publica en Telegram (`@palmapps`).
2. `.\scripts\generate-promo.ps1` + `.\scripts\generate-promo-images.ps1`
3. Publicas en tu **Página de Facebook** (imagen feed + texto `*-facebook-page.txt`).
4. Subes `*-story.png` a Instagram / WhatsApp Status.

### Facebook Page (profesional)

Tu **perfil personal** no admite API; crea una **Página de Facebook** (gratis, sin empresa):

1. Facebook → **Crear** → **Página** → nombre tipo *PalmApps* o *Tus apps*.
2. Categoría: *Desarrollador de software* o *Empresa de tecnología*.
3. Añade foto de perfil (`assets/palmapps-logo-full.png`) y portada (puedes usar un `*-feed.png`).
4. En **Información** pon el enlace `https://t.me/palmapps`.
5. (Opcional) Vincula **Instagram Creator** a la Página para publicar Stories vía API más adelante.

Automatización futura (cuando tengas la Página): token de Meta + post con imagen desde CI. El timeline personal sigue siendo manual si quieres compartir ahí.

### Facebook Page — publicacion automatica (CI)

Pagina PalmApps: [facebook.com/profile.php?id=61592597813147](https://www.facebook.com/profile.php?id=61592597813147)

#### 1. Token de Meta (una vez)

1. Entra en [Meta for Developers](https://developers.facebook.com/) → **Mis apps** → **Crear app** → tipo **Otro** → **Negocio**.
2. Nombre ej. `PalmApps Notify`. Anade el producto **Facebook Login** (o usa **Herramientas** → **Explorador de la API Graph**).
3. En [Explorador de la API Graph](https://developers.facebook.com/tools/explorer/), selecciona tu app y genera un **token de usuario** con permisos:
   - `pages_manage_posts`
   - `pages_read_engagement`
   - `pages_show_list`
4. Con ese token, llama (en el explorador o con curl):

   ```
   GET /me/accounts
   ```

5. En la respuesta, busca la pagina **PalmApps** y copia:
   - `id` → secret `META_PAGE_ID` (ej. `61592597813147`)
   - `access_token` → secret `META_PAGE_ACCESS_TOKEN`

6. **Secrets en GitHub** (org `PalmApps` o en cada repo CI):

   | Secret | Valor |
   |--------|--------|
   | `META_PAGE_ID` | `61592597813147` |
   | `META_PAGE_ACCESS_TOKEN` | token de la pagina del paso 5 |

**Token largo:** intercambia el token de usuario por uno de larga duracion antes de `/me/accounts` (menu del Explorador → *Obtener token de acceso de larga duracion*), o usa un **System User** en Business Manager para produccion.

**Prueba manual** (PowerShell, sin commitear el token):

```powershell
$token = "..."   # META_PAGE_ACCESS_TOKEN
$pageId = "61592597813147"
$env:ACTION_PATH = "D:\Devops\Repos\palmapps-notify"
$env:META_PAGE_ID = $pageId
$env:META_PAGE_ACCESS_TOKEN = $token
$env:APP = "costify"
$env:VERSION = "1.0.21"
$env:CHANGELOG = "Prueba de publicacion automatica"
bash scripts/publish-facebook.sh
```

#### 2. Activar en el workflow del repo (ej. Costify)

Tras publicar tag **`v3`** en `palmapps-notify`:

```yaml
- name: Notify PalmApps Telegram + Facebook
  uses: PalmApps/palmapps-notify@v3
  with:
    telegram_bot_token: ${{ secrets.TELEGRAM_BOT_TOKEN }}
    telegram_forum_chat_id: ${{ secrets.TELEGRAM_FORUM_CHAT_ID }}
    notify_facebook: true
    meta_page_id: ${{ secrets.META_PAGE_ID }}
    meta_page_access_token: ${{ secrets.META_PAGE_ACCESS_TOKEN }}
    app: costify
    version: ${{ steps.meta.outputs.version }}
    template: android-release
    release_page_url: https://github.com/PalmApps/Costify/releases/tag/${{ steps.meta.outputs.tag }}
    changelog: |
      Mejora 1
      Mejora 2
```

Cada release publica en **Telegram** (foro) y en la **Pagina de Facebook** (texto + enlace de vista previa a la web o al foro).

Plantilla del post FB: `templates/facebook-page-release.txt`.

**Imagen en el post:** por ahora el CI publica texto + link. Para subir el PNG promo (`*-feed.png`), genera la imagen en un step previo y pasa `FACEBOOK_IMAGE_PATH` (soporte en `publish-facebook.sh`); Stories/IG siguen manuales o en una fase 2.

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
| `templates/social-promo-*.txt` | Promo para Instagram, WhatsApp, X, Facebook Page, genérico |
| `templates/promo-themes.json` | Colores por app para imágenes promo |
| `templates/facebook-page-release.txt` | Post automatico en Facebook Page (CI) |
| `scripts/publish-facebook.sh` | Publicar en Facebook via Graph API |

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
