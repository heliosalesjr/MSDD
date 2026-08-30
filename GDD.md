# MSDD — Game Design Document (v0.2 / Foundational + Proto Snapshot)

> Rascunho inicial. Compila as decisões fundamentais tomadas em sessão de brainstorming.
> Tudo aqui é revisável — o objetivo é servir de âncora conceitual, não de contrato.
> **Atualização 2026-08-30:** adicionada §15 com o estado atual do protótipo técnico (Minesweeper + caça-chaves). Seções 1-14 permanecem como visão conceitual — o proto ainda não implementa a camada D&D.

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
- Botão "1 — Jogar" (ativo, atalhos `1`/`Enter`).
- Botão "2 — Em construção" (disabled).

**`main.tscn` — cena de jogo**
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
- Flood-fill em 24×14 é instantâneo.
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
1. **Herói no grid** — Sprite2D visível (`Human_Knight` já tá nos assets), posição inicial no safe zone, movimento por clique em célula adjacente. Primeira ponte com §4 do GDD.
2. **Sistema mínimo de recursos** — HP e/ou turnos. Substituir o timer real-time por turnos consumidos por movimento. Alinha com §9 do GDD.
3. **Ícones temáticos nas células** (§5.2) — trocar/complementar os números por número + ícone. Começar por 1-2 tipos além de bomba (ex: baú).
4. **Múltiplos tipos de "coisa notável"** — generalizar o placement pra suportar N tipos com contagens/hint colors separadas.
5. **Fonte pixel + refino visual** — resolver o gap estético.
6. **Chord click** — quando o board ficar denso o suficiente pra justificar.

Racional da ordem: herói + turnos é a ponte conceitual mais importante (transforma o Minesweeper em RPG). Ícones e múltiplos tipos vêm depois, quando a mecânica base tá firme.
