import { tabsMessage, thumbSize, capturable } from "./lib.js";

const HOST = "br.inf.brusoft.alttab";
let port = null;
let tabsTimer = null;
const captureTimers = new Map();

function connect() {
  try {
    port = chrome.runtime.connectNative(HOST);
  } catch {
    port = null;
    setTimeout(connect, 5000);
    return;
  }
  port.onMessage.addListener(onCommand);
  port.onDisconnect.addListener(() => {
    port = null;
    setTimeout(connect, 5000);
  });
  sendTabs();
}

function post(message) {
  if (!port) return;
  try {
    port.postMessage(message);
  } catch {
    port = null;
  }
}

function sendTabs() {
  clearTimeout(tabsTimer);
  tabsTimer = setTimeout(async () => post(tabsMessage(await chrome.tabs.query({}))), 150);
}

function scheduleCapture(windowId, delay = 350) {
  clearTimeout(captureTimers.get(windowId));
  captureTimers.set(windowId, setTimeout(() => captureActive(windowId), delay));
}

async function captureActive(windowId) {
  const [tab] = await chrome.tabs.query({ active: true, windowId });
  if (!tab || !capturable(tab.url)) return;
  try {
    const dataUrl = await chrome.tabs.captureVisibleTab(windowId, { format: "jpeg", quality: 70 });
    const bitmap = await createImageBitmap(await (await fetch(dataUrl)).blob());
    const size = thumbSize(bitmap.width, bitmap.height);
    const canvas = new OffscreenCanvas(size.width, size.height);
    canvas.getContext("2d").drawImage(bitmap, 0, 0, size.width, size.height);
    const jpeg = await canvas.convertToBlob({ type: "image/jpeg", quality: 0.72 });
    post({ type: "thumb", tabId: tab.id, jpegBase64: await toBase64(jpeg), capturedAt: Date.now() });
  } catch {
    // Janela minimizada, página protegida ou limite de capturas por segundo: segue sem foto.
  }
}

async function toBase64(blob) {
  const bytes = new Uint8Array(await blob.arrayBuffer());
  let binary = "";
  for (let i = 0; i < bytes.length; i += 0x8000) binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(binary);
}

async function onCommand(message) {
  if (message.type === "hello") {
    sendTabs();
    for (const window of await chrome.windows.getAll()) scheduleCapture(window.id, 50);
  } else if (message.type === "activate") {
    try {
      const tab = await chrome.tabs.update(message.tabId, { active: true });
      await chrome.windows.update(tab.windowId, { focused: true });
    } catch {}
  } else if (message.type === "close") {
    chrome.tabs.remove(message.tabId).catch(() => {});
  }
}

for (const event of [chrome.tabs.onCreated, chrome.tabs.onRemoved, chrome.tabs.onMoved,
                     chrome.tabs.onAttached, chrome.tabs.onDetached]) {
  event.addListener(sendTabs);
}
chrome.tabs.onUpdated.addListener((_id, change, tab) => {
  sendTabs();
  if (change.status === "complete" && tab.active) scheduleCapture(tab.windowId, 400);
});
chrome.tabs.onActivated.addListener(({ windowId }) => {
  sendTabs();
  scheduleCapture(windowId);
});
chrome.windows.onFocusChanged.addListener((windowId) => {
  if (windowId !== chrome.windows.WINDOW_ID_NONE) scheduleCapture(windowId);
});
chrome.runtime.onStartup.addListener(() => {});
connect();
