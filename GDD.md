# MSDD — Game Design Document (v0.5 / Foundational + Quatro Protótipos)

> Rascunho inicial. Compila as decisões fundamentais tomadas em sessão de brainstorming.
> Tudo aqui é revisável — o objetivo é servir de âncora conceitual, não de contrato.
> **Atualização 2026-08-30:** §15 com o estado do primeiro protótipo (Minesweeper + caça-chaves).
> **Atualização 2026-09-02:** §16 com o estado do segundo protótipo (Exploração — knight + chunks conectados).
> **Atualização 2026-09-06:** §17 com o estado do terceiro protótipo (Cripta — Minesweeper cozy com HP + 2d6). Seções 1-14 permanecem como visão conceitual.
> **Atualização 2026-09-24:** menu ganhou descrição curta por modo (§15.1); densidade de bombas da Exploração subiu de ~10% pra ~15% (§16.1).
> **Atualização 2026-09-27:** §18 com a cascata de revelação — primeira camada puramente estética do projeto, compartilhada pelos protótipos 2 e 3.
> **Atualização 2026-09-29:** cascata estendida ao protótipo 1 (§18 agora vale para os três modos).
> **Atualização 2026-09-30:** §19 com o quarto protótipo (Save the Dodo — grid grande com liberação por zona/quadrante). Decisões em aberto deste protótipo estão na **§19.5**.
> **Correção 2026-09-30:** `tile_hint.gdshader` descartava o `modulate` dos tiles (§18.3) — nenhum tingimento de tile jamais apareceu na tela até aqui, incluindo o clarão da cascata.
> **Atualização 2026-10-02:** Save the Dodo perdeu o first-click-safe por região; só a primeira casa da partida é protegida (§19.2, §19.5 item 3). No mesmo dia ganhou 50 moedas coletáveis (§19.1) — primeiro passo, ainda sem uso pra elas.

---

## 1. Pitch

**MSDD** é um puzzle-RPG tático para desktop que cruza **Minesweeper** com **Dungeons & Dragons**. Cada partida é uma dungeon procedural única onde o jogador — um aventureiro que se define pelas escolhas que faz durante a run — precisa encontrar a escada de saída antes que o relógio da masmorra zere. Números e ícones nas células revelam pistas sobre o que existe ao redor; cada combate custa tempo; cada santuário força uma escolha de build irreversível.

Partidas curtas (10–20 min), rejogabilidade via geração procedural + builds emergentes, tensão baseada em decisão de risco em vez de reflexo.

---

## 2. Pilares de Design

1. **Decisão > Execução.** O jogo é sobre escolher bem, não clicar rápido.
2. **Informação parcial, sempre.** O jogador nunca tem certeza total — o puzzle é gerenciar dúvida.
3. **Tempo é o inimigo real.** O relógio que corre é a fonte primária de tensão, não HP.
4. **Cada run tem uma identidade.** A build emerge das escolhas; a mesma classe nunca sai duas vezes idêntica.
5. **Escopo enxuto, loop polido.** Menos conteúdo, melhor iteração.

---

## 3. Loop Principal (Core Loop)

```
Entrar na dungeon
   ↓
Revelar célula adjacente (grátis)
   ↓
Ler informação (número + ícone) das vizinhas
   ↓
Decidir: mover, entrar em combate, desviar, usar magia, abrir baú, ativar santuário
   ↓
Combate/desvio consome turnos → relógio avança
   ↓
Ganhar loot / upgrade / dano
   ↓
Repetir até: encontrar escada (vitória) | HP zera (derrota) | turnos zeram (derrota)
```

**Duração alvo:** 10–20 minutos por partida.

---

## 4. Personagem do Jogador

- Começa como **Aventureiro genérico** — sem classe definida.
- Sem escolha de kit inicial no MVP (mesmo ponto de partida sempre).
- **A classe emerge das escolhas em santuários.** Depois de 2–3 santuários, o padrão de escolhas caracteriza o herói (mago, guerreiro, ladino, híbrido…).
- Recursos base:
  - **HP** — dano físico e mágico.
  - **Mana** — magias e habilidades ativas.
  - **Turnos restantes** — o relógio da dungeon.

---

## 5. Grid e Geração da Dungeon

- **Formato:** procedural, irregular. Não é um retângulo fechado tipo Minesweeper clássico. Salas conectadas por corredores.
- **Movimento:** o herói tem uma **posição no grid** (avatar visível). Só pode revelar/entrar em células **adjacentes ou conectadas por corredor visível**.
- **Vitória:** encontrar e alcançar a **célula de escada/saída**, escondida em algum ponto.
- **Não precisa limpar a dungeon** — fugir cedo é estratégia válida.

### 5.1 Tipos de Célula (MVP)

| Tipo | Função |
|---|---|
| Piso / Corredor | Vazio, mostra pistas (números + ícones) sobre vizinhas |
| Inimigo | Encontro de combate/desvio |
| Baú | Loot: itens, ouro, poções |
| Santuário | Escolha entre 3 upgrades irreversíveis (motor da build) |
| Armadilha | Perigo estático — HP ou penalidade se pisar sem detectar |
| Escada de saída | Objetivo de vitória |

### 5.2 Sistema de Pistas (o "Minesweeper")

Cada célula de piso revelada mostra:
- **Um número** — quantidade de "coisas notáveis" nas 8 vizinhas.
- **Ícones temáticos** — indicam *tipo* do que está próximo (ex: caveira = inimigo, moeda = baú, chama = armadilha, estrela = santuário).

Trade-off intencional: mais informação por célula que o Minesweeper original, mas tabuleiro mais denso e legível. Puxa o jogo pra decisão consciente em vez de dedução matemática pura.

---

## 6. Combate e Encontros

Ao revelar um inimigo, o jogador escolhe entre:

| Ação | Custo | Efeito |
|---|---|---|
| **Enfrentar** | 1+ turnos, possível dano de HP | Vence baseado em stats/dado; ganha loot/XP |
| **Desviar** | Rolagem 2d6 vs dificuldade do inimigo | Sucesso: passa sem custo. Falha: sofre HP ou perde turnos |
| **Magia** | Mana | Efeitos variados (dano à distância, atordoar, teleporte…) |

**Regra do desviar:** não é grátis nem garantido — o teste de dado impede que o jogador simplesmente ignore todos os inimigos. Alta variação de custo real, forçando gerenciamento de risco.

**Regra do enfrentar:** é o *único* consumidor primário de turnos além do movimento. Isso significa que "limpar a dungeon" custa muito tempo — normalmente a estratégia ótima é escolher batalhas.

---

## 7. Sistema de Dado

- **2d6** como base (média 7, curva sino).
- Preferido sobre d20 por: menor variância → melhor pra partidas curtas onde uma rolagem ruim não pode "roubar" a run.
- Modificadores vindos de atributos/itens são aditivos simples.
- Rolagens visíveis ao jogador (transparência).

---

## 8. Progressão (dentro da run)

**Santuários** são o motor de build:
- Ao ativar, apresenta **3 opções** de upgrade.
- Escolha é **irreversível** dentro da run.
- Opções misturam: nova magia, +HP máx, +mana máx, arma, traço passivo, habilidade ativa.
- Frequência: dosada pra caber ~3–5 santuários por dungeon.

Sem XP e level-up clássico no MVP — evolução é toda por escolhas, não por acúmulo linear.

---

## 9. Recursos e Condição de Derrota

- **HP zera** → morte.
- **Turnos restantes zeram** → morte (a torre desaba/os guardiões despertam).
- **Mana zerada** → não morre, mas perde acesso a magias até encontrar fonte/item.

Isso cria pressão dupla: você pode sobreviver mesmo perdendo muito HP se souber administrar o tempo, ou vice-versa.

---

## 10. Setting e Tom

- **Setting:** torre/masmorra fantástica genérica. Um aventureiro entrando em ruínas antigas.
- **Estética:** pixel art clássico, 16-bit, referências a Shining Force / early Final Fantasy / clássicos SNES.
- **Escrita:** mínima. Nomes de itens, magias e inimigos com sabor D&D, sem cutscenes.
- **Áudio (aspiracional):** chiptune atmosférico, SFX curtos e limpos.

---

## 11. Escopo do MVP

Alvo de "v1 jogável" para validação do loop:

| Categoria | Alvo MVP |
|---|---|
| Inimigos | ~5 (ex: Goblin, Esqueleto, Slime, Mago sombrio, Guardião) |
| Magias | ~5 (ex: Bola de Fogo, Escudo, Teleporte, Detectar, Cura) |
| Itens | ~8 (poções, armas, anéis, pergaminhos) |
| Tipos de célula especial | 3 (Baú, Santuário, Armadilha) |
| Chefes | 1 (opcional — ou substituir por "dungeon única" no MVP) |
| Tipo de dungeon | 1 arquétipo procedural (cripta genérica) |

Regra guia: **cortar antes de adicionar**. Se não sobrevive a "isso é essencial pro loop funcionar?", fica fora do MVP.

---

## 12. Plataforma e Escopo Técnico

- **Engine:** Godot (versão a definir — provavelmente 4.x).
- **Plataforma primária:** Desktop (Windows/Mac/Linux via export do Godot).
- **Plataforma secundária (futuro):** Mobile — considerar desde o design (área de toque, UI escalável), mas não é foco de MVP.
- **Input:** Mouse + teclado. Controller e touch ficam pra fase pós-MVP.

---

## 13. Perguntas Abertas / TODO

Coisas que **ainda não decidimos** e que vão precisar de resposta antes ou durante a implementação:

- [ ] Como exatamente funciona a **geração procedural** da dungeon? (algoritmo: BSP? drunkard walk? salas pré-fabricadas conectadas?)
- [ ] Quantos **turnos iniciais** o jogador tem? (calibrar por playtest)
- [ ] **Modificadores de dado**: quais atributos existem (Força, Destreza, Inteligência…)? Ou é sistema abstrato?
- [ ] Sistema de **save**: salva runs em andamento ou só resultado?
- [ ] **Dificuldade**: um modo só, ou seletor Easy/Normal/Hard?
- [ ] **Meta-narrativa mínima**: tutorial embutido? Menu principal com lore leve?
- [ ] **Nome definitivo** do projeto (MSDD é código-nome?).
- [ ] **Chefe de dungeon**: entra no MVP ou fica pra v0.2?
- [ ] **Acessibilidade**: daltonismo (ícones + cores redundantes), tamanho de fonte, etc.
- [ ] **Balanceamento**: quantos inimigos/baús/santuários por dungeon (densidade)?

---

## 14. Próximos Passos Sugeridos

1. Prototipar o **loop mínimo** em papel/planilha: grid pequeno fixo, sem procedural, 3 células especiais, 2 inimigos, testar se a decisão "enfrentar/desviar" é interessante.
2. Definir algoritmo de **geração procedural** (item mais arriscado tecnicamente).
3. Fechar **atributos e sistema de dado detalhado** (o quanto o jogador consegue prever suas rolagens).
4. Sketch de **UI/UX** — o desafio é caber "número + ícone + estado da célula" com legibilidade.
5. Escolher versão do Godot e montar projeto base. *(feito — Godot 4.7, ver §15)*

---

## 15. Estado do Protótipo (Ago/2026)

**Escopo do protótipo.** Camada técnica isolada — Minesweeper puro com mecânica de "caça-chaves". Valida tech (grid, input, shader, timer, UI, transição de cena) antes de amarrar as camadas de D&D descritas nas §§1-11.

### 15.1 O que existe

**`menu.tscn` — menu inicial**
- Título "MSDD" + subtítulo "Minesweeper × D&D".
- Botão "1 — Caça às chaves" (atalhos `1`/`Enter`) → carrega `main.tscn` (protótipo desta §15).
- Botão "2 — Exploração (proto)" (atalho `2`) → carrega `explore.tscn` (protótipo da §16).
- Botão "3 — Cripta" (atalho `3`) → carrega `classic.tscn` (protótipo da §17).
- Botão "4 — Save the Dodo" (atalho `4`) → carrega `dodo.tscn` (protótipo da §19).
- Cada botão traz **abaixo uma descrição de 2 linhas** (fonte 15, cinza) resumindo o modo — objetivo e condição de derrota. Botão + descrição são montados pelo helper `_add_option(parent, label, description, callback)`, que empacota os dois num `VBoxContainer` próprio.
  - Caça às chaves: "Ache 5 chaves escondidas no campo antes do tempo acabar. / Um passo em falso numa bomba encerra a corrida."
  - Exploração: "Mova o cavaleiro por um mapa infinito de setores. / Cada portal abre um novo campo para revelar."
  - Cripta: "Campo minado com regras de RPG: role os dados para desarmar armadilhas. / Junte ouro e sobreviva com seus 5 pontos de vida."
  - Save the Dodo: "Abra caminho pelos quatro lados da ilha para chegar ao Dodo. / Cada anel só cede quando você o cerca por inteiro."

**`main.tscn` — cena de jogo**
- **Revelação em cascata** (desde 2026-09-29) — flood-fill e revelação de derrota abrem em onda. Ver **§18**, em especial §18.3 sobre os sprites de chave.
- Grid **24×14 landscape** (336 células), tile art 16×16 renderizado a scale 2 → 32px onscreen.
- **50 bombas** (~15% densidade).
- **First click safe + zero** — bombas plantadas depois do primeiro clique, excluindo a célula clicada + 8 vizinhas → sempre abre uma área ≥ 3×3.
- Flood-fill BFS iterativo em células vazias.
- Right-click cicla `HIDDEN → FLAGGED → QUESTIONED → HIDDEN`. Bandeira protege left-click, `?` não.
- **5 chaves coloridas** (vermelho, azul, verde, amarelo, cinza) espalhadas na dungeon:
  - Cada chave num tile não-bomba com ao menos 1 bomba adjacente.
  - Distância mínima Chebyshev ≥ 4 entre chaves (fallback 3), garantindo zero overlap de indicadores.
  - Nunca no safe zone do primeiro clique.
- **Indicador visual das chaves** via shader `tile_hint.gdshader`:
  - Tile da chave: 100% tint na cor.
  - Ortogonais adjacentes: metade da tile na cor, no lado que aponta pra chave.
  - Diagonais: quarto na tile, no canto que aponta pra chave.
- **Timer de 15s** por chave. Reseta a cada find mas **continua correndo** (não pausa).
- **Score +100** por chave achada.
- **Dramaticidade escalonada** conforme timer:
  - < 10s: cor do timer amarela.
  - < 7.5s: red overlay pulsante intensificando.
  - < 5s: cor do timer vermelha.
  - < 3s: screen shake, amplitude crescente.
- **Fim de partida** (win/lose): overlay modal com backdrop dim (55%), box centralizado com mensagem + subtítulo, botões "Voltar ao menu" e "Quit".
  - **Win:** 5 chaves → "YOU WIN!" + score final.
  - **Bomb:** clicou bomba → "GAME OVER" + "Boom!" + score.
  - **Timeout:** timer chegou a 0 → "GAME OVER" + "Tempo esgotado" + score.
  - Board revelado no lose (bombas + chaves não encontradas), tal como Minesweeper clássico.
- **Atalho `R`** reseta a partida a qualquer momento (não anunciado na UI).

**Estrutura de arquivos:**
```
msdd/
├── menu.tscn / menu.gd         # entry point
├── main.tscn / main.gd         # cena de jogo
├── tile.gd                     # Sprite2D + estado por célula
├── tile_hint.gdshader          # canvas_item shader pra hint colorido parcial
├── project.godot               # viewport 1280×720, filter nearest, main_scene = menu
└── assets/
    ├── minesweeper_tiles/      # PNG 16×16 (hidden, revealed, flags, números, bombas)
    │   └── KeyFly-Sheet.png    # sprite sheet 4 frames × 64×64
    └── Little RPG Characters/  # Human_Knight, Human_Archer (não usados ainda)
```

### 15.2 Distância do GDD conceitual

O protótipo **não é** o MSDD descrito nos §§1-11. É um teste técnico. Principais gaps:

| Aspecto | Conceito (GDD) | Protótipo |
|---------|----------------|-----------|
| Camada RPG | HP, mana, 2d6, combate, magia, santuário, classes | Nada disso ainda |
| Grid | Procedural irregular, salas + corredores | Retangular fechado 24×14 |
| Herói | Avatar visível com posição, movimento célula-a-célula | Cursor (herói implícito) |
| Objetivo | Escada de saída em dungeon procedural | 5 chaves espalhadas |
| Coisas notáveis | 4+ tipos (inimigo, baú, armadilha, santuário) + ícones | 1 tipo (bomba) |
| Tempo | Turnos discretos consumidos por ações | Timer real-time em segundos |
| Pistas | Número + ícone temático por tipo | Só número + cor de hint da chave |

### 15.3 O que foi validado tecnicamente

- Grid clickable + per-tile shader material funciona sem gargalo em Godot 4.7.
- Flood-fill em 24×14 **custa nada** — o BFS resolve o grid inteiro em um frame. (É justamente isso que permitiu a cascata do §18 ser puramente visual: o cálculo continua instantâneo, só a *apresentação* é escalonada.)
- Shader UV-region → hint colorido é **generalizável** pra múltiplos tipos de "coisa notável" (basta trocar `hint_color` por tile).
- Modal end-game com PanelContainer + CenterContainer é padrão bom, aplicável a outras telas futuras (santuário, loot, level-up).
- Transição de cena via `change_scene_to_file` é fluida.
- Setup programático de UI (sem editar `.tscn` no editor) escala bem pra prototipagem rápida.

### 15.4 Gaps notados durante o proto

- **`modulate` multiplicativo não dessatura** — a chave "cinza" ficou sutil demais. Cores neutras vão precisar de shader de luminance, não modulate.
- **Fonte padrão do Godot** é o gargalo estético mais visível. Pixel font resolveria grande parte do "cheiro de engine test".
- **Timer 15s + grid grande** é apertado — jogador mal tem tempo de escanear. Quando entrar a camada de turnos do GDD, o modelo temporal precisa ser redesenhado.
- **Chord click** (§7 do `MINESWEEPER_REFERENCE.md`) não foi implementado — pode virar relevante se o board escalar pra tamanho Expert ou se turnos ficarem caros.

### 15.5 Próximos passos (post-proto)

Sugestões pra próxima iteração, na ordem crítica:
1. ~~**Herói no grid**~~ *(feito no protótipo 2 — ver §16)*
2. **Sistema mínimo de recursos** — HP e/ou turnos. Substituir o timer real-time por turnos consumidos por movimento. Alinha com §9 do GDD.
3. **Ícones temáticos nas células** (§5.2) — trocar/complementar os números por número + ícone. Começar por 1-2 tipos além de bomba (ex: baú).
4. **Múltiplos tipos de "coisa notável"** — generalizar o placement pra suportar N tipos com contagens/hint colors separadas.
5. **Fonte pixel + refino visual** — resolver o gap estético.
6. **Chord click** — quando o board ficar denso o suficiente pra justificar.

Racional da ordem: herói + turnos é a ponte conceitual mais importante (transforma o Minesweeper em RPG). Ícones e múltiplos tipos vêm depois, quando a mecânica base tá firme.

---

## 16. Estado do Protótipo 2 — Exploração (Set/2026)

**Escopo.** Segundo protótipo, acessado pelo botão "2" do menu. Primeiro passo real em direção ao MSDD conceitual: agora o herói tem posição no grid (§4), se move célula-a-célula, e a "dungeon" começa a existir como espaço contínuo com múltiplas salas conectadas por portais.

### 16.1 O que existe

**`knight.tscn` + `knight.gd`**
- Root `CharacterBody2D` com `AnimatedSprite2D` (5 anims: idle/walk/attack/death/powerUp — só idle/walk usados por enquanto) e `CollisionShape2D` (16×17 raw).
- Script cuida de walk-along-path: recebe `Array[Vector2i]` de tiles, tween manual em `_physics_process` a `WALK_SPEED` = 120 px/s, toca "walk" durante movimento e "idle" ao parar, aplica `flip_h` pra viradas horizontais.
- Emite signal `reached_target(tile_pos)` quando path termina.
- Sprite raw 80×80, renderizado a `scale = 2` → ~72-100px onscreen (heroico sobre tile de 32px). `z_index = 10` pra sempre render acima dos tiles.

**`explore.tscn` + `explore.gd` — cena de exploração**
- Grid procedural em **chunks** de 24×14 tiles (mesmo tamanho do main.tscn).
- Cada chunk sorteia orientação de portais no spawn: **VERTICAL** (portais N/S) ou **HORIZONTAL** (portais E/W). Só 2 portais por chunk.
- Chunk inicial (0, 0): player no centro. Chunks subsequentes conectados via portais.
- Chunks **persistem** — mundo contínuo cresce à medida que jogador avança. Todos os tiles ficam no `world_tiles: Dictionary` keyed por world position.
- Bombas: **45 por chunk** (~15% do chunk; ~14,6% dos tiles sorteáveis, já que as safe zones tiram ~27 candidatos). Era 35 (~10%) até 2026-09-24 — subiu pra alinhar a pressão com os outros dois modos (50 bombas em 336 células ≈ 15%).
- Safe zones no spawn de cada chunk: portais + 8 vizinhas de cada, entry tile + 8 vizinhas, e (no chunk inicial) centro + 8 vizinhas.
- **Portais** = tiles pre-revealed com tint azul via `tile_hint.gdshader` (`hint_color` = azul, `hint_rect` = tile inteira).

**Movimento do player**
- Sem input direto de movimento. Player se move via **auto-walk** quando BFS acha corredor a um portal válido.
- BFS 4-conexo a partir da posição do knight, através de tiles revealed + non-bomb.
- Rodada de BFS acontece: (1) após reveal de tile (click), (2) após flood-fill. **NÃO** após walk completion — evita chains de walks encadeados.
- **Alvo válido de BFS** é um portal que atenda 3 condições combinadas:
  - **Distância Chebyshev > 1 do start** (evita walk trivial de 1 passo pro entry portal quando orientações alinham).
  - **Chunk adjacente ao portal ainda NÃO spawnado** (evita walk pra portais "mortos" que levam a território já explorado).
  - **Pertence geograficamente ao `current_chunk`** (chunk onde a câmera está — evita walk pra portais em chunks antigos).

**Câmera**
- `Camera2D` independente do knight, filha da cena raiz.
- Centrada no `current_chunk`. Ao chegar num portal e spawnar novo chunk, `current_chunk` muda e `camera.position` recebe o centro do novo chunk. `position_smoothing_speed = 5.0` lerpa suave.
- Player fica onde estava (não teleporta) — visualmente parece que "veio de fora" do novo chunk, aparece na borda da tela na direção de origem.

**Novo chunk ao chegar num portal**
1. `_on_knight_reached(portal_pos)` → `_try_spawn_adjacent_chunk` cria chunk adjacente (se não existe).
2. **Entry tile** do novo chunk é sempre safe + revealed. Posição = `portal_pos + direção_do_chunk` (ex: portal N de A em (12, 0) → entry em (12, -1) no chunk sul-de-A).
3. Se orientações alinham (V→V ou H→H), entry tile É o portal oposto do novo chunk. Se cruzam (V→H ou H→V), entry é só um tile safe (não portal).
4. `current_chunk` atualiza pro novo. Câmera lerpa pro centro dele.
5. Player fica parado no portal antigo até novo BFS achar corredor pra portal válido do novo chunk.

**First-click safety per chunk**
- `chunks_first_clicked: Dictionary` rastreia quais chunks já tiveram primeiro clique.
- Ao clicar pela primeira vez num chunk, se a tile clicada ou suas 8 vizinhas forem bombas, elas são movidas pra posições random (não-portal, fora do raio 1 do clique). Adjacências recomputadas globalmente.
- Cliques subsequentes no mesmo chunk têm risco normal.

**Adjacências cross-chunk**
- Bombas num chunk afetam contagem de números nos tiles de borda dos chunks adjacentes.
- `_recompute_adjacencies_around(chunk_coord)` roda em 3×3 chunks ao spawnar um novo. Se número de tile já revelado mudou, chama `_update_visual()` pra re-textura sem re-flood.

**Fim de partida**
- Único fim: clique em bomba → `_lose()`. Bombas revealed, wrong-flagged tiles marcadas.
- Overlay end reutiliza padrão do main.gd: backdrop 55% + `PanelContainer` + "GAME OVER" + subtítulo "Boom! Chunks explorados: N" + botões "Voltar ao menu" / "Quit".
- Sem vitória (modo aberto). Sem timer. Sem score.
- `R` = `reload_current_scene()` (reset total).

**UI**
- Status label top-left: `"Chunks: N"` (contador de salas exploradas).

**Revelação em cascata** (desde 2026-09-27)
- Flood-fill e revelação de derrota abrem em onda, não de uma vez. Ver **§18**.
- Consequência específica deste modo: o auto-walk do knight **espera a onda assentar** antes de traçar rota, senão ele caminha por cima de tiles ainda visualmente fechados.

### 16.2 O que foi validado tecnicamente

- **CharacterBody2D + script** de walk-along-path funcional com tween manual em `_physics_process`, sem depender de `AnimationPlayer` ou `Tween` node.
- **Chunks contínuos persistentes** em Godot 4 usando `Dictionary` global de tiles keyed por world position — sem gargalo notável até dezena de chunks explorados.
- **`Camera2D` com `position_smoothing`** dá transição suave entre chunks sem código de tween adicional.
- **Adjacência cross-chunk** limpa — flood-fill e contagem de números respeitam bordas entre chunks.
- **BFS com filtros de contexto combinados** (`current_chunk`, `unspawned adjacent`, `dist > 1`) elimina walks indesejados (trivial, pra trás, pra chunks antigos).
- **Signal-based reveal → BFS → walk** dá loop reativo sem polling.

### 16.3 Bugs enfrentados durante o desenvolvimento

Documentados aqui pra não repetir em iterações futuras:

- **`Variant + Vector2i`:** parâmetro `entry_from: Variant = null` causou erro na hora de fazer `entry_from + direction`. Fix: usar `Vector2i` tipado com sentinela `NO_CHUNK = Vector2i(INT_MAX, INT_MAX)`.
- **Typed Array em função:** passar `[a, b]` inline pra função que espera `Array[Vector2i]` falha em Godot 4 — literal cria Array untyped. Fix: declarar variável tipada primeiro (`var path: Array[Vector2i] = [a, b]`).
- **Z-index:** knight renderizando abaixo de tiles porque novos chunks são adicionados ao scene tree DEPOIS do knight (later siblings render on top). Fix: `knight.z_index = 10` — children do knight herdam via `z_as_relative` default true.
- **Player anda pra portal antigo:** BFS encontrava portais em chunks antigos ainda reachable via corredor revelado, player saía da câmera. Fix evoluído em 3 iterações: (1) `dist > 1`, (2) `leads to unspawned chunk`, (3) `portal in current_chunk`.
- **First click ainda podia matar:** proteção original só cobria o primeiro clique do run inteiro. Ao entrar num chunk novo e clicar uma bomba, morte instantânea. Fix: rastrear per-chunk (`chunks_first_clicked`).

### 16.4 Gaps notados durante o proto

- **Sem "voltar" pra chunks anteriores:** exploração é one-way. Ao entrar num chunk novo via portal, o portal oposto não escolhido do chunk anterior fica inacessível pelo BFS (excluído pelo filtro `current_chunk`). Faltaria mecânica explícita de backtrack (tecla/botão pra recentralizar câmera em chunk antigo).
- **Chord click ainda ausente.** Não é necessário sem timer, mas ao entrar mecânica de recursos limitados (turnos) vai fazer diferença.
- **Player fica visualmente na borda da tela ao entrar em chunk novo.** Semanticamente correto ("veio de fora"), mas pode confundir — usuário pode pensar que "está fora do chunk". Sinalização visual explícita (seta, glow no entry tile) resolveria.
- **Animation direcional limitada:** só walk-esquerda/direita via `flip_h`. Movimento vertical usa a mesma anim. Requer frames dedicados no sprite sheet ou aceitar limitação.
- **Não tem vitória:** modo aberto pode virar meta-jogo "explore N chunks" ou "encontre o boss no chunk (X, Y)" quando decidirmos condição de fim.
- **Sem HP, mana, combate — nada de RPG ainda.** Bomba = morte instantânea (mesmo que no proto 1).

### 16.5 Comparação com GDD conceitual

Atualização da tabela §15.2:

| Aspecto | Conceito (§§1-11) | Proto 1 (§15) | Proto 2 (§16) |
|---------|-------------------|----------------|-----------------|
| Herói no grid | Avatar com posição, movimento | Cursor implícito | ✅ Knight visível, tile-a-tile |
| Grid | Procedural irregular | 24×14 fixo | 24×14 por chunk, mundo contínuo |
| Objetivo | Escada de saída | 5 chaves na mesma sala | Exploração aberta |
| Coisas notáveis | Inimigo/baú/armadilha/santuário | Bombas + 5 chaves coloridas | Bombas + portais |
| Tempo | Turnos discretos por ação | Timer 15s por chave | Sem timer |
| Camera/mundo | Um espaço explorável | Fixo, uma tela | Contínuo, câmera transita |

Proto 2 é o primeiro passo real em direção ao MSDD. Herói ✅. Movimento ✅. Mundo contínuo ✅. Falta: **turnos, HP, tipos de célula variados, sistema de dado, combate.**

### 16.6 Próximos passos (post-proto-2)

1. **Sistema de turnos** — cada tile andado consome 1 turno. Contador global regride. Zerar = morte. Substitui o "timer 15s" do proto 1 conceitualmente.
2. **HP** — knight tem HP. Bomba causa dano em vez de morte instantânea (ou mantém morte + adiciona HP pra combates futuros).
3. **Tipos de célula extras** — introduzir baú (revela → item/score), armadilha (revela → dano). Mesmo padrão técnico dos portais: tile pre-revealed com sprite/tint distinto, ou reveal-triggered com ícone.
4. **Backtrack via UI** — tecla ou botão pra "voltar câmera pra chunk anterior" e permitir escolher o portal não escolhido.
5. **Anim direcional** — dedicar frames de walk_up/walk_down se existirem no sprite sheet.
6. **Unificar `main.tscn` e `explore.tscn`** — quando as duas mecânicas convergirem (turnos + herói + múltiplos tipos), fará sentido só uma cena "game.tscn" com toda a lógica. Proto 1 pode virar tutorial ou modo especial.

Racional: turnos + HP são a base do RPG. Sem eles, o proto 2 é só "exploração livre" — que já validou tech mas não valida a experiência do MSDD.

---

## 17. Estado do Protótipo 3 — Cripta (Set/2026)

**Escopo.** Terceiro protótipo, acessado pelo botão "3" do menu. Um Minesweeper com sabor **cozy-D&D**: mesmas mecânicas base (grid, armadilhas, first-click-safe, flood-fill, flags), mas com uma camada RPG mínima em cima — HP + dado 2d6 + ouro — que remove o "instakill" clássico e transforma cada armadilha numa **decisão de risco negociada por dice roll**. Primeiro protótipo a exercitar o sistema de dado do §7 do GDD conceitual.

### 17.1 O que existe

**`classic.tscn` + `classic.gd` — "Cripta"**
(nome de arquivo mantido do protótipo anterior de Minesweeper puro; semantics reescrita)

- Grid 24×14 (mesmo do main.gd), 50 armadilhas (~15%), first-click safe.
- Right-click cicla `HIDDEN → FLAGGED → QUESTIONED → HIDDEN`.
- Flood-fill em zeros, cada tile seguro revelado dá **+1 ouro**.
- **HP** inicial 5, sem regen.
- **Ouro** acumulativo, sem gasto (métrica final).
- **Dado 2d6 vs dificuldade fixa 7** ao clicar armadilha:
  - **Sucesso (roll ≥ 7, ~58%):** armadilha desarmada. Tile vira safe (`is_bomb = false`), adjacências vizinhas recomputam, cascata pode disparar. +5 ouro bonus além do +1 do reveal.
  - **Falha (roll < 7, ~42%):** armadilha dispara. Dano = margem de falha, capado 1-3. Tile fica revealed com `TEX_EXPLODED`, mas `is_bomb` permanece `true` (contadores dos vizinhos não mudam). Sem ouro.
- **Fim de partida:**
  - **Vitória:** todos os tiles não-armadilha revelados → "AVENTURA COMPLETA" + ouro final + HP restante.
  - **Derrota:** HP zera → **"VOCÊ RECUA"** (deliberadamente cozy — evita "GAME OVER"). Armadilhas restantes reveladas visualmente. Ouro coletado exibido.
- **Revelação em cascata** (desde 2026-09-27) — flood-fill e revelação de derrota abrem em onda a partir do tile clicado. Ver **§18**.
- **Log narrativo** bottom-center em cor pergaminho (`Color(0.95, 0.88, 0.72)`):
  - Início: "Você entra na cripta."
  - Sucesso: "Você desarmou a armadilha (rolou N vs 7). +6 ouro."
  - Falha: "A armadilha disparou (rolou N vs 7). -N HP."
- **Status label** top-left: `HP: 5/5    Ouro: 0    Armadilhas: 50`.
- Overlay end padrão do projeto (backdrop 55% + PanelContainer + menu/quit).
- `R` reset.

### 17.2 Design intents

- **Cozy porque:** o dado tira o instakill. "GAME OVER" vira "VOCÊ RECUA" (softer, narrativo). Log em tom pergaminho warm. Ouro é sempre positivo — nunca perde. Sem timer, sem pressão temporal, sem screen shake.
- **D&D porque:** dado 2d6 vs dificuldade — coração do sistema do §7 do GDD. HP como recurso finito. Vocabulário ("armadilha", "cripta", "expedição", "desarmar", "recuar") puxa fantasia.
- **Simples porque:** apenas UMA mecânica nova casada em cima do minesweeper base (o dado no clique de armadilha). Todo o resto (números, flags, flood-fill, first-click-safe) permanece intacto.

### 17.3 O que foi validado tecnicamente

- **Loop 2d6 + damage margem + HP** funciona como base pro §7 do GDD. Números 6-8 sentem justos.
- **Ouro como métrica gratificante contínua** dá loop de dopamina sem punição — cada clique seguro é celebrado.
- **Log label com cor override warm** cria mood cozy sem custo (só um `Label` + `add_theme_color_override`).
- **Reaproveitamento de mecânicas base** — 90% do código veio do `main.gd` sem chaves/timer/drama. Confirma que a arquitetura de tiles + shader é flexível pra variantes de gameplay.
- **`_recompute_neighbors_of(pos)`** após desarme resolve limpo o problema de "adjacências ficam desatualizadas quando bombas mudam de status".

### 17.4 Gaps notados

- **Difficulty 7 pode ser generoso demais** — ~58% de sucesso deixa jogador esperto tanquear várias armadilhas com confiança. Pra mais tensão, testar 8 (~42%).
- **Sem visual de dado rolando** — só texto no log. Ausência do "clatter" enfraquece o momento D&D. Animação de d6 na tela + som resolveria.
- **Sem penalidade estratégica por errar** — só dano. Sem "shock" (1 turno sem clicar), sem modifier negativo na próxima rolagem, sem desabilitar flags temporariamente. Deixa a decisão rasa.
- **Ouro não gasta** — puramente métrica final. Naturalmente pede loja entre runs ou score persistente entre sessões. Sem isso, incentivo pra maximizar é fraco.
- **Sem regen de HP** — armadilhas erradas se acumulam sem recuperação. Pra runs mais longas (multi-dungeon), precisaria fonte de cura.
- **Log some rapidamente** — cada nova ação sobrescreve. Player pode perder texto se clicar rápido. Fila/scroll de mensagens ou fade-out resolveria.

### 17.5 Direções alternativas consideradas (possíveis próximos protótipos)

Duas outras variações **cozy-D&D** foram propostas no brainstorm da §17 mas ficaram fora do protótipo atual. Ficam registradas como possíveis próximos testes:

**A. "Cartógrafo pacato"** — pressão zero, foco puro em descoberta.
- **Sem condição de derrota nenhuma.** Player é um cartógrafo mapeando ruínas antigas.
- Cada célula revelada gera **flavor text curto** ("Você encontra poeira num canto", "Um brilho fraco atrás da parede", "Pegadas de goblin", "Um pergaminho gasto"). ~50 linhas fixas + sample aleatório resolvem MVP.
- Armadilhas viram "quartos perigosos" que player marca com flag e evita — **não ferem**.
- Números continuam indicando adjacência de coisas notáveis.
- **Endgame** = mapa completo + journal narrativo pra ler no final.
- **Cozy nível máximo.** Requer database de flavor text mas é o mais fácil de escrever depois de estruturado.

**B. "Buscador de ervas"** — loop de coleta com recompensa visual.
- **10-15% das células seguras contêm ervas / moedas / relíquias** com sprites distintos.
- Score = valor total coletado (categorias diferentes de item = valores diferentes).
- Armadilhas ainda matam (single run, sem HP/dado — ou opcionalmente com HP do proto 17).
- **Dopamine loop:** cada clique tem chance de "pop" visual + som de coleta.
- Puxa mecânica de coleta tipo Stardew mining / Animal Crossing.
- **Requer arte adicional** (sprites de itens colecionáveis) mas fica visualmente satisfatório rápido.

Cada variante testa um **vetor cozy diferente**:
| Variante | Vetor testado | Complexidade | Requer |
|----------|---------------|--------------|--------|
| Cripta (§17 atual) | Dado + RPG stats | Média | Nada extra |
| A. Cartógrafo pacato | Narrativa + descoberta | Baixa | Database de texto |
| B. Buscador de ervas | Coleta + arte | Média | Sprites de itens |

Rodar múltiplas variantes pode informar qual eixo escala melhor pro MSDD real (ou dar ideias pra combinar — ex: "cripta com flavor text").

### 17.6 Próximos passos (pra Cripta ou variantes)

Sugestões pra iterar sobre o §17 atual OU tentar as variantes 17.5:

1. **Playtest de difficulty** — testar 6, 7, 8 no dado e ver qual sente melhor. Provavelmente 8 mais tenso.
2. **Animação de dado** — sprites de d6 rolando + som ao clicar armadilha. Reforça o momento D&D.
3. **Loja / gastar ouro** — dar propósito ao ouro. Poções de HP, "escudo" pro próximo dado, mapa parcial revelador, etc.
4. **HP potions dropadas** — 1-2 células com "poção" que dá +1 HP ao revelar. Recurso descoberto no board.
5. **Journal narrativo** (empréstimo da variante A) — cada evento importante entra num log persistente que player pode revisar.
6. **Sprites de dado + coração no HUD** — trocar texto por ícones. Ganho estético grande.
7. **Prototipar variante A ("Cartógrafo pacato")** — como cena separada, testar se "pressão zero" tem apelo mesmo sem competição/desafio.
8. **Prototipar variante B ("Buscador de ervas")** — se conseguir sprites, o loop de coleta é o mais viral/redes-sociais das três.

---

## 18. Cascata de revelação (Set/2026)

**Escopo.** Primeira camada do projeto puramente **estética** — não muda regra, número ou condição de vitória nenhuma. Implementada nos **quatro protótipos** (2 e 3 em 2026-09-27, o 1 em 2026-09-29, e o 4 já nasceu com ela). O ritmo vive todo em `tile.gd`, então todos compartilham a mesma linguagem visual.

**A ideia:** ao clicar num tile, os tiles não abrem todos no mesmo frame. Eles abrem em **anéis**, com atraso crescente conforme a distância do clique — a cripta parece se abrir, em vez de simplesmente aparecer.

### 18.1 Como funciona

**Separação lógica/visual.** O ponto central da implementação: `Tile.reveal(delay)` muda o **estado lógico na hora** (`REVEALED`, ouro contabilizado) e só **escalona a apresentação**. Enquanto a onda não chega, o tile carrega `reveal_pending = true` e o sprite segue mostrando o que estava na tela antes.

Isso foi deliberado. A alternativa — atrasar o estado lógico junto — dessincronizaria win check, contagem de ouro, pathfinding e bloqueio de re-clique da animação, criando uma janela em que o jogo e a tela discordam. Do jeito atual, a única consequência observável é que clicar num tile que já abriu logicamente mas ainda não visualmente não faz nada, o que é inofensivo e até previne double-click acidental.

**Onda de abertura (flood-fill).** O BFS do flood-fill passou a carregar a **profundidade** (o anel) junto de cada posição. Como BFS garante que o primeiro visitante de um tile chega pelo caminho mais curto, cada tile recebe o menor anel possível. O atraso vem de `Tile.cascade_delay(ring)`.

Efeito colateral que ficou melhor do que o planejado: a onda se propaga **pelo próprio caminho aberto**, então ela **contorna as paredes de números** em vez de ser um círculo geométrico. Lê como a cripta se abrindo, não como um efeito sobreposto ao grid.

**Onda de derrota.** A revelação final das bombas irradia do **epicentro** em anéis de **Chebyshev**, via `Tile.defeat_delay(ring)`. O epicentro depende do modo: a armadilha que zerou o HP (§17), a bomba pisada (§15, §16 e §19) ou — quando o tempo esgota no §15, que não tem bomba culpada — o **último tile clicado**, porque é onde a atenção do jogador estava. Aqui não há caminho aberto pra seguir, então a onda é geométrica mesmo. Ritmo próprio, mais lento que o do flood (a função aqui é dramática, não informativa), com teto de atraso pra não fazer o jogador esperar num mundo grande — no protótipo 2 as bombas de chunks distantes caem no teto e abrem juntas, mas estão fora da tela de qualquer forma.

**Overlays esperam a onda.** "YOU WIN!", "AVENTURA COMPLETA", "VOCÊ RECUA", "GAME OVER", "DODO LIVRE!" e "O DODO CONTINUA PRESO" — todos os fins de partida dos quatro modos — só aparecem depois que o último tile assenta. Sem isso, a tela de fim cobriria justamente a animação mais bonita do jogo.

### 18.2 Números (todos em `tile.gd`)

| Constante | Valor | O que controla |
|-----------|-------|----------------|
| `OPEN_DURATION` | 0.16s | Duração do "pop" de um tile |
| `OPEN_SCALE_FROM` | 0.82 | Escala inicial (tile cresce até 1.0) |
| `OPEN_SCALE_PUNCH` | 1.06 | Overshoot antes de assentar |
| `OPEN_FLASH` | `Color(1.55, 1.45, 1.25)` | Clarão warm no instante da abertura |
| `CASCADE_STEP` | 0.032s | Atraso por anel no flood-fill |
| `CASCADE_JITTER` | 0.012s | Quebra do ritmo de metrônomo |
| `DEFEAT_STEP` | 0.045s | Atraso por anel na onda de derrota |
| `DEFEAT_MAX_DELAY` | 1.1s | Teto de atraso da onda de derrota |

O ritmo vive **todo em `tile.gd`**, não duplicado nas cenas — afinar num lugar afeta os quatro protótipos. `CASCADE_JITTER` é mantido **abaixo** de `CASCADE_STEP` de propósito: acima, o jitter inverteria a ordem dos anéis e a onda perderia a direção.

No grid 24×14, a maior cascata possível dá ~0.8s de ponta a ponta.

### 18.3 Detalhes que exigiram cuidado

- **Pivô do pop.** `Sprite2D` não tem `pivot_offset`, e os tiles são `centered = false`. Escalar do canto faria o tile "fugir" pra baixo-direita. A escala compensa a posição na mão (`_set_open_progress`).
- **Overshoot cortado pelos vizinhos.** Durante o pop o tile sobe de `z_index` — sem isso, o overshoot de 1.06 fica escondido atrás dos tiles irmãos desenhados depois.
- **Extensão da onda durante a espera** (protótipo 2). Um clique novo enquanto a onda corre **estende** o prazo, mas o timer já criado dispararia no prazo antigo — e o knight andaria em cima da onda nova. `_after_cascade` se **reagenda** ao acordar, reconsultando o prazo, em vez de disparar cego. Nos protótipos 1 e 3 isso não pode acontecer — lá a espera só existe pra cobrir a tela de fim de partida, e a partir daí os cliques já estão bloqueados —, então eles usam um `_show_end_after_cascade` mais simples, de disparo único.
- **Reset no meio da onda.** Nos protótipos 1 e 3, `R` reinicia a partida sem recriar a cena, então um timer pendente sobreviveria ao reset e dispararia num jogo novo — overlay fantasma no §17, e no §15 também um sprite de chave da partida anterior. Um `run_id` incrementado a cada run descarta esses timers. O protótipo 2 não precisa disso: lá o `R` chama `reload_current_scene()` e a cena inteira morre junto com os timers.
- **O shader engolia o `modulate` — bug encontrado só em 2026-09-30.** `tile_hint.gdshader` terminava com `COLOR = tex;`, onde `tex` era um `texture(TEXTURE, UV)` cru. Em Godot 4 o `COLOR` do fragment **já chega multiplicado pelo `modulate` do nó**, então sobrescrevê-lo daquele jeito descartava a modulação inteira, silenciosamente. Consequência: **o clarão de abertura nunca apareceu em protótipo nenhum** desde que a cascata foi escrita — o pop de escala funcionava (não passa pelo shader) e mascarou a ausência. O tingimento de zona do §19 também não aparecia, e foi por ele que o bug apareceu. Correção: não sobrescrever `COLOR`, só aplicar o hint por cima (`COLOR.rgb *= hint_tint.rgb`). **Lição:** um shader que escreve `COLOR = <algo montado do zero>` está optando por fora de tudo que o CanvasItem já calculou — `modulate`, `self_modulate` e o modulate dos ancestrais.
- **Textura durante a pendência.** Um tile com bandeira errada mantém a **bandeira** até a onda chegar, não volta pra tampa. Por isso `_pending_prev_texture` guarda o que estava na tela em vez de assumir `TEX_HIDDEN`.
- **Sprites de chave** (protótipo 1). O maior ajuste que a cascata exigiu no §15: a chave é um `AnimatedSprite2D` *em cima* do tile, então ela apareceria flutuando sobre uma tampa fechada. Agora o sprite espera o tile dela abrir, consultando `Tile.time_until_open()`. O **score e o reset do timer de 15s continuam imediatos** — a animação não pode cobrar tempo de um modo cronometrado. Na derrota, as chaves perdidas surgem conforme a onda passa por cada uma.
- **Indicadores de chave via shader** (protótipo 1). Os tints de `tile_hint.gdshader` entram junto com o pop de cada tile, porque `_update_visual()` só roda quando a onda chega. O ganho foi inesperado: os 5 rastros coloridos se desenham progressivamente em vez de aparecerem todos num frame. Era o risco que tinha feito o §15 ficar de fora na primeira leva — na prática a cascata **melhorou** essa leitura.
- **Timer real durante a onda** (protótipo 1). O relógio de 15s **não pausa** enquanto a cascata corre, e o tempo pode esgotar no meio de uma. Isso é proposital: a animação é enfeite, não estado de jogo. O `_timeout` no meio de uma cascata simplesmente estende o prazo da onda e o overlay espera as duas.

### 18.4 O que ficou de fora

- **Spawn de chunk (§16)** — portais e entry tile de um chunk novo abrem instantâneos, porque a câmera está deslizando pra lá ao mesmo tempo. Um pop leve ali é um argumento em cada `reveal()`, se valer.
- **Som** — a onda pede um tick por anel (ou por tile, com voice limit). Hoje o projeto não tem áudio nenhum; esse é o gap mais óbvio dessa camada.
- **Screen shake na derrota** — combinaria com a onda irradiando, mas os modos discordam: o §15 **já tem** shake (escalando nos últimos 3s do timer, em `_update_dramatic_effects`), enquanto o §17.2 registra "sem screen shake" como decisão cozy deliberada. Ou seja, isso é decisão **por modo**, não global — e no §15 o shake para no instante da derrota, deixando a onda correr numa tela estável. Fica como tensão de design a resolver, não como esquecimento.

---

## 19. Estado do Protótipo 4 — Save the Dodo (Set/2026)

> 👉 **Decisões em aberto esperando playtest: §19.5.** É o painel de ajuste deste protótipo — cada item traz o que está valendo hoje, o sinal que indica qual caminho tomar e onde mexer no código.

**Escopo.** Quarto protótipo, botão "4" do menu. Testa **um eixo de design que nenhum dos outros toca: progressão espacial obrigatória**. O jogador não escolhe onde cavar — precisa cercar o objetivo por inteiro antes de poder se aproximar dele. As mecânicas de minesweeper (bombas, números, flood-fill, flags) ficam intactas embaixo; o que é novo é o **gating por zona e quadrante** montado em cima.

### 19.1 O que existe

**`dodo.tscn` + `dodo.gd`**

- Grid **71×35 = 2485 casas** (7× o dos outros protótipos), com tiles de **16px** onscreen — `SCALE_FACTOR = 1`, metade do tamanho dos demais modos, pra caber 1136×560px numa viewport de 1280×720.
- **Dimensões ímpares de propósito:** garantem um tile central exato, que é onde o Dodo fica (35, 17).
- **372 bombas** (~15%, mesma densidade dos outros modos).
- O **Dodo** é um `AnimatedSprite2D` (4 frames de 16×16, placeholder de galinha do Farm RPG pack) sempre visível no centro, sobre um tile tingido de dourado. A casa dele nunca é clicável nem revelada pelo flood.
- **3 zonas concêntricas**, de fora pra dentro: **Orla** (1404 casas), **Mata** (828), **Clareira** (253).
- **Condição de vitória:** revelar qualquer casa **ortogonalmente adjacente** ao Dodo. O Dodo e as 8 casas em volta nunca recebem bomba — se um dos quatro lados fosse mina, a vitória seria inalcançável em segurança.
- **50 moedas** *(2026-10-02, primeiro passo)* — sorteadas **depois** das bombas, entre as casas que sobraram, pelo mesmo método (shuffle de candidatas). A casa do Dodo fica de fora porque nunca é revelada. Ao abrir uma casa com moeda, ela **salta, gira no ar e some**; nada fica na casa, e o registro da coleta é o contador no HUD. O salto é uma **parábola integrada de verdade**, não trechos encadeados com easing escolhido a dedo: a moeda sai com uma velocidade, a gravidade a traz de volta, e ela quica devolvendo uma fração da velocidade de impacto. O voo termina no apogeu do quique, onde ela se apaga. Duas coisas saem de graça dessa escolha:

  1. **O easing é exato, não aproximado.** A desaceleração na subida e a aceleração na queda são a física, então o *hang time* no apogeu e o peso da queda aparecem sozinhos, sem precisar escolher curvas que os imitem.
  2. **A duração emerge dos parâmetros em vez de ser imposta** — e é isso que torna a variação elegante. Não se sorteia "duração" nem "altura" separadamente: sorteia-se o impulso, o peso e a elasticidade, e tudo o mais decorre de forma **coerente entre si**. A moeda que sobe mais alto também fica mais tempo no ar, porque é o que aconteceria.

  Varia por moeda: impulso (±20%), gravidade (±18%), restituição (0,55–0,92), deriva lateral (±16px, linear no tempo, já que não há força horizontal) e velocidade do giro (0,60×–1,70×). O resultado é **0,8s a 1,9s** de duração e apogeus de 21px a 67px — uma razão de 2,5× entre o voo mais curto e o mais longo.

  As faixas são largas de propósito. O que mais denuncia repetição num punhado de moedas não é a duração total, é o **instante do impacto**: quando todas quicam no mesmo frame, lê-se como uma animação tocada cinco vezes. Numa amostra de seis moedas coletadas juntas, o quique se espalha por meio segundo (0,65s a 1,15s), o que basta pra elas se dessincronizarem sozinhas.

  *(Calibrado em duas rodadas: a primeira versão ficou longa demais — até 2,7s — e com variação estreita demais. Baixar a base e alargar as faixas são ajustes que puxam em direções opostas no tempo máximo, então a gravidade subiu bastante pra abrir espaço pra amplitude.)* O fade só começa depois que a segunda subida já pegou altura, senão a moeda some antes de ficar claro que quicou. Por ora as moedas **não fazem nada** além de contar: não há gasto, bônus nem efeito no gating.
  - **Desenhada em código, e desenhada girando.** Não há sprite de moeda utilizável no projeto (as "Gold Stones" do Tiny Swords são 128×128 e borrariam num tile de 16px). São 8 quadros de 15×15 gerados no boot, num giro completo em torno do eixo vertical.
  - O **volume** vem de três coisas somadas, não de sombreamento isolado: (1) a largura aparente encolhe com o cosseno do ângulo; (2) a face de trás recebe menos luz, então o quadro "largo" do verso é visivelmente mais escuro que o da frente — é isso que faz o giro ser lido como giro, e não como a moeda piscando; (3) quando passa de perfil, o que sobra é a **espessura** dela (`COIN_HALF_THICKNESS`), que impede o quadro de 90° de simplesmente sumir.
  - Quatro tons na face (brilho / corpo / sombra / contorno) com a luz vindo do canto superior-esquerdo, mais um quinto tom pra lateral.
  - Cada moeda começa o giro num **quadro aleatório**, pra que duas coletadas juntas não girem em uníssono.
  - A coleta é **agendada pela onda de revelação** (via `Tile.time_until_open()`), não pelo instante lógico: num flood grande as moedas saltam conforme a onda passa por elas, em vez de todas de uma vez antes de a tela mostrar o porquê.
  - Distribuição resultante, por ser proporcional à área: ~28 na Orla, ~17 na Mata, ~5 na Clareira.
- **Derrota:** clicar numa bomba. Revelação final irradia da bomba pisada (§18).
- `R` reset, overlay de fim padrão do projeto, log narrativo em tom verde-folha.

**O gating (a mecânica nova)**

- Começa só com a **Orla** clicável. O tingimento das casas (`Tile.base_tint`) carrega **duas informações ao mesmo tempo** — ver §19.2, "As zonas precisam ser visíveis, não só existir".
- Pra abrir a zona seguinte, o jogador precisa ter revelado **ao menos uma casa em cada um dos 4 quadrantes** da zona atual. Quadrante é medido em relação ao Dodo (NO/NE/SO/SE), não à tela.
- Ao abrir uma zona, o contador de quadrantes **zera** — a Mata exige os seus próprios quatro, e assim por diante.
- A **Clareira não tem gating de saída**: é a última, então lá é só chegar ao Dodo.
- O HUD mostra a zona atual e quais quadrantes já caíram.

### 19.2 Decisões de implementação que não eram óbvias

**Zonas em distância normalizada, não Chebyshev.** Anéis de Chebyshev puro num grid 71×35 ficariam quadrados: o anel externo sobraria só nas laterais, porque a distância vertical ao centro (17) se esgota muito antes da horizontal (35). A distância usada é `max(|dx|/35, |dy|/17)` — 0 no Dodo, 1 na borda — então os anéis acompanham a proporção do grid e a Orla é uma moldura de espessura visualmente constante.

**O flood-fill não atravessa a fronteira da zona.** Sem isso o gating não existiria na prática: um flood grande na Orla vazaria pra dentro e entregaria a Clareira de graça. O BFS descarta qualquer casa de zona ainda bloqueada.

**First-click safe só na primeira casa da partida** *(decisão revista em 2026-10-02)*. A primeira versão protegia o primeiro clique de cada uma das 12 regiões (3 zonas × 4 quadrantes), como o protótipo 2 faz por chunk (§16.3). O raciocínio era: o gating obriga a abrir os quatro quadrantes, o quadrante seguinte fica longe de qualquer número revelado, logo o jogador seria forçado a clicar às cegas — e doze cliques cegos a 15% dão ~14% de sobrevivência.

**Esse raciocínio partia de uma premissa errada sobre como se joga o modo.** Ele assumia que o jogador *teleporta* para o próximo quadrante com um clique cego. Com só a primeira casa protegida, ele não pode: precisa **cavar até lá**, expandindo a área segura pelos números, como num minesweeper comum. O risco deixa de ser "12 apostas de 15%" e passa a ser o risco normal de dedução, que é o do jogo todo.

E isso **conserta o gating**, que era o risco de design nº 1 deste protótipo (§19.3): cumprir quadrante deixa de ser "clicar quatro vezes em cantos aleatórios" e vira "estender meu território até alcançar os quatro lados". O gating passa a medir alcance conquistado em vez de cliques gastos — que era exatamente a diferença entre tensão e burocracia.

O preço é que o modo fica **bem mais difícil e mais longo**: atravessar 2485 casas deduzindo, da borda ao centro, sem errar uma vez. É uma escolha deliberada de identidade — ver §19.5 item 2, que fica mais sensível por causa disto.

**Tingimento por `Tile.base_tint`.** Escurecer as zonas bloqueadas com `modulate` direto brigaria com a animação de abertura do §18, que também mexe em `modulate`. O `Tile` ganhou um `base_tint` que multiplica tudo que ele desenha, e o clarão do pop passou a ser `OPEN_FLASH * base_tint` em vez de branco absoluto — senão abrir um tile "acenderia" temporariamente uma casa que deveria estar apagada. Default branco, então os outros três protótipos não mudam.

**A zona acende de fora pra dentro.** Ao ser liberada, a zona não troca de cor num frame: um tween de 0.55s varre o tint da borda externa dela pra dentro, na mesma linguagem da cascata do §18. O sweep itera só as casas daquela zona (pré-computadas em `zone_members`), não o grid inteiro.

**As zonas precisam ser visíveis, não só existir.** A primeira versão pintava só dois estados — liberado (branco) e bloqueado (cinza) — e nisso as três zonas eram invisíveis: o jogador via "onde posso clicar" e nada da estrutura em anéis que rege o modo inteiro. O tingimento passou a carregar **dois eixos**:

1. **Cor por zona**, formando um gradiente da borda pro centro: Orla fria e escura (mata fechada), Mata neutra, Clareira quente e clara (a luz onde o Dodo está).
2. **Véu de bloqueio**, um multiplicador aplicado por cima dessa cor.

O véu é multiplicativo, e não uma cor fixa, justamente pra preservar o eixo 1 debaixo dele — com cor fixa, Mata e Clareira ficariam idênticas enquanto ambas estão fechadas, que é o estado do começo da partida. E o multiplicador **varia por zona** (0.42 / 0.46 / 0.56, mais fraco quanto mais fundo): a Clareira "brilha através" da névoa, como uma luz distante. Com um véu único os dois anéis apagados ficavam separados por só 0.06 de luma — na prática uma massa escura só.

Contraste resultante, em luma:

| Fronteira que o jogador vê lado a lado | Δ luma |
|---|---|
| Orla liberada vs Mata bloqueada | **+0.390** |
| Mata liberada vs Clareira bloqueada | **+0.350** |
| Mata bloqueada vs Clareira bloqueada (início de partida) | +0.164 |
| Orla liberada vs Mata liberada | +0.124 |
| Mata liberada vs Clareira liberada | +0.123 |

As duas primeiras linhas são o que responde "posso clicar aqui?", e por isso são as maiores por uma margem larga: a leitura de zona nunca compete com a de disponibilidade.

### 19.3 O que este protótipo testa que os outros não

| | Eixo testado |
|---|---|
| §15 Caça às chaves | Pressão de tempo + busca por alvos dispersos |
| §16 Exploração | Mundo contínuo + herói que anda |
| §17 Cripta | Risco negociado por dado + HP |
| **§19 Save the Dodo** | **Progressão espacial obrigatória — você não escolhe onde cavar** |

A pergunta que ele responde: **forçar o jogador a cercar o objetivo cria tensão interessante ou só burocracia?** O risco é a segunda: cumprir quadrante pode virar "clicar quatro vezes em cantos aleatórios e seguir". O sinal de que funcionou é o jogador começar a **planejar a ordem** dos quadrantes — abrir primeiro o que parece mais seguro, guardar o pior pro fim, usar os números da fronteira pra escolher por onde encostar na zona seguinte.

### 19.4 Estado de validação

**Nada aqui rodou.** O Godot não estava instalado na máquina da sessão em que este protótipo foi escrito — ele passou só por revisão de código e checagem de indentação/sintaxe. Toda a §19.5 é, portanto, hipótese fundamentada, não observação.

Dois fatos (não hipóteses) sobre o estado atual:

- **O Dodo é uma galinha.** Placeholder 16×16 do Farm RPG pack. Não existe sprite de dodo no projeto.
- **Este é o maior grid do projeto por uma larga margem:** 2485 casas contra 336 dos protótipos 1 e 3. Vários números herdados dos outros modos foram escolhidos para grids 7× menores — é daí que vem a maior parte da §19.5.

### 19.5 Painel de decisões — levar pro playtest

Cada item abaixo é uma decisão em aberto, com o que está valendo hoje, o sinal que indica qual caminho tomar, e onde mexer. **Ordem de prioridade:** 1-3 provavelmente precisam de ajuste; 4-7 dependem do que o playtest mostrar; 8-9 são de produto, não de balanceamento.

---

**1. Ritmo da cascata neste grid — o mais provável de incomodar**

- **Hoje:** `CASCADE_STEP = 0.032s` por anel, sem teto. Herdado dos grids 24×14.
- **O problema:** num grid 71×35 o flood alcança anéis muito maiores. E o overlay de fim de partida **espera a cascata inteira** (§18), então uma vitória depois de um flood grande trava a tela por segundos.

| Tamanho do flood | Duração da onda |
|---|---|
| grid 24×14, flood máximo (protótipos 1-3) | 0.90s |
| Dodo, flood de 20 anéis | 0.80s |
| Dodo, flood de 35 anéis (meia tela) | **1.28s** |
| Dodo, flood de 60 anéis | **2.08s** |
| Dodo, teórico máximo | **2.40s** |

- **Sinal:** se abrir uma área grande der sensação de espera em vez de espetáculo, é isto.
- **Opções:** (a) dar à cascata um teto como o da onda de derrota — existe `DEFEAT_MAX_DELAY`, falta o equivalente em `cascade_delay`; (b) `CASCADE_STEP` menor só neste modo, o que exige tirar o ritmo de `tile.gd` e parametrizá-lo por cena; (c) atraso proporcional à raiz do anel em vez de linear, comprimindo as pontas sem achatar o começo.
- **Onde:** `tile.gd`, `CASCADE_STEP` e `cascade_delay()`. Cuidado: hoje esse ritmo é **compartilhado pelos quatro protótipos** (§18.2) — mexer direto ali afeta todos.

---

**2. Densidade de bombas**

- **Hoje:** 15% (372 bombas), a mesma dos outros três modos.
- **Por que pode estar errado:** desde que a proteção por região saiu (item 3), este é **o** botão de dificuldade do modo. O jogador atravessa 2485 casas deduzindo, da borda ao centro, e um único erro encerra — é muito mais exposição acumulada que nos outros modos, onde o board tem 336 casas.
- **Sinal:** morrer repetidamente antes da Mata; ou chegar à Clareira sentindo que foi sorte, não leitura.
- **Opções:** baixar para 10-12%; ou densidade **crescente por zona** (Orla mansa, Clareira perigosa), que transforma a aproximação em tensão em vez de repetição.
- **Onde:** `dodo.gd`, `BOMB_DENSITY`. A versão por zona exige mudar `_place_bombs` para sortear por `zone_members`.

---

**3. ~~First-click safe por região~~ — RESOLVIDO em 2026-10-02: removido**

- **Decidido:** só a **primeira casa da partida** é protegida. A exploração é feita casa a casa, cavando pelos números até alcançar cada quadrante. Ver §19.2 pro raciocínio completo.
- **Fica de olho em:** se o modo se mostrar longo e punitivo demais, o ajuste agora é a **densidade** (item 2), não voltar a proteção — a proteção por região era o que tornava o gating burocrático.

---

**4. O gating tem peso ou é burocracia? — a pergunta central do protótipo**

- **Hoje:** uma casa revelada por quadrante libera a zona seguinte.
- **Sinal de que funcionou:** você se pega **planejando a ordem** dos quadrantes — abrir primeiro o que parece seguro, guardar o pior pro fim, usar os números da fronteira pra escolher por onde encostar.
- **Sinal de que falhou:** você clica quatro vezes em cantos aleatórios sem pensar e segue. *(A remoção da proteção por região em 2026-10-02 deve ter matado esse cenário — clicar em canto aleatório agora é 15% de morte, então não há atalho barato. Vale confirmar no playtest se o gating ganhou peso de verdade.)*
- **Opções se falhar:** exigir **duas** casas por quadrante; exigir uma casa **por quadrante e por sub-anel**; ou casar com a densidade crescente do item 2, que faz cercar ficar progressivamente mais caro.
- **Onde:** `dodo.gd`, `_mark_quadrant()` e `_check_zone_unlock()` — hoje `quadrants_done` é um array de bool; virar contador resolve a variante "duas casas".

---

**5. Performance com 2485 tiles**

- **Hoje:** cada `Tile` cria o próprio `ShaderMaterial` no `_ready()`. São 2485 materiais e sprites; `_reset_run` percorre todos duas vezes (reset + tint).
- **Sinal:** hitch no boot da cena ou ao apertar `R`.
- **Opção:** compartilhar um único material entre os tiles que não usam `hint_rect` — que neste modo são **todos**, já que Save the Dodo não tem indicadores de chave nem tint de portal.
- **Onde:** `tile.gd`, `_ready()`.

---

**6. Tamanho do grid**

- **Hoje:** 71×35, tiles de 16px, ocupando 1136×560 de uma viewport 1280×720.
- **A dúvida:** 16px é pequeno para ler números confortavelmente, e o grid ocupa quase toda a tela.
- **Opções:** reduzir para ~55×27 com tiles de 20px (mais legível, zonas mais apertadas); ou manter o tamanho e adicionar zoom/câmera.
- **Onde:** `dodo.gd`, `GRID_WIDTH` / `GRID_HEIGHT` / `SCALE_FACTOR`. **Mantenha as duas dimensões ímpares** — é o que garante um tile central exato pro Dodo.

---

**7. Legibilidade dos números na Orla**

- **Hoje:** a Orla é tingida a ~0.83 de luma (`ZONE_TINTS[0]`), então os números revelados ali saem mais escuros que nos outros modos.
- **Por que assim:** o gradiente de zona precisa de amplitude pra ser perceptível, e a Orla é o extremo escuro dele. Já limitei o mínimo a 0.78 pensando nisso, mas é tinta sobre o número, não atrás dele.
- **Sinal:** cansaço ou erro de leitura ao contar números na Orla, especialmente os de cor mais escura (o 4 e o 7 da tileset).
- **Opções:** clarear só `ZONE_TINTS[0]` e compensar a amplitude escurecendo o véu; ou aplicar o tint de zona **apenas nas casas fechadas**, deixando as reveladas em branco — custa a leitura de profundidade justamente na área aberta, que é onde o jogador mais olha.
- **Onde:** `dodo.gd`, `ZONE_TINTS`; a segunda opção mexe em `_apply_all_zone_tints()` e `_apply_zone_light()`.

---

**8. Arte do Dodo**

- **Hoje:** galinha do Farm RPG pack, 4 frames de 16×16, escala 1.5.
- **Por que 1.5 e não 2.0:** a 2× o sprite cobre os números das casas vizinhas, que é justamente onde você precisa enxergar pra fechar o cerco.
- **A decidir:** encomendar ou buscar um sprite de dodo; e se o Dodo deve ter uma reação visual ao ser libertado (hoje só aparece o overlay).

---

**9. Por que o jogador se importa com o Dodo?**

- **Hoje:** nada. Abrir uma zona só dá acesso à seguinte; não há score, item, nem flavor text.
- **O ponto:** o modo se chama *Save the Dodo* mas não dá motivo emocional nenhum pra salvá-lo. Esse é o gap menos técnico e talvez o mais importante.
- **Opções:** flavor text por zona (a variante "Cartógrafo pacato" do §17.5 tem a munição pronta); o Dodo reagindo conforme você se aproxima; contador de casas abertas como score.
