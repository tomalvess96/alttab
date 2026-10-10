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
