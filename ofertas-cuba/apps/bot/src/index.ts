import { Bot } from "grammy";
import { PROVINCES } from "@ofertas-cuba/shared";

const token = process.env.TELEGRAM_OFERTAS_BOT_TOKEN;

if (!token) {
  console.error("TELEGRAM_OFERTAS_BOT_TOKEN is required");
  process.exit(1);
}

const bot = new Bot(token);
const appUrl =
  process.env.NEXT_PUBLIC_APP_URL ?? "https://ofertascuba.vercel.app";

bot.command("start", async (ctx) => {
  await ctx.reply(
    [
      "OfertasCuba — compara ofertas de compra y venta en Cuba.",
      "",
      "Comandos (fase 1):",
      "/buscar <producto> — buscar en tu provincia",
      "/alerta <producto> — aviso cuando aparezca",
      "/provincia <nombre> — cambiar provincia",
      "/misalertas — ver alertas",
      "",
      `Web: ${appUrl}`,
      "",
      "Reenvia un post o captura de oferta para ayudar a la comunidad.",
    ].join("\n"),
  );
});

bot.command("provincia", async (ctx) => {
  const query = ctx.match?.trim().toLowerCase();
  if (!query) {
    const list = PROVINCES.map((p) => p.name).join(", ");
    await ctx.reply(`Provincias: ${list}`);
    return;
  }
  const match = PROVINCES.find(
    (p) =>
      p.name.toLowerCase().includes(query) || p.slug.includes(query),
  );
  if (!match) {
    await ctx.reply("Provincia no encontrada. Prueba con otro nombre.");
    return;
  }
  // TODO fase 1: persistir en Neon (telegram_users)
  await ctx.reply(`Provincia guardada: ${match.name} (persistencia pendiente).`);
});

bot.command("buscar", async (ctx) => {
  const query = ctx.match?.trim();
  if (!query) {
    await ctx.reply("Uso: /buscar iphone 13");
    return;
  }
  await ctx.reply(
    `Busqueda "${query}" — indice en construccion (fase 1).\n${appUrl}`,
  );
});

bot.command("alerta", async (ctx) => {
  const query = ctx.match?.trim();
  if (!query) {
    await ctx.reply("Uso: /alerta arroz");
    return;
  }
  await ctx.reply(`Alerta "${query}" registrada (persistencia pendiente).`);
});

bot.command("misalertas", async (ctx) => {
  await ctx.reply("No tienes alertas activas (fase 1).");
});

bot.on("message", async (ctx) => {
  if (!ctx.message.forward_origin && !ctx.message.photo) return;
  await ctx.reply(
    "Gracias. Reenvio recibido — indexacion en fase 1 (parser + Neon).",
  );
});

bot.catch((err) => {
  console.error("Bot error:", err);
});

if (process.env.NODE_ENV !== "production") {
  bot.start();
  console.log("OfertasCuba bot polling (dev)");
} else {
  console.log("Production: configure webhook on Vercel (fase 1).");
}
