import type { Metadata } from "next";
import "./globals.css";
import { ProvinceGate } from "@/components/ProvinceGate";

export const metadata: Metadata = {
  title: "OfertasCuba — Compara antes de contactar",
  description:
    "Comparador comunitario de compra y venta en Cuba. Ofertas de Facebook y Telegram por provincia.",
  manifest: "/manifest.webmanifest",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="es">
      <body>
        <ProvinceGate>{children}</ProvinceGate>
      </body>
    </html>
  );
}
