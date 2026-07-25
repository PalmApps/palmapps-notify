"use client";

import { PROVINCES, type Province } from "@ofertas-cuba/shared";
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from "react";

const STORAGE_KEY = "ofertas-cuba-province";

interface ProvinceContextValue {
  province: Province | null;
  setProvince: (province: Province) => void;
  ready: boolean;
}

const ProvinceContext = createContext<ProvinceContextValue | null>(null);

export function ProvinceGate({ children }: { children: React.ReactNode }) {
  const [province, setProvinceState] = useState<Province | null>(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (saved) {
      const match = PROVINCES.find((p) => p.slug === saved);
      if (match) setProvinceState(match);
    }
    setReady(true);
  }, []);

  const setProvince = useCallback((next: Province) => {
    localStorage.setItem(STORAGE_KEY, next.slug);
    setProvinceState(next);
  }, []);

  const value = useMemo(
    () => ({ province, setProvince, ready }),
    [province, setProvince, ready],
  );

  if (!ready) {
    return (
      <main>
        <p>Cargando…</p>
      </main>
    );
  }

  if (!province) {
    return <ProvinceOnboarding onSelect={setProvince} />;
  }

  return (
    <ProvinceContext.Provider value={value}>{children}</ProvinceContext.Provider>
  );
}

function ProvinceOnboarding({
  onSelect,
}: {
  onSelect: (province: Province) => void;
}) {
  const [slug, setSlug] = useState(PROVINCES[2].slug);

  return (
    <main>
      <div className="card">
        <h1>OfertasCuba</h1>
        <p>Compara ofertas de compra y venta en tu provincia.</p>
        <label htmlFor="province">Provincia</label>
        <select
          id="province"
          value={slug}
          onChange={(e) => setSlug(e.target.value)}
        >
          {PROVINCES.map((p) => (
            <option key={p.id} value={p.slug}>
              {p.name}
            </option>
          ))}
        </select>
        <p style={{ marginTop: "1rem" }}>
          <button
            type="button"
            className="primary"
            onClick={() => {
              const selected = PROVINCES.find((p) => p.slug === slug);
              if (selected) onSelect(selected);
            }}
          >
            Continuar
          </button>
        </p>
      </div>
      <p className="disclaimer">
        Precios del mercado informal agregados desde fuentes publicas. Verifica
        siempre antes de pagar. Proyecto comunitario PalmApps — fase beta.
      </p>
    </main>
  );
}

export function useProvince() {
  const ctx = useContext(ProvinceContext);
  if (!ctx) {
    throw new Error("useProvince must be used within ProvinceGate");
  }
  return ctx;
}
