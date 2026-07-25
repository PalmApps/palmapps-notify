import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import {
  containsBlacklistedTerm,
  extractCurrency,
  extractPhone,
  extractPrice,
  normalizeProductKey,
  type ParsedOffer,
} from "@ofertas-cuba/shared";

const seedsDir = join(
  dirname(fileURLToPath(import.meta.url)),
  "../../../docs/seeds",
);

export function loadJson<T>(filename: string): T {
  const raw = readFileSync(join(seedsDir, filename), "utf8");
  return JSON.parse(raw) as T;
}

export function parseOfferText(
  text: string,
  meta: Pick<ParsedOffer, "sourcePlatform" | "sourceUrl" | "externalGroupId">,
): ParsedOffer | null {
  if (!text.trim() || containsBlacklistedTerm(text)) return null;

  return {
    productKey: normalizeProductKey(text),
    rawText: text.trim(),
    priceOriginal: extractPrice(text),
    currency: extractCurrency(text),
    phone: extractPhone(text),
    provinceId: null,
    sourceUrl: meta.sourceUrl,
    sourcePlatform: meta.sourcePlatform,
    externalGroupId: meta.externalGroupId,
    scrapedAt: new Date().toISOString(),
  };
}

export async function persistOffers(offers: ParsedOffer[]): Promise<void> {
  if (!process.env.DATABASE_URL) {
    console.log(`[dry-run] ${offers.length} offers (DATABASE_URL not set)`);
    for (const offer of offers.slice(0, 3)) {
      console.log(JSON.stringify(offer, null, 2));
    }
    return;
  }
  // TODO fase 1: insert into Neon via Drizzle or pg
  console.log(`[db] would persist ${offers.length} offers`);
}
