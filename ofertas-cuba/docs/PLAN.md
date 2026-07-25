# OfertasCuba — Plan v1.2 (Fase 0)

Comparador comunitario PalmApps para compra/venta en Cuba.

## Vision

Indexar ofertas de grupos publicos de **Facebook** y **Telegram**, normalizar precios (USD/EUR via El Toque), filtrar por provincia y conectar al post o WhatsApp del vendedor.

## Decisiones clave

| Area | Decision |
|------|----------|
| Usuario | Comprador primero; vendedores fase 3 |
| Cobertura | Toda Cuba; provincia en localStorage |
| Fuentes | FB scrape + TG Client API + reenvios al bot |
| Producto | Web PWA + bot Telegram dedicado |
| FX | El Toque API |
| Scraper host | GitHub Actions |
| DB | Neon Postgres |
| Repo | Monorepo privado |
| Dominio MVP | ofertascuba.vercel.app |
| Bot | Nuevo (NO PalmAppsNotify) |

## Arquitectura

```
apps/web       → Next.js 15 PWA (Vercel)
apps/bot       → Grammy (webhook Vercel en prod)
apps/scraper   → FB + Telegram (GH Actions cron)
packages/shared→ provincias, blacklist, parser precio
```

## Fases

### Fase 0 (actual)

- Monorepo, docs, seeds, workflows stub
- Entrada en palmapps-notify `apps.json`
- Secrets y servicios externos pendientes de configurar manual

### Fase 1 (MVP)

- Neon schema + persistencia
- Scraper Telegram operativo (prioridad)
- Scraper Facebook basico
- Web: busqueda, listado, reportar
- Bot: busqueda, alertas, reenvio indexado
- Beta en foro PalmApps

### Fase 2

- Escala 50-100 fuentes, historial precios, confianza

### Fase 3

- Destacar ofertas → analytics vendedor → publicacion directa

## Metricas MVP

1. >= 500 ofertas activas en >= 5 provincias
2. >= 100 alertas Telegram activas
3. 20 feedbacks en topic foro

## Bots Telegram

| Bot | Uso |
|-----|-----|
| `@PalmAppsNotify_bot` | CI → foro PalmApps |
| `@Ofertas_Cuba_bot` | Producto: buscar, alertas, reenvios |

Ver `docs/SETUP.md` para checklist de secrets y servicios.
