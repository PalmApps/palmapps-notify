"use client";

import { useProvince } from "@/components/ProvinceGate";

export default function HomePage() {
  const { province } = useProvince();

  return (
    <main>
      <header style={{ marginBottom: "1.5rem" }}>
        <h1>OfertasCuba</h1>
        <p>
          Provincia: <strong>{province?.name}</strong>{" "}
          <button
            type="button"
            onClick={() => {
              localStorage.removeItem("ofertas-cuba-province");
              window.location.reload();
            }}
            style={{
              background: "transparent",
              border: "none",
              color: "var(--accent)",
              cursor: "pointer",
              textDecoration: "underline",
            }}
          >
            cambiar
          </button>
        </p>
      </header>

      <div className="card">
        <h2>En construccion (fase 0)</h2>
        <p>
          Proximamente: busqueda y comparacion de ofertas desde grupos publicos
          de <strong>Facebook</strong> y <strong>Telegram</strong>, con precios
          en USD/EUR de referencia (El Toque).
        </p>
        <ul>
          <li>Web PWA en ofertascuba.vercel.app</li>
          <li>Bot Telegram para busqueda, alertas y reenvio de ofertas</li>
          <li>Scrapers en GitHub Actions</li>
        </ul>
      </div>

      <p className="disclaimer">
        Los precios mostrados provienen de publicaciones publicas. OfertasCuba no
        garantiza disponibilidad ni autenticidad. Usa el boton reportar cuando
        este disponible.
      </p>
    </main>
  );
}
