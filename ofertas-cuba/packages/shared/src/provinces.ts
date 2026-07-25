export interface Province {
  id: string;
  name: string;
  slug: string;
}

/** 15 provincias + Isla de la Juventud */
export const PROVINCES: Province[] = [
  { id: "pin", name: "Pinar del Río", slug: "pinar-del-rio" },
  { id: "art", name: "Artemisa", slug: "artemisa" },
  { id: "hab", name: "La Habana", slug: "la-habana" },
  { id: "may", name: "Mayabeque", slug: "mayabeque" },
  { id: "mat", name: "Matanzas", slug: "matanzas" },
  { id: "vcl", name: "Villa Clara", slug: "villa-clara" },
  { id: "cfg", name: "Cienfuegos", slug: "cienfuegos" },
  { id: "ssp", name: "Sancti Spíritus", slug: "sancti-spiritus" },
  { id: "cav", name: "Ciego de Ávila", slug: "ciego-de-avila" },
  { id: "cmg", name: "Camagüey", slug: "camaguey" },
  { id: "ltu", name: "Las Tunas", slug: "las-tunas" },
  { id: "hol", name: "Holguín", slug: "holguin" },
  { id: "gra", name: "Granma", slug: "granma" },
  { id: "stg", name: "Santiago de Cuba", slug: "santiago-de-cuba" },
  { id: "gua", name: "Guantánamo", slug: "guantanamo" },
  { id: "ij", name: "Isla de la Juventud", slug: "isla-de-la-juventud" },
];

export const PROVINCE_BY_SLUG = Object.fromEntries(
  PROVINCES.map((p) => [p.slug, p]),
) as Record<string, Province>;

export function findProvinceByName(input: string): Province | undefined {
  const normalized = input.trim().toLowerCase();
  return PROVINCES.find(
    (p) =>
      p.name.toLowerCase() === normalized ||
      p.slug === normalized ||
      p.id === normalized,
  );
}
