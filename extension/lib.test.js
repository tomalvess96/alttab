import { test } from "node:test";
import assert from "node:assert/strict";
import { tabPayload, tabsMessage, thumbSize, capturable } from "./lib.js";

test("tabPayload normaliza campos que o Chromium pode omitir", () => {
  assert.deepEqual(tabPayload({ id: 3, windowId: 1, active: true }), {
    id: 3, windowId: 1, title: "", url: "", favIconUrl: null, active: true, audible: false, lastAccessed: 0,
  });
});

test("tabPayload usa pendingUrl enquanto a aba carrega", () => {
  assert.equal(tabPayload({ id: 1, windowId: 1, pendingUrl: "https://a.com" }).url, "https://a.com");
});

test("tabsMessage descarta abas sem id válido", () => {
  const message = tabsMessage([{ id: -1, windowId: 1 }, { id: 2, windowId: 1, title: "x" }]);
  assert.equal(message.type, "tabs");
  assert.deepEqual(message.tabs.map((t) => t.id), [2]);
});

test("thumbSize reduz para 480 de largura mantendo a proporção", () => {
  assert.deepEqual(thumbSize(2544, 1393), { width: 480, height: 263 });
  assert.deepEqual(thumbSize(400, 300), { width: 400, height: 300 });
});

test("capturable recusa páginas internas e vazias", () => {
  assert.equal(capturable("https://desk.evotalks.ai/x"), true);
  assert.equal(capturable("file:///tmp/a.html"), true);
  assert.equal(capturable("edge://newtab/"), false);
  assert.equal(capturable("about:blank"), false);
  assert.equal(capturable(undefined), false);
});
