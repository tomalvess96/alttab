# Alternador de janelas e abas (Option+Tab) — Design

**Data:** 09/out/2026 · **Status:** em revisão · **Protótipo visual:** https://claude.ai/artifact/HXkTSRDNCgCbaDYEVJ61fd (quadro "A · com 8 workspaces")

Projeto pessoal do Tom, fora do Cockpit (sem card, sem apontamento de horas).

## 1. Objetivo

Um alternador estilo Alt+Tab do Windows para o Mac mini, que mostra **numa tela só** as janelas do Warp
(organizadas por workspace do AeroSpace) e **as abas do Edge com miniatura**, com visual de vidro do macOS
e animações caprichadas.

**Sucesso =** apertar Option+Tab, achar a janela/aba certa pelo olho (miniatura) ou digitando, soltar e
estar nela — mais rápido que trocar de workspace no AeroSpace e caçar a aba no Edge.

## 2. Escopo

**Dentro:**
- Janelas de qualquer app gerenciadas pelo AeroSpace (na prática: Warp e Edge), agrupadas por workspace.
- Abas do Microsoft Edge, com miniatura.
- Busca por título/endereço, fechar janela/aba, player do YouTube Music.

**Fora (por enquanto):**
- Safari, Chrome e outros navegadores.
- Abas internas do Warp (cada aba do Warp vira janela própria no AeroSpace — é assim que o Tom já usa).
- Agrupar abas por site (fica para quando passar de ~30 abas com frequência).
- Distribuição para outras pessoas / Mac App Store.

## 3. Experiência

### 3.1 Abrir, navegar, escolher
| Ação | Resultado |
|---|---|
| Segurar **Option** + **Tab** | Abre o painel com a **última janela usada** já selecionada |
| Tab / Shift+Tab (Option segurado) | Próximo / anterior, na ordem de uso recente |
| ← → | Workspace anterior / próximo |
| ↑ ↓ | Janela ou aba dentro do workspace |
| 1–9 | Pula para o workspace (enquanto nada foi digitado; depois entra na busca) |
| Digitar qualquer letra | Filtra; o painel fica **fixo** (soltar Option não confirma mais — Enter confirma, Esc cancela) |
| **/** ou **espaço** | Ativa a busca (painel fixo, cursor piscando) sem precisar do mouse |
| **Option+W** | Fecha a janela/aba selecionada (só enquanto nada foi digitado; depois W vira letra da busca) |
| Soltar Option | Vai para a seleção e fecha o painel (se nada foi digitado) |
| Esc | Fecha o painel sem trocar |
| Mouse | Passar por cima seleciona (só com movimento real do mouse, ≥3 pt: mouse parado não troca a seleção); clique escolhe |

Option+Tab rápido (apertar e soltar) = volta para a janela anterior — substitui o
`alt-tab = 'workspace-back-and-forth'` do AeroSpace, que será **removido na instalação**.

### 3.2 Layout ("A · grade de workspaces", modo foco)
- **Topo:** busca à esquerda · ícone do app + título da seleção · à direita "Bom dia/Boa tarde/Boa noite, Tom",
  data/hora e a **foto da conta do macOS**.
- **Meio:** uma coluna por workspace ocupado, com o número no topo (o workspace atual em destaque).
  A coluna da seleção **abre mais larga** (animação suave de largura) e as outras encolhem e esmaecem.
- **Cartão de janela:** miniatura + ícone + título. Mouse por cima: **inclinação 3D seguindo o ponteiro**
  (8°) e brilho na posição do cursor.
- **Coluna do Edge:**
  - Fora de foco: 3 abas mais recentes com miniatura + cartão empilhado **"+N"**.
  - Em foco, até 4 abas: miniaturas normais.
  - Em foco, mais de 4 abas: **destaque grande da aba selecionada no topo** (miniatura, título completo,
    endereço, "visto há X", botão X) + **grade fixa de miniaturas pequenas**, uma por aba, com o ícone do
    site no canto. Colunas: até 9 abas → 3; até 20 → 5; acima → 6. **A grade nunca se reorganiza ao passar o
    mouse** — só muda o contorno e o conteúdo do destaque (troca com esmaecimento). Sem rolagem.
- **Busca:** mostra **só** o que bate (título ou endereço); workspace sem resultado some; o trecho encontrado
  fica destacado; a seleção pula para o primeiro resultado.
- **Fechar:** X no canto de cima à direita da miniatura do selecionado; o cartão encolhe, desfoca e some.
  Se o app pedir confirmação (ex.: Warp com processo rodando), o alternador **não força** — deixa o app perguntar.
- **Player do YouTube Music** (só aparece se houver aba do YouTube Music): pílula compacta de 50 px com capa,
  título, artista, visualizador de barrinhas, anterior/tocar-pausar/próxima e progresso fino.
  - Toda a pílula é **tingida com a cor dominante da capa**, que muda devagar (0,6 s) entre músicas.
  - Brilho só no hover, seguindo o mouse; nada piscando sozinho.
  - Clicar na capa: ela **gira (flip) e cresce** até o centro do painel (280 px) com o nome embaixo; clicar fecha.
- **Fundo:** vidro real do macOS (Liquid Glass; fallback para o vidro fosco clássico).
- **Cor de destaque:** âmbar `#FFB547`. Fontes do sistema (SF Pro / SF Mono) no app nativo.

## 4. Arquitetura — 3 peças

```
┌──────────────── Mac ────────────────────────────────────────────────┐
│                                                                     │
│  AlttabApp (Swift, barra de menu, sem ícone no Dock)                │
│   ├─ HotkeyMonitor ── CGEventTap: Option+Tab, Tab, Option solto     │
│   ├─ WindowSource ─── `aerospace list-windows --all --json`         │
│   │                   `aerospace focus/close --window-id`           │
│   ├─ WindowThumbs ─── ScreenCaptureKit + cache por janela           │
│   ├─ BrowserSource ── socket local ◄──┐                             │
│   ├─ SwitcherModel ── junta tudo: MRU, busca, seleção, layout       │
│   └─ SwitcherPanel ── NSPanel + SwiftUI + Liquid Glass              │
│                                       │                             │
│  alttab-host (binário pequeno) ───────┘ ponte stdin/stdout ↔ socket │
│        ▲ Native Messaging                                           │
│  Extensão do Edge (MV3)                                             │
│   ├─ abas: lista, ativar, fechar, foto ao ficar visível             │
│   └─ content script em music.youtube.com: música, capa, controles   │
└─────────────────────────────────────────────────────────────────────┘
```

### 4.1 App nativo (Swift 6, SwiftUI + AppKit, macOS 27)
Fica fora da stack web padrão do time porque hotkey global, vidro real e captura de janela só existem
nativamente.

| Unidade | Faz | Depende de |
|---|---|---|
| `HotkeyMonitor` | Detecta Option+Tab e os eventos enquanto Option está segurado; engole o Tab para não vazar pro app da frente | Permissão de **Acessibilidade** |
| `WindowSource` | Lista janelas (id, app, título, workspace), foca e fecha via CLI do AeroSpace | `aerospace` no PATH |
| `WindowThumbs` | Tira a miniatura das janelas; guarda a última imagem por janela | Permissão de **Gravação de Tela** |
| `BrowserSource` | Recebe abas, miniaturas e estado do player da extensão; manda comandos (ativar, fechar, tocar…) | Socket Unix local |
| `MRUTracker` | Ordem de uso recente (janelas e abas), alimentada por foco do AeroSpace e ativação de aba | `WindowSource`, `BrowserSource` |
| `SwitcherModel` | Estado puro: itens, filtro, seleção, colunas, regras de layout da coluna do Edge | — (testável sem UI) |
| `AlbumColor` | Cor dominante da capa, com clamp de luminância para manter texto legível | Core Image |
| `SwitcherPanel` | Painel flutuante, não ativa o app da frente, aparece sobre tudo; views SwiftUI | `SwitcherModel` |
| `UserGreeting` | Saudação por horário + foto da conta do macOS | Identidade do usuário local |

- Inicia no login (`SMAppService`). Ícone na barra de menu com: pausar, permissões, sair.
- Assinatura: certificado de desenvolvedor local — **não** ad-hoc com hardened runtime (já quebrou carregamento
  de framework embutido em outro app deste Mac).

### 4.2 Extensão do Edge (Manifest V3, JavaScript)
- `chrome.tabs` para listar, ativar (`tabs.update` + `windows.update focused`) e fechar abas.
- **Miniaturas:** ao ativar uma aba ou ela terminar de carregar, `tabs.captureVisibleTab` (JPEG pequeno, ~480 px
  de largura) e guarda por id de aba. Aba nunca vista desde que o Edge abriu → só ícone até ser vista.
- **YouTube Music:** content script em `music.youtube.com` lê título, artista, capa e tempo do player
  (DOM do player, com `mediaSession` como alternativa) e aciona os botões do próprio player.
- Comunicação: Native Messaging com o `alttab-host`, registrado em
  `~/Library/Application Support/Microsoft Edge/NativeMessagingHosts/`.

### 4.3 Ponte `alttab-host`
Binário mínimo que o Edge inicia; repassa mensagens JSON entre a extensão (stdin/stdout) e o app
(socket Unix em `~/Library/Application Support/alttab/`). Se o app não estiver rodando, descarta e tenta de
novo na próxima mensagem.

## 5. Fluxo de dados
1. Em segundo plano, o app mantém um **retrato atualizado**: janelas do AeroSpace (atualizado ao trocar foco),
   abas e player (empurrados pela extensão a cada mudança) e miniaturas em cache.
2. Option+Tab → o painel abre **na hora com o retrato em cache** (meta: < 80 ms até aparecer) e atualiza em
   seguida se algo mudou.
3. Escolha → `aerospace focus --window-id` (janela) ou comando "ativar aba" para a extensão + foco na janela do Edge.

## 6. Erros e permissões
| Situação | Comportamento |
|---|---|
| Sem permissão de Acessibilidade | Hotkey não funciona; menu da barra mostra aviso e abre o painel de Ajustes certo |
| Sem Gravação de Tela | Janelas aparecem com ícone do app no lugar da miniatura; aviso no menu |
| AeroSpace fora do ar / CLI falha | Cai para lista simples de janelas do macOS sem workspaces; aviso discreto no painel |
| Extensão desconectada | Edge aparece como janela comum, sem abas; aviso discreto |
| Miniatura de janela em workspace escondido não captura | Usa a última imagem guardada de quando a janela esteve visível |
| Capa clara demais | `AlbumColor` escurece/satura antes de tingir |

## 7. Testes
- **Unitários (XCTest)** no que é lógica pura: `SwitcherModel` (filtro, seleção, colunas, regra de 4/9/20 abas,
  "+N"), `MRUTracker`, `AlbumColor` (clamp), parser do JSON do AeroSpace.
- **Extensão:** testes do protocolo de mensagens (formato de entrada/saída) com Node.
- **Manual (checklist)** com o setup real: 8 workspaces, 20 abas, YouTube Music tocando, permissões negadas,
  AeroSpace parado, Edge fechado.

## 8. Riscos
1. **Miniatura de janela escondida pelo AeroSpace** — o AeroSpace esconde janelas de outros workspaces
   jogando-as para o canto da tela; a captura pode vir vazia. Mitigação: cache da última imagem visível
   (seção 6). Validar logo no início.
2. **Option+Tab engolido** — o CGEventTap tem que consumir o Tab só enquanto Option está segurado e
   devolver todo o resto; bug aqui atrapalha o teclado inteiro. Mitigação: tap mínimo e testado primeiro.
3. **Secure Input bloqueia a hotkey** — com campo de senha focado ou "Secure Keyboard Entry" ligado num
   terminal, o macOS não entrega teclas ao CGEventTap e o Option+Tab "morre" (já aconteceu com atalhos globais
   neste Mac). Mitigação: detectar Secure Input ativo e avisar no ícone da barra de menu qual app está segurando.
4. **DOM do YouTube Music muda** — seletores quebram. Mitigação: `mediaSession` como alternativa; player some
   em vez de mostrar dado errado.

## 9. Instalação
1. Instalar o app e conceder Acessibilidade + Gravação de Tela.
2. Carregar a extensão no Edge (modo desenvolvedor) e registrar o `alttab-host`.
3. **Remover `alt-tab = 'workspace-back-and-forth'`** de `~/.aerospace.toml` (linha 159) e recarregar o AeroSpace.
