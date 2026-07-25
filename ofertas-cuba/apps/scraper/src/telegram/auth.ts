import { createInterface } from "node:readline/promises";
import { stdin as input, stdout as output } from "node:process";
import { TelegramClient } from "telegram";
import { StringSession } from "telegram/sessions/index.js";

async function prompt(question: string): Promise<string> {
  const rl = createInterface({ input, output });
  const answer = await rl.question(question);
  rl.close();
  return answer.trim();
}

/**
 * Ejecutar localmente UNA vez para generar TELEGRAM_USER_SESSION:
 * pnpm --filter @ofertas-cuba/scraper auth:telegram
 */
async function main() {
  const apiId = Number(process.env.TELEGRAM_API_ID);
  const apiHash = process.env.TELEGRAM_API_HASH;

  if (!apiId || !apiHash) {
    throw new Error("Set TELEGRAM_API_ID and TELEGRAM_API_HASH");
  }

  const session = new StringSession("");
  const client = new TelegramClient(session, apiId, apiHash, {
    connectionRetries: 5,
  });

  await client.start({
    phoneNumber: async () => await prompt("Telefono (+53...): "),
    password: async () => await prompt("2FA password (si aplica): "),
    phoneCode: async () => await prompt("Codigo SMS/Telegram: "),
    onError: (err) => console.error(err),
  });

  console.log("\nTELEGRAM_USER_SESSION (guardar en secrets):\n");
  console.log(client.session.save());
  await client.disconnect();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
