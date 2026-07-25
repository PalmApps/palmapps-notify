/**
 * Palabras que excluyen una oferta del indice.
 * Mantener en minusculas ASCII; el matcher normaliza el texto.
 */
export const BLACKLIST_KEYWORDS: string[] = [
  "arma",
  "armas",
  "pistola",
  "revolver",
  "municion",
  "droga",
  "marihuana",
  "cocaina",
  "fentanilo",
  "documento falso",
  "pasaporte falso",
  "licencia falsa",
  "hackeo",
  "carding",
  "estafa",
  "phishing",
];

export function containsBlacklistedTerm(text: string): boolean {
  const haystack = text.toLowerCase();
  return BLACKLIST_KEYWORDS.some((term) => haystack.includes(term));
}
