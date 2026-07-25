# Setup — Fase 0

Checklist manual antes de Fase 1.

## 1. GitHub repo

El monorepo vive en `ofertas-cuba/` (bootstrap en palmapps-notify hasta separar).

- [ ] Crear repo privado `PalmApps/ofertas-cuba` en GitHub (manual)
- [ ] Copiar carpeta: `git subtree split` o push del subdirectorio
- [ ] Branch protection en `main` (opcional)

## 2. Secrets (org PalmApps → Settings → Secrets)

| Secret | Descripcion |
|--------|-------------|
| `DATABASE_URL` | Connection string Neon |
| `EL_TOQUE_API_KEY` | Reutilizar de Costify si aplica |
| `TELEGRAM_OFERTAS_BOT_TOKEN` | **Nuevo** bot en @BotFather |
| `TELEGRAM_API_ID` | my.telegram.org |
| `TELEGRAM_API_HASH` | my.telegram.org |
| `TELEGRAM_USER_SESSION` | Generar con `pnpm --filter @ofertas-cuba/scraper auth:telegram` |

**No reutilizar** `TELEGRAM_BOT_TOKEN` (ese es Notify/foro).

## 3. BotFather

1. Bot creado: **Ofertas Cuba** → `@Ofertas_Cuba_bot`
2. Guardar token en `TELEGRAM_OFERTAS_BOT_TOKEN` (org secrets; no en el repo)
3. Actualizar `NEXT_PUBLIC_TELEGRAM_BOT_USERNAME` en Vercel

## 4. Neon

1. Crear proyecto `ofertas-cuba`
2. Copiar `DATABASE_URL` a secrets repo + Vercel
3. Schema: ver `docs/schema.sql` (fase 1)

## 5. Vercel

1. Importar repo `ofertas-cuba`
2. Root directory: `apps/web`
3. Variables: `DATABASE_URL`, `EL_TOQUE_API_KEY`, `NEXT_PUBLIC_APP_URL`
4. Dominio: `ofertascuba.vercel.app`

## 6. Telegram session (scraper)

```bash
cd ofertas-cuba
cp .env.example .env
# Rellenar TELEGRAM_API_ID y TELEGRAM_API_HASH
pnpm install
pnpm --filter @ofertas-cuba/scraper auth:telegram
```

Usar numero dedicado (no personal). Guardar session string en GitHub Secret.

## 7. PalmApps foro

Desde `palmapps-notify` (con token admin):

```powershell
$env:TELEGRAM_BOT_TOKEN = "..."  # Notify bot
$env:TELEGRAM_FORUM_CHAT_ID = "@palmapps"
.\scripts\setup-forum.ps1 -Mode topics
.\scripts\setup-forum.ps1 -Mode apps
```

Esto crea topic **OfertasCuba** y actualiza `forumTopicId` en `apps.json`.

## 8. Seeds

Editar `docs/seeds/` con grupos/canales reales:

- `facebook-groups.json`
- `telegram-channels.json`
- `discovery-keywords.json`

## 9. CI novedades (fase 1)

En `.github/workflows/deploy.yml` del repo ofertas-cuba:

```yaml
- uses: PalmApps/palmapps-notify@v2
  with:
    telegram_bot_token: ${{ secrets.TELEGRAM_BOT_TOKEN }}
    telegram_forum_chat_id: ${{ secrets.TELEGRAM_FORUM_CHAT_ID }}
    app: ofertas-cuba
    version: ${{ github.sha }}
    template: web-deploy
```

Usa **Notify** token para publicar en foro, no el bot de producto.
