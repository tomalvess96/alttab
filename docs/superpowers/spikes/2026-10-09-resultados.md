# Resultados dos spikes — 09/out/2026

## Teclado (CGEventTap de sessão, inserido no topo)
- O tap viu **todos** os Option+Tab (7/7) e os engoliu.
- Com o `alt-tab = 'workspace-back-and-forth'` do AeroSpace **ainda ativo**, o AeroSpace **não** reagiu (confirmado pelo Tom): o tap chega antes do atalho do AeroSpace. Remover o atalho na instalação é limpeza, não requisito.
- `IsSecureEventInputEnabled()` = false durante o teste.
- Permissão de Acessibilidade herdada do terminal (Warp) — o app final pede a dele.

## Captura (ScreenCaptureKit)
- `window-id` do AeroSpace **=** `CGWindowID`: as 13 janelas foram encontradas no `SCShareableContent`.
- Janelas de workspaces escondidos (o AeroSpace joga para o canto, frame em (2559,1412)) **capturam com conteúdo real e atual** — conferido visualmente (Warp do workspace 3, Edge do 10).
- Decisão: a estratégia "capturar ao abrir + cache da última imagem boa" segue válida; o cache vira só proteção.
- **Achado de SDK:** no SDK do macOS 27 `SCScreenshotManager.captureImage(contentFilter:configuration:)` **não** tem variante `async` importada (só `completionHandler:`); usar `withCheckedThrowingContinuation`.
- **Achado:** em processo sem `NSApplication.shared` a captura aborta com `CGS_REQUIRE_INIT` (no app isso já existe).
