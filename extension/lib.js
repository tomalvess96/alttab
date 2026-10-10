// Funções puras da extensão (testadas com `node --test`).

export function tabPayload(tab, favicons = {}) {
  return {
    id: tab.id,
    windowId: tab.windowId,
    title: tab.title ?? "",
    url: tab.url ?? tab.pendingUrl ?? "",
    favIconUrl: tab.favIconUrl ?? null,
    favIconData: favicons[tab.url] ?? null,
    active: Boolean(tab.active),
    audible: Boolean(tab.audible),
    lastAccessed: tab.lastAccessed ?? 0,
  };
}

export function tabsMessage(tabs, favicons = {}) {
  return { type: "tabs", tabs: tabs.filter((t) => Number.isInteger(t.id) && t.id >= 0).map((t) => tabPayload(t, favicons)) };
}

export function thumbSize(width, height, maxWidth = 480) {
  if (width <= maxWidth) return { width, height };
  return { width: maxWidth, height: Math.round((height * maxWidth) / width) };
}

/** `captureVisibleTab` falha em páginas internas do navegador; nem tenta. */
export function capturable(url) {
  return /^(https?|file):/.test(url ?? "");
}

/** Maior imagem declarada em `MediaMetadata.artwork` (sizes "LxA"). */
export function pickArtwork(list) {
  if (!Array.isArray(list) || list.length === 0) return null;
  const area = (a) => {
    const [w, h] = String(a.sizes ?? "0x0").split("x").map(Number);
    return (w || 0) * (h || 0);
  };
  return [...list].sort((a, b) => area(b) - area(a))[0].src ?? null;
}

/** Chave para só avisar o app quando algo visível mudou (posição em segundos inteiros). */
export function mediaKey(state) {
  if (!state) return "null";
  return JSON.stringify({ ...state, position: Math.floor(state.position ?? 0) });
}

/** Ícone do cache do próprio navegador (permissão "favicon"): sem baixar nada da página. */
export function faviconRequestUrl(base, pageUrl, size = 32) {
  return `${base}?pageUrl=${encodeURIComponent(pageUrl)}&size=${size}`;
}

// Nomes exatos (aria-label) dos botões do player do YouTube Music, em pt-BR e inglês.
// Exatos de propósito: "Avançar 30 segundos" não pode ser confundido com "Avançar".
// content.js repete esta tabela (content script não importa módulos) — mantenha as duas iguais.
export const CONTROL_LABELS = {
  next: ["Avançar", "Próxima", "Próximo", "Next"],
  previous: ["Anterior", "Previous"],
  playPause: ["Tocar", "Pausar", "Reproduzir", "Play", "Pause"],
};

export function controlAction(label) {
  for (const [action, labels] of Object.entries(CONTROL_LABELS)) if (labels.includes(label)) return action;
  return null;
}

/** Fotos guardadas (por endereço) das abas abertas, no formato da mensagem "thumb". */
export function thumbsToResend(cache, tabs) {
  return tabs
    .filter((tab) => cache[tab.url])
    .map((tab) => ({ type: "thumb", tabId: tab.id, jpegBase64: cache[tab.url].jpegBase64, capturedAt: cache[tab.url].capturedAt }));
}

/** Guarda as fotos das abas abertas e completa com as mais recentes até `max` (o resto sai). */
export function pruneThumbCache(cache, liveUrls, max = 150) {
  const entries = Object.entries(cache);
  const live = entries.filter(([url]) => liveUrls.has(url));
  const others = entries.filter(([url]) => !liveUrls.has(url)).sort((a, b) => b[1].capturedAt - a[1].capturedAt);
  return Object.fromEntries([...live, ...others.slice(0, Math.max(0, max - live.length))]);
}

/** Foto guardada na sessão do Edge: nunca de aba anônima, nunca de página interna. */
export function shouldRememberThumb(tab) {
  return !tab.incognito && capturable(tab.url);
}
