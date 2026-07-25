export type SourcePlatform = "facebook" | "telegram" | "telegram_forward";

export type OfferCurrency = "CUP" | "MLC" | "USD" | "EUR" | "UNKNOWN";

export interface ParsedOffer {
  productKey: string;
  rawText: string;
  priceOriginal: number | null;
  currency: OfferCurrency;
  phone: string | null;
  provinceId: string | null;
  sourceUrl: string | null;
  sourcePlatform: SourcePlatform;
  externalGroupId: string | null;
  scrapedAt: string;
}

export interface FxRates {
  date: string;
  usdCup: number | null;
  eurCup: number | null;
  source: string;
}
