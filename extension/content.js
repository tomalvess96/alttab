// Lê o player do YouTube Music e aperta os botões dele. Fonte principal: <video> + mediaSession;
// seletores do DOM só como alternativa (mudam com frequência).
(() => {
  const PLAY = ["#play-pause-button", "ytmusic-player-bar .play-pause-button"];
  const NEXT = ["ytmusic-player-bar .next-button", '[aria-label="Next"]', '[aria-label="Próxima"]', '[aria-label="Próximo"]'];
  const PREV = ["ytmusic-player-bar .previous-button", '[aria-label="Previous"]', '[aria-label="Anterior"]'];

  const find = (selectors) => selectors.map((s) => document.querySelector(s)).find(Boolean) ?? null;
  const area = (a) => String(a.sizes ?? "0x0").split("x").map(Number).reduce((x, y) => (x || 0) * (y || 0), 1);

  function snapshot() {
    const video = document.querySelector("video");
    const meta = navigator.mediaSession?.metadata;
    const title = meta?.title || document.querySelector("ytmusic-player-bar .title")?.textContent?.trim() || "";
    if (!video || !title) return null;
    const artwork = meta?.artwork?.length
      ? [...meta.artwork].sort((a, b) => area(b) - area(a))[0].src
      : document.querySelector("ytmusic-player-bar img")?.src ?? null;
    return {
      title,
      artist: meta?.artist || "",
      album: meta?.album || "",
      artworkUrl: artwork,
      playing: !video.paused,
      position: video.currentTime || 0,
      duration: Number.isFinite(video.duration) ? video.duration : 0,
    };
  }

  let lastKey = "";
  function report(force = false) {
    const state = snapshot();
    const key = state ? JSON.stringify({ ...state, position: Math.floor(state.position) }) : "null";
    if (!force && key === lastKey) return;
    lastKey = key;
    chrome.runtime.sendMessage({ type: "media", media: state }).catch(() => {});
  }

  setInterval(report, 1000);
  document.addEventListener("play", () => report(), true);
  document.addEventListener("pause", () => report(), true);

  chrome.runtime.onMessage.addListener((message) => {
    const video = document.querySelector("video");
    if (message.action === "playPause") {
      const button = find(PLAY);
      if (button) button.click();
      else if (video) video.paused ? video.play() : video.pause();
    } else if (message.action === "next") {
      find(NEXT)?.click();
    } else if (message.action === "previous") {
      find(PREV)?.click();
    }
    setTimeout(() => report(true), 300);
  });
})();
