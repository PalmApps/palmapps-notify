import type { OfferCurrency } from "../types";

const CURRENCY_PATTERNS: Array<{ currency: OfferCurrency; pattern: RegExp }> = [
  { currency: "USD", pattern: /\b(usd|dolar(?:es)?|dlls?|us\$|\$)\b/i },
  { currency: "EUR", pattern: /\b(eur|euro?s?|€)\b/i },
  { currency: "MLC", pattern: /\b(mlc)\b/i },
  { currency: "CUP", pattern: /\b(cup|peso?s?|mn)\b/i },
];

const PHONE_PATTERN =
  /(?:\+53|53)?[\s-]?(?:5\d{7}|[2-4,6-9]\d{6,7})/;

export function extractPhone(text: string): string | null {
  const match = text.match(PHONE_PATTERN);
  return match ? match[0].replace(/\s|-/g, "") : null;
}

export function extractCurrency(text: string): OfferCurrency {
  for (const { currency, pattern } of CURRENCY_PATTERNS) {
    if (pattern.test(text)) return currency;
  }
  return "UNKNOWN";
}

export function extractPrice(text: string): number | null {
  const normalized = text.replace(/\./g, "").replace(/,/g, ".");
  const match = normalized.match(/(\d+(?:\.\d{1,2})?)/);
  if (!match) return null;
  const value = Number.parseFloat(match[1]);
  return Number.isFinite(value) ? value : null;
}

export function normalizeProductKey(text: string): string {
  return text
    .toLowerCase()
    .normalize("NFD")
    .replace(/\p{M}/gu, "")
    .replace(/[^a-z0-9\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 120);
}
