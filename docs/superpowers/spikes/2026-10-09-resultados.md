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

## Checklist do Plano 1 (09/out, 22:42)
- Instalado em `~/Applications/Alttab.app`; "Iniciar com o Mac" ligado (Itens de Início confirmou).
- Acessibilidade herdada entre builds (mesma assinatura). Gravação de Tela: o app **só entra na lista de Ajustes depois de chamar `CGRequestScreenCaptureAccess()`** — antes disso não há o que ligar.
- Miniaturas: aparecem para as 14 janelas, inclusive de workspaces escondidos; coluna em foco com miniatura grande.
- Option+Tab de ponta a ponta confirmado pelo Tom.
- Mouse (Tom): inclinação/brilho, seleção parada com mouse parado, clique e X — tudo ok.
- `alt-tab = 'workspace-back-and-forth'` removido do `~/.aerospace.toml` (linha 159) com backup em `~/.aerospace.toml.bak-alttab`; `aerospace reload-config` ok.
- Não testados: AeroSpace parado e aviso de Secure Input.

## Checklist dos Planos 2 e 3 (10/out, com o Tom)
- Extensão carregada (ID `npgoecidghckmkdhakalhchnaebjdhlc`); menu mostra "Edge: N abas · M com foto".
- Abas do Edge no alternador com miniatura, ícone e áudio — ok. Miniaturas guardadas na sessão do Edge: após reiniciar o app, 4/4 com foto.
- Mouse: seleciona exatamente o cartão embaixo — ok após dois achados:
  1. cartões cresciam ao ganhar foco (58→112 pt) e o selecionado descia para fora do ponteiro;
  2. inclinação 3D com perspectiva projetava a área de toque até ~230 pt fora do cartão (medido com registro temporário).
- Player do YouTube Music: pílula, cor da capa, tocar/pausar, próxima/anterior — ok. O YouTube Music trocou `ytmusic-player-bar` por `ytmusic-wiz-player-controls`; botões achados pelo aria-label exato ("Avançar", não "Avançar 30 segundos"). Ao recarregar a extensão o content script da aba aberta fica órfão → extensão reinjeta.
- Clique na pílula abre a aba da música; capa ampliada com progresso e controles — entregue.
- Option+Tab parou de abrir uma vez até reiniciar o app; na mesma hora o painel escondido mantinha animações vivas (25% de CPU, tap com 176 ms de latência). Corrigido (0,4%); não voltou a acontecer com registro ligado. Causa exata não confirmada.
- Instalação reinicia o alttab-host: um host antigo com o binário trocado é recusado pela verificação de assinatura.
- Limitações conhecidas: painel não aparece sobre jogo em tela cheia; aba nunca vista desde que o Edge abriu fica sem foto até ser vista; um perfil do Edge por vez.
