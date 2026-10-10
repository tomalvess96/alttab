// Lê o player do YouTube Music e aperta os botões dele. Fonte principal: <video> + mediaSession;
// seletores do DOM só como alternativa (mudam com frequência).
(() => {
  // Mesma tabela de lib.js (CONTROL_LABELS): nome exato do botão no player novo (ytmusic-wiz-player-controls).
  const LABELS = {
    next: ["Avançar", "Próxima", "Próximo", "Next"],
    previous: ["Anterior", "Previous"],
    playPause: ["Tocar", "Pausar", "Reproduzir", "Play", "Pause"],
  };
  // Player antigo, se o YouTube Music voltar a ele.
  const LEGACY = {
    next: ["ytmusic-player-bar .next-button"],
    previous: ["ytmusic-player-bar .previous-button"],
    playPause: ["#play-pause-button", "ytmusic-player-bar .play-pause-button"],
  };
  function findControl(action) {
    const scope = document.querySelector("ytmusic-wiz-player-controls") ?? document.querySelector("ytmusic-player-bar") ?? document;
    const byLabel = [...scope.querySelectorAll("button[aria-label]")].find((b) => LABELS[action].includes(b.getAttribute("aria-label")));
    return byLabel ?? LEGACY[action].map((s) => document.querySelector(s)).find(Boolean) ?? null;
  }
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
      const button = findControl("playPause");
      if (button) button.click();
      else if (video) video.paused ? video.play() : video.pause();
    } else if (message.action === "next" || message.action === "previous") {
      findControl(message.action)?.click();
    }
    setTimeout(() => report(true), 300);
  });
})();
