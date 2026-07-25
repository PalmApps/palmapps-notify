# AGENTS.md — palmapps-notify / PalmApps

Documento de contexto para agentes de IA. **Confidencial:** no incluir tokens; usar GitHub Secrets.

## Qué es PalmApps

Hub de **releases oficiales** para las apps del ecosistema (Costify, Reservas, Viajando, Carta Restaurante, Rendesigns).

- Foro Telegram (principal): https://t.me/palmapps (`@palmapps`, topics por app)
- Canal legacy: https://t.me/palmappschannel (`@palmappschannel`, opcional)
- Bot: `@PalmAppsNotify_bot`
- Redes sociales: promos con CTA al canal Telegram (no changelogs largos)

## Este repositorio

`palmapps-notify` = GitHub Action reutilizable + plantillas + catálogo de apps.

| Recurso | Ubicación |
|---------|-----------|
| Action definition | `action.yml` |
| Send script | `scripts/notify.sh` |
| Forum setup | `scripts/setup-forum.ps1`, `scripts/setup-forum.sh` |
| App catalog | `templates/apps.json` |
| APK template | `templates/android-release.txt` |
| Web template | `templates/web-deploy.txt` |
| Ejemplo workflow | `.github/workflows/example-web-notify.yml` |
| Contexto Cursor | `.cursor/rules/palmapps-context.mdc` |

**Consumo:** `uses: PalmApps/palmapps-notify@v2` (foro `@palmapps`). `@v1` = solo canal legacy.

## Secrets (org PalmApps)

- `TELEGRAM_BOT_TOKEN`
- `TELEGRAM_FORUM_CHAT_ID` → `@palmapps` (principal)
- `TELEGRAM_CHANNEL_ID` → `@palmappschannel` (opcional, solo con `notify_channel: true`)

## Apps del ecosistema

| Key | Repo local | Producción |
|-----|------------|------------|
| `costify` | `D:\Devops\Repos\Costify` | https://costify-iota.vercel.app |
| `reservas` | `D:\Devops\Repos\reservas` | https://reservas-taupe.vercel.app |
| `viajando` | `D:\Devops\Repos\viajando` | (Vercel) |
| `carta-restaurante` | `D:\Devops\Repos\carta-restaurante` | (Vercel) |
| `rensoli-commerce` | `D:\Devops\Repos\rensoli-commerce` | https://rensoli-commerce.vercel.app (Rendesigns) |

Costify APK releases: tag `v*.*.*` → workflow `Costify/.github/workflows/android-release.yml` (incluye step Telegram si está pusheado).

## Desarrollo local

```bash
export TELEGRAM_BOT_TOKEN=...   # no commitear
export TELEGRAM_FORUM_CHAT_ID=@palmapps
export APP=costify
export VERSION=1.0.18
export TEMPLATE=android-release
export CHANGELOG=$'cambio 1\ncambio 2'
export ACTION_PATH="$(pwd)"
bash scripts/notify.sh
```

## Pendientes típicos

1. Repo publicado en `github.com/PalmApps/palmapps-notify` + tag `v1`
2. Organization secrets Telegram en `PalmApps` (`visibility: all`)
3. Commit + push workflow Costify con `PalmApps/palmapps-notify@v1`
4. Completar URLs en `apps.json` para viajando y carta-restaurante
5. Foro: permiso **Manage Topics** al bot → `.\scripts\setup-forum.ps1` → tag `v2` + `telegram_forum_chat_id` en workflows
6. Añadir notify a deploy production Vercel (Reservas, etc.) con `template: web-deploy`

## Referencia rápida Telegram API

- Verificar bot: `GET https://api.telegram.org/bot<TOKEN>/getMe`
- Publicar foro: `sendMessage` con `chat_id=@palmapps` + `message_thread_id` (`forumTopicId` en apps.json)
- Canal legacy: `@palmappschannel` (deprecado para releases)
- 404 en API → URL/token mal formado (probar `getMe` primero)

Ver también `README.md` para ejemplos YAML completos.
