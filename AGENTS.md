# AGENTS.md — palmapps-notify / PalmApps

Documento de contexto para agentes de IA. **Confidencial:** no incluir tokens; usar GitHub Secrets.

**Reglas Cursor (leer antes de editar):**

| Rule | Contenido |
|------|-----------|
| `.cursor/rules/palmapps-context.mdc` | Foro, org, apps, scripts, CI v2 |
| `.cursor/rules/utf8-telegram.mdc` | UTF-8 obligatorio; no strings con tildes/emojis en .ps1 |
| `.cursor/rules/palmapps-copy.mdc` | Tono público; novedades vs releases; marketing |

## Qué es PalmApps

Hub de **novedades oficiales** del ecosistema (Costify, Reservas, Viajando, Carta Restaurante, Rendesigns, OfertasCuba).

- Foro (principal): https://t.me/palmapps (`@palmapps`)
- Canal legacy: https://t.me/palmappschannel (solo redirección)
- Bot: `@PalmAppsNotify_bot`
- Redes: promo corta + `t.me/palmapps`

## Este repositorio

`palmapps-notify` = GitHub Action + plantillas + catálogo + scripts de foro y promo.

| Recurso | Ubicación |
|---------|-----------|
| Action | `action.yml` — `@v2` foro, `@v1` canal legacy |
| Notify CI | `scripts/notify.sh` |
| Foro setup | `scripts/setup-forum.ps1` |
| Historial topics | `scripts/post-forum-history.ps1`, `templates/history/*.json` |
| Promos redes | `scripts/generate-promo.ps1`, `templates/social-promo-*.txt` |
| Catálogo | `templates/apps.json` |

## Secrets (org PalmApps)

- `TELEGRAM_BOT_TOKEN`
- `TELEGRAM_FORUM_CHAT_ID` → `@palmapps`
- `TELEGRAM_CHANNEL_ID` → `@palmappschannel` (opcional)

## UTF-8 (crítico en Windows)

- Textos al usuario → `templates/*.txt` UTF-8, no inline en `.ps1`
- Telegram API → JSON UTF-8 + `Content-Type: application/json; charset=utf-8`
- Ver `.cursor/rules/utf8-telegram.mdc`

## Apps

| Key | Público | Web |
|-----|---------|-----|
| `costify` | Costify | https://costify-iota.vercel.app |
| `reservas` | Reservas | https://reservas-taupe.vercel.app |
| `viajando` | Viajando | https://viajando-nine.vercel.app |
| `carta-restaurante` | Carta Restaurante | LAN |
| `rensoli-commerce` | **Rendesigns** | https://rensoli-commerce.vercel.app |
| `ofertas-cuba` | **OfertasCuba** | https://ofertascuba.vercel.app |

Promo prioritaria: costify, reservas, carta-restaurante.

Ver `README.md` y `.cursor/rules/palmapps-context.mdc` para detalle completo.
