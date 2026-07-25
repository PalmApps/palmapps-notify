import { TelegramClient } from "telegram";
import { StringSession } from "telegram/sessions/index.js";
import { loadJson, parseOfferText, persistOffers } from "../lib.js";

interface TelegramChannelSeed {
  username: string;
  name: string;
  provinceId: string | null;
  type: "channel" | "group";
}

/**
 * Fase 0: valida credenciales si existen.
 * Fase 1: lee mensajes recientes de canales/grupos publicos.
 */
export async function runTelegramScraper(): Promise<void> {
  const channels = loadJson<TelegramChannelSeed[]>("telegram-channels.json");
  console.log(`Telegram scraper — ${channels.length} fuentes semilla`);

  const apiId = Number(process.env.TELEGRAM_API_ID);
  const apiHash = process.env.TELEGRAM_API_HASH;
  const session = process.env.TELEGRAM_USER_SESSION;

  if (!apiId || !apiHash || !session) {
    console.warn(
      "TELEGRAM_API_ID / TELEGRAM_API_HASH / TELEGRAM_USER_SESSION no configurados — dry-run",
    );
    const parsed = parseOfferText(
      "Laptop Lenovo 350 USD, entrega Camaguey, t.me/vendedor",
      {
        sourcePlatform: "telegram",
        sourceUrl: "https://t.me/example",
        externalGroupId: channels[0]?.username ?? null,
      },
    );
    await persistOffers(parsed ? [parsed] : []);
    return;
  }

  const client = new TelegramClient(
    new StringSession(session),
    apiId,
    apiHash,
    { connectionRetries: 3 },
  );

  await client.connect();
  console.log("Telegram client connected.");

  for (const channel of channels.slice(0, 5)) {
    try {
      const entity = await client.getEntity(channel.username);
      console.log(`OK: ${channel.name} (${entity.className})`);
      // TODO fase 1: client.getMessages(entity, { limit: 50 })
    } catch (err) {
      console.warn(`Skip ${channel.username}:`, err);
    }
  }

  await client.disconnect();
  console.log("Telegram scrape run complete (stub).");
}

runTelegramScraper().catch((err) => {
  console.error(err);
  process.exit(1);
});
