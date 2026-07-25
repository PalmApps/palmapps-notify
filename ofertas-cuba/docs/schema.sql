-- Fase 1: ejecutar en Neon SQL editor

CREATE TABLE IF NOT EXISTS provinces (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  platform TEXT NOT NULL CHECK (platform IN ('facebook', 'telegram')),
  external_id TEXT NOT NULL,
  name TEXT NOT NULL,
  province_id TEXT REFERENCES provinces(id),
  status TEXT NOT NULL DEFAULT 'active',
  member_count INT,
  last_scraped_at TIMESTAMPTZ,
  UNIQUE (platform, external_id)
);

CREATE TABLE IF NOT EXISTS offers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID REFERENCES groups(id),
  source TEXT NOT NULL CHECK (source IN ('scrape', 'telegram_forward')),
  source_platform TEXT NOT NULL,
  raw_text TEXT NOT NULL,
  product_key TEXT NOT NULL,
  price_original NUMERIC,
  currency TEXT,
  price_usd NUMERIC,
  price_eur NUMERIC,
  phone TEXT,
  fb_post_url TEXT,
  telegram_message_url TEXT,
  province_id TEXT REFERENCES provinces(id),
  scraped_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ,
  is_reported BOOLEAN NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS offers_product_key_idx ON offers (product_key);
CREATE INDEX IF NOT EXISTS offers_province_scraped_idx ON offers (province_id, scraped_at DESC);

CREATE TABLE IF NOT EXISTS fx_rates (
  date DATE PRIMARY KEY,
  rates_json JSONB NOT NULL,
  source TEXT NOT NULL DEFAULT 'eltoque'
);

CREATE TABLE IF NOT EXISTS telegram_users (
  chat_id BIGINT PRIMARY KEY,
  province_id TEXT REFERENCES provinces(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chat_id BIGINT NOT NULL REFERENCES telegram_users(chat_id),
  query TEXT NOT NULL,
  province_id TEXT REFERENCES provinces(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  offer_id UUID NOT NULL REFERENCES offers(id),
  reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
