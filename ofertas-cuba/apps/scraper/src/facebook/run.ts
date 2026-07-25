import { loadJson, parseOfferText, persistOffers } from "../lib.js";

interface FacebookGroupSeed {
  name: string;
  url: string;
  provinceId: string | null;
  notes?: string;
}

/**
 * Fase 0: estructura y dry-run.
 * Fase 1: fetch public group feed HTML / API workaround.
 */
export async function runFacebookScraper(): Promise<void> {
  const groups = loadJson<FacebookGroupSeed[]>("facebook-groups.json");
  console.log(`Facebook scraper — ${groups.length} grupos semilla`);

  const sampleText =
    "Vendo iPhone 13 128GB, 350 USD, La Habana. WhatsApp +5351234567";

  const parsed = parseOfferText(sampleText, {
    sourcePlatform: "facebook",
    sourceUrl: groups[0]?.url ?? null,
    externalGroupId: groups[0]?.url ?? null,
  });

  await persistOffers(parsed ? [parsed] : []);
  console.log("Facebook scrape run complete (stub).");
}

runFacebookScraper().catch((err) => {
  console.error(err);
  process.exit(1);
});
