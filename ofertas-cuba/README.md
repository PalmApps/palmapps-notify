# OfertasCuba

Comparador comunitario de compra y venta en Cuba — proyecto [PalmApps](https://t.me/palmapps).

Indexa ofertas de grupos publicos de **Facebook** y **Telegram**, muestra precios con referencia **USD/EUR** (El Toque) y filtra por **provincia**.

- Web (MVP): https://ofertascuba.vercel.app
- Foro novedades: https://t.me/palmapps
- Bot producto: `@Ofertas_Cuba_bot`

## Monorepo

```
apps/web       → Next.js 15 PWA
apps/bot       → Telegram (busqueda, alertas, reenvios)
apps/scraper   → Facebook + Telegram (GitHub Actions)
packages/shared→ provincias, blacklist, parser
```

## Desarrollo local

```bash
pnpm install
pnpm dev          # web en :3000
pnpm dev:bot      # bot polling (requiere TELEGRAM_OFERTAS_BOT_TOKEN)
pnpm scrape:telegram
pnpm scrape:facebook
```

Copiar `.env.example` → `.env` en la raiz.

## Documentacion

- [Plan](docs/PLAN.md)
- [Setup Fase 0](docs/SETUP.md)
- [Schema DB](docs/schema.sql) (fase 1)
- [Seeds](docs/seeds/)

## Estado

**Fase 0** — estructura, seeds, workflows stub. Sin DB ni scrapers productivos aun.

## Licencia

Privado — PalmApps.
