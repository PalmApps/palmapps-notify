import { Bot, InlineKeyboard } from "grammy";
import {
  PROVINCES,
  containsBlacklistedTerm,
  extractCurrency,
  extractPhone,
  extractPrice,
  findProvinceByName,
  normalizeProductKey,
} from "@ofertas-cuba/shared";
import { loadEnv } from "./load-env";
import {
  addAlert,
  getUser,
  listAlerts,
  removeAlert,
  setUserProvince,
} from "./store";

loadEnv();

const token = process.env.TELEGRAM_OFERTAS_BOT_TOKEN;

if (!token) {
  console.error("TELEGRAM_OFERTAS_BOT_TOKEN is required");
  process.exit(1);
}

const bot = new Bot(token);
const appUrl =
  process.env.NEXT_PUBLIC_APP_URL ?? "https://ofertascuba.vercel.app";

function provinceName(provinceId: string | null): string {
  if (!provinceId) return "Toda Cuba";
  return PROVINCES.find((p) => p.id === provinceId)?.name ?? provinceId;
}

function provincePickerKeyboard(): InlineKeyboard {
  const kb = new InlineKeyboard();
  for (const p of PROVINCES) {
    kb.text(p.name, `prov:${p.id}`).row();
  }
  return kb;
}

bot.command("start", async (ctx) => {
  const user = getUser(ctx.chat.id);
  const lines = [
    "OfertasCuba — compara ofertas de compra y venta en Cuba.",
    "",
    "Comandos:",
    "/buscar <producto>",
    "/alerta <producto>",
    "/provincia <nombre>",
    "/misalertas",
    "",
    `Web: ${appUrl}`,
    "",
    "Reenvia un post o captura para ayudar a indexar ofertas.",
  ];

  if (!user.provinceId) {
    await ctx.reply(
      [...lines, "", "Elige tu provincia para empezar:"].join("\n"),
      { reply_markup: provincePickerKeyboard() },
    );
    return;
  }

  lines.splice(
    2,
    0,
    `Provincia: ${provinceName(user.provinceId)}`,
    "",
  );
  await ctx.reply(lines.join("\n"));
});

bot.callbackQuery(/^prov:(.+)$/, async (ctx) => {
  const provinceId = ctx.match[1];
  const province = PROVINCES.find((p) => p.id === provinceId);
  if (!province) {
    await ctx.answerCallbackQuery({ text: "Provincia no valida" });
    return;
  }
  setUserProvince(ctx.chat!.id, province.id);
  await ctx.answerCallbackQuery({ text: `Provincia: ${province.name}` });
  await ctx.editMessageText(
    `Listo. Provincia: ${province.name}.\n\nPrueba /buscar iphone o /alerta arroz`,
  );
});

bot.command("provincia", async (ctx) => {
  const query = ctx.match?.trim();
  if (!query) {
    await ctx.reply("Elige provincia:", {
      reply_markup: provincePickerKeyboard(),
    });
    return;
  }
  const match = findProvinceByName(query);
  if (!match) {
    await ctx.reply("Provincia no encontrada. Prueba /provincia La Habana");
    return;
  }
  setUserProvince(ctx.chat.id, match.id);
  await ctx.reply(`Provincia guardada: ${match.name}`);
});

bot.command("buscar", async (ctx) => {
  const query = ctx.match?.trim();
  if (!query) {
    await ctx.reply("Uso: /buscar iphone 13");
    return;
  }
  const user = getUser(ctx.chat.id);
  const province = provinceName(user.provinceId);
  const searchUrl = `${appUrl}/?q=${encodeURIComponent(query)}&provincia=${user.provinceId ?? ""}`;

  await ctx.reply(
    [
      `Busqueda: "${query}"`,
      `Provincia: ${province}`,
      "",
      "El indice web esta en construccion. Pronto veras resultados aqui.",
      "",
      `Abrir en web: ${searchUrl}`,
    ].join("\n"),
  );
});

bot.command("alerta", async (ctx) => {
  const query = ctx.match?.trim();
  if (!query) {
    await ctx.reply("Uso: /alerta arroz");
    return;
  }
  const user = getUser(ctx.chat.id);
  const alert = addAlert(ctx.chat.id, query, user.provinceId);
  await ctx.reply(
    [
      `Alerta creada (#${alert.id})`,
      `Producto: ${query}`,
      `Provincia: ${provinceName(user.provinceId)}`,
      "",
      "Te avisaremos cuando aparezca una oferta (fase 1: requiere base de datos).",
    ].join("\n"),
  );
});

bot.command("misalertas", async (ctx) => {
  const items = listAlerts(ctx.chat.id);
  if (items.length === 0) {
    await ctx.reply("No tienes alertas. Crea una con /alerta <producto>");
    return;
  }
  const kb = new InlineKeyboard();
  const lines = items.map((a) => {
    kb.text(`Borrar #${a.id}`, `del:${a.id}`).row();
    return `#${a.id} — ${a.query} (${provinceName(a.provinceId)})`;
  });
  await ctx.reply(["Tus alertas:", "", ...lines].join("\n"), {
    reply_markup: kb,
  });
});

bot.callbackQuery(/^del:(.+)$/, async (ctx) => {
  const id = ctx.match[1];
  const ok = removeAlert(ctx.chat!.id, id);
  await ctx.answerCallbackQuery({
    text: ok ? "Alerta eliminada" : "No encontrada",
  });
  if (ok) {
    await ctx.editMessageText(`Alerta #${id} eliminada.`);
  }
});

bot.on("message:text", async (ctx) => {
  if (ctx.message.text.startsWith("/")) return;

  const text = ctx.message.text;
  const isForward = ctx.message.forward_origin !== undefined;

  if (!isForward) return;

  if (containsBlacklistedTerm(text)) {
    await ctx.reply("No se puede indexar este contenido.");
    return;
  }

  const price = extractPrice(text);
  const currency = extractCurrency(text);
  const phone = extractPhone(text);
  const productKey = normalizeProductKey(text);

  await ctx.reply(
    [
      "Gracias. Oferta recibida (cola comunidad).",
      "",
      `Producto: ${productKey.slice(0, 80) || "(sin texto)"}`,
      price ? `Precio detectado: ${price} ${currency}` : "Precio: no detectado",
      phone ? `Telefono: ${phone}` : "",
      "",
      "Indexacion completa en fase 1 (Neon + scrapers).",
    ]
      .filter(Boolean)
      .join("\n"),
  );
});

bot.on("message:photo", async (ctx) => {
  const caption = ctx.message.caption ?? "";
  if (caption && containsBlacklistedTerm(caption)) {
    await ctx.reply("No se puede indexar este contenido.");
    return;
  }
  await ctx.reply(
    "Foto recibida. OCR e indexacion en fase 1.\n" +
      (caption ? `Texto: ${caption.slice(0, 200)}` : "Sin texto en la imagen."),
  );
});

bot.catch((err) => {
  console.error("Bot error:", err);
});

async function registerCommands(): Promise<void> {
  await bot.api.setMyCommands([
    { command: "start", description: "Iniciar y elegir provincia" },
    { command: "buscar", description: "Buscar un producto" },
    { command: "alerta", description: "Crear alerta de precio" },
    { command: "provincia", description: "Cambiar provincia" },
    { command: "misalertas", description: "Ver tus alertas" },
  ]);
}

registerCommands()
  .then(() => bot.start())
  .then(() => {
    console.log("OfertasCuba bot @Ofertas_Cuba_bot — polling activo");
  })
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
