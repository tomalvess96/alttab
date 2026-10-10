// Funções puras da extensão (testadas com `node --test`).

export function tabPayload(tab) {
  return {
    id: tab.id,
    windowId: tab.windowId,
    title: tab.title ?? "",
    url: tab.url ?? tab.pendingUrl ?? "",
    favIconUrl: tab.favIconUrl ?? null,
    active: Boolean(tab.active),
    audible: Boolean(tab.audible),
    lastAccessed: tab.lastAccessed ?? 0,
  };
}

export function tabsMessage(tabs) {
  return { type: "tabs", tabs: tabs.filter((t) => Number.isInteger(t.id) && t.id >= 0).map(tabPayload) };
}

export function thumbSize(width, height, maxWidth = 480) {
  if (width <= maxWidth) return { width, height };
  return { width: maxWidth, height: Math.round((height * maxWidth) / width) };
}

/** `captureVisibleTab` falha em páginas internas do navegador; nem tenta. */
export function capturable(url) {
  return /^(https?|file):/.test(url ?? "");
}
