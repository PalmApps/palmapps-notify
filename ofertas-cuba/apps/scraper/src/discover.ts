import { loadJson } from "./lib.js";

interface DiscoveryKeywords {
  facebook: string[];
  telegram: string[];
}

/**
 * Fase 0: imprime keywords.
 * Fase 1: buscar grupos/canales y persistir en tabla `groups`.
 */
export async function runDiscovery(): Promise<void> {
  const keywords = loadJson<DiscoveryKeywords>("discovery-keywords.json");
  console.log("Discovery keywords:");
  console.log("Facebook:", keywords.facebook.join(", "));
  console.log("Telegram:", keywords.telegram.join(", "));
  console.log("Policy: auto-permissive (indexar; retirar si reportes).");
}

runDiscovery().catch((err) => {
  console.error(err);
  process.exit(1);
});
