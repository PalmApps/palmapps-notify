/** In-memory store until Neon DATABASE_URL is configured (fase 1). */

export interface BotUser {
  chatId: number;
  provinceId: string | null;
}

export interface BotAlert {
  id: string;
  chatId: number;
  query: string;
  provinceId: string | null;
  createdAt: string;
}

const users = new Map<number, BotUser>();
const alerts = new Map<number, BotAlert[]>();

let alertSeq = 1;

export function getUser(chatId: number): BotUser {
  const existing = users.get(chatId);
  if (existing) return existing;
  const user: BotUser = { chatId, provinceId: null };
  users.set(chatId, user);
  return user;
}

export function setUserProvince(chatId: number, provinceId: string): BotUser {
  const user = getUser(chatId);
  user.provinceId = provinceId;
  users.set(chatId, user);
  return user;
}

export function addAlert(
  chatId: number,
  query: string,
  provinceId: string | null,
): BotAlert {
  const list = alerts.get(chatId) ?? [];
  const alert: BotAlert = {
    id: String(alertSeq++),
    chatId,
    query: query.toLowerCase().trim(),
    provinceId,
    createdAt: new Date().toISOString(),
  };
  list.push(alert);
  alerts.set(chatId, list);
  return alert;
}

export function listAlerts(chatId: number): BotAlert[] {
  return alerts.get(chatId) ?? [];
}

export function removeAlert(chatId: number, alertId: string): boolean {
  const list = alerts.get(chatId) ?? [];
  const next = list.filter((a) => a.id !== alertId);
  if (next.length === list.length) return false;
  alerts.set(chatId, next);
  return true;
}
