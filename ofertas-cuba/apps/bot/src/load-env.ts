import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

/** Load repo-root .env without adding dotenv dependency. */
export function loadEnv(): void {
  const candidates = [
    resolve(process.cwd(), ".env"),
    resolve(process.cwd(), "../../.env"),
    resolve(import.meta.dirname, "../../../.env"),
  ];

  for (const path of candidates) {
    if (!existsSync(path)) continue;
    const lines = readFileSync(path, "utf8").split("\n");
    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith("#")) continue;
      const eq = trimmed.indexOf("=");
      if (eq === -1) continue;
      const key = trimmed.slice(0, eq).trim();
      const value = trimmed.slice(eq + 1).trim();
      if (!process.env[key]) process.env[key] = value;
    }
    return;
  }
}
