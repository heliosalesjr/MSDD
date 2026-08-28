# Minesweeper — Referência de Mecânica e Design

> Documento de referência técnica e crítica sobre o Minesweeper clássico. Serve de âncora ao desenvolver a gameplay do MSDD.
> Cada seção descreve **como o original funciona** e adiciona **análise crítica** — por que a mecânica existe, o que ela custa, onde ela quebra.

---

## 1. Configurações Clássicas (Windows Minesweeper)

| Modo | Grid | Minas | Densidade |
|------|------|-------|-----------|
| Beginner | 9×9 | 10 | 12.3% |
| Intermediate | 16×16 | 40 | 15.6% |
| Expert | 30×16 | 99 | 20.6% |
| Custom | até 30×24 | variável | variável |

**Análise.** Os três presets não são incrementos lineares — são categorias de experiência distintas. Beginner ensina o loop, Intermediate ensina dedução real, Expert força chord + gestão de risco. O salto de densidade Intermediate→Expert (15%→20%) é onde o jogo deixa de ser sempre solvente por lógica pura e passa a exigir "guesses educados" ocasionais.

---

## 2. Estados e Conteúdo da Célula

**Conteúdo real** (imutável após geração):
- **MINA**
- **NÚMERO 1–8** (quantas minas nas 8 vizinhas)
- **VAZIO / 0** (nenhuma mina vizinha)

**Estados de exibição** (mutáveis pelo jogador):
- HIDDEN — coberta
- REVEALED — descoberta, mostra conteúdo real
- FLAGGED — bandeira 🚩
- QUESTIONED — interrogação ❓

**Adjacência = 8 vizinhos** (distância de Chebyshev = 1, movimento de rei no xadrez). Bordas e cantos contam apenas vizinhos existentes: canto = 3, borda = 5, interior = 8.

---

## 3. Regras de Interação

| Ação | Estado da célula | Resultado |
|------|------------------|-----------|
| L-click | HIDDEN | Revela |
| L-click | FLAGGED | Bloqueado (proteção) |
| L-click | QUESTIONED | Revela (? não protege) |
| L-click | REVEALED | Nada (ou chord, §7) |
| R-click | HIDDEN | Vira FLAGGED |
| R-click | FLAGGED | Vira QUESTIONED |
| R-click | QUESTIONED | Vira HIDDEN |
| R-click | REVEALED | Nada |

**Análise.** A proteção da bandeira é uma das poucas concessões da UI ao erro humano. Sem ela, um clique acidental num flag mataria a partida — quebrando o modelo mental de "bandeira = decidi que é mina, não me deixe errar isso". A `?` existe justamente pra casos "acho que é, mas não vou proteger" — na prática, ~90% dos jogadores nunca usam, e speedrunners desabilitam.

---

## 4. Primeiro Clique — Safety

**Original (Windows).** A primeira célula clicada nunca é mina. Se o RNG teria colocado uma ali, a mina é movida pro primeiro slot livre (varredura top-left → bottom-right).

**Implementações modernas.** Também garantem que a primeira célula é ZERO (`adjacent = 0`), disparando uma cascata que dá ~3×3 de área inicial no mínimo. Isso significa que bombas são plantadas **depois** do primeiro clique, excluindo a célula clicada + suas 8 vizinhas.

**Análise crítica.** First-click-safe é lei não escrita — sem ela, morrer no primeiro clique acontece com probabilidade ≈ densidade (~15-20%), o que é frustração pura. Zero-safe vai além: garante que a partida "começa" com informação real, não apenas ausência de morte. Custo: reduz variância de aberturas — todo início parece igual. Um design mais ousado (jogo curto, dificuldade alta) pode preferir "só safe, não zero-safe" pra recuperar variância.

---

## 5. Flood Fill (Cascata)

Ao revelar uma célula com 0 minas adjacentes, revela recursivamente todas as vizinhas. A cascata **para** em qualquer célula numerada (revela ela, mas não propaga).

Implementação canônica: BFS ou DFS iterativo. Recursão pura funciona em grids pequenos mas estoura stack em grids grandes (100×100+).

**Análise.** Flood-fill é o "sabor de recompensa" do minesweeper — clicar em área vazia e ver o tabuleiro se abrir dispara dopamina real. Sem ela o jogo seria intolerável (revelar célula-por-célula em zonas seguras). É também a maior fonte de reclamação sobre "sorte": um primeiro clique bom abre metade do tabuleiro, um ruim revela uma célula isolada. Zero-safe (§4) existe em parte pra mitigar essa variância.

---

## 6. Cores dos Números — Convenção

| # | Cor (Windows clássico) |
|---|------------------------|
| 1 | Azul |
| 2 | Verde |
| 3 | Vermelho |
| 4 | Roxo escuro |
| 5 | Vinho / Marrom |
| 6 | Turquesa |
| 7 | Preto |
| 8 | Cinza |

**Análise.** Redundância dupla (cor + forma numérica) que permite parse rápido do tabuleiro. Jogadores expert reconhecem por cor antes de ler o dígito — "campo de vermelhos" é lido como "zona perigosa" instantaneamente. É acessibilidade acidental — funciona bem pra daltonismo moderado (cores distintas), mas 1-3-4 (azul, vermelho, roxo) pode confundir daltônicos protanope/deuteranope. Design moderno deveria manter o padrão de cor **e** garantir contraste de luminância independente do matiz.

---

## 7. Chord Click

**Ação:** L+R simultâneo (ou middle click) sobre uma célula NUMERADA revelada.

**Regra:** Se o número de bandeiras nas 8 vizinhas == número da célula, revela todas as vizinhas não-flagged. Se qualquer bandeira estiver errada → **game over instantâneo** ao revelar as vizinhas.

**Análise crítica.** Chord separa jogador casual do intermediário. Sem chord, Expert é impossível em tempo razoável — 99 minas em 30×16 exige revelar ~380 células. Chord também é o momento mais brutal do jogo: bandeira colocada por reflexo em cima de uma dedução errada mata você **não** quando você clica na célula (você nunca ia clicar num flag), mas quando você chord num vizinho. A morte vem de longe, por uma decisão passada esquecida. É excelente design de risco mas horrível pra iniciante — quase todo tutorial esconde chord.

---

## 8. Vitória e Derrota

**Vitória:** todas as células não-mina reveladas. Bandeiras são cosmético — não contam pra vitória. Convenção: ao vencer, minas restantes viram auto-flagged (feedback visual).

**Derrota:** clicou em mina.
- A mina clicada recebe visual "explodida" (fundo vermelho).
- Todas as outras minas são reveladas.
- Bandeiras erradas (colocadas onde não havia mina) recebem X vermelho.
- Bandeiras corretas permanecem como bandeira.

**Análise.** O reveal pós-derrota é catártico e educativo — você vê a solução, entende onde errou. É o design que transforma perda em aprendizado. Um jogo que só mostrasse "You Lost" sem revelar seria drasticamente pior — literalmente esconderia a informação necessária pra você ficar melhor. Vale como princípio: **em jogos de dedução, a derrota deve revelar a verdade.**

---

## 9. UI Clássica

- **Placar de minas:** `total_minas − flags_colocadas`. Pode ir negativo (over-flag). Estado da conta atualiza em tempo real.
- **Timer:** começa no primeiro clique, para em vitória/derrota. Contava até 999s no original.
- **Face (smiley):**
  - 🙂 idle
  - 😮 mouse pressionado (mostra "wow" antes de soltar)
  - 😎 vitória
  - 😵 derrota
  - Clicar na face reinicia

**Análise.** O rosto é feedback afetivo — o jogo antropomorfizado reage junto com você. É pequeno mas contribui muito pro "sentir" da partida. O `wow` durante o botão pressionado é o único elemento de tensão em tempo real do jogo — o resto é puramente turn-based mental. Timer + face juntos criam a única pressão temporal real do jogo (relevante pra speedrunners e insignificante pra casual).

---

## 10. Densidade e Dificuldade

| Densidade | Caráter |
|-----------|---------|
| <10% | Trivial, quase só cascatas |
| 10-15% | Fácil, dedução simples resolve tudo |
| 15-20% | Sweet spot — dedução + gestão de risco |
| 20-25% | Difícil, guesses ocasionais necessários |
| >25% | Impraticável sem guess, frustrante |

**Análise.** Densidade não é a única variável — TAMANHO do board interage com ela. 20% em 9×9 (16 minas em 81 células) é psicologicamente muito diferente de 20% em 30×16 (99 minas em 480), pois grids maiores dão mais "informação total" pro solver lógico usar. Também: **densidade percebida vs real** — jogador percebe densidade pela frequência que encontra minas ao explorar, não pela % absoluta. Cascatas grandes reduzem densidade percebida ("nossa, tabuleiro fácil"); áreas apertadas aumentam.

---

## 11. Solvabilidade — o Debate Central

**Original (Windows):** placement é 100% aleatório. Boards NÃO são garantidos solucionáveis por lógica pura — situações **50/50 guess** ocorrem, especialmente em Expert.

**Modernos (Simon Tatham, Minesweeper.online modo NG):** geração testa com solver lógico embutido e regenera se o board não for solvente sem guess.

**Análise crítica.** É uma das decisões de design mais divisivas do gênero puzzle.

**Random puro:**
- ✓ Mantém tensão de "posso morrer por azar puro"
- ✓ Gerador é trivial (só shuffle)
- ✗ Frustra por perdas não-culpadas (jogou perfeito, morreu por 50/50)
- ✗ Speedrun/leaderboards ficam contaminados por sorte

**No-guessing:**
- ✓ Cada morte é sua culpa (justo)
- ✓ Permite verdadeira competição de skill
- ✗ Limita dificuldade máxima (alguns boards muito densos são impossíveis de gerar solventes)
- ✗ Requer solver programático embutido no gerador (custo de dev)
- ✗ Vies: se todo board é solvente, dedução avançada vira **obrigação**, não bônus — muda o feel

Para o **MSDD** essa decisão vira: aceito que o jogador perca por RNG? Ou toda derrota tem que ser derivável das pistas mostradas? Como o MSDD tem múltiplos tipos de célula (inimigo, baú, armadilha…), "solvabilidade" fica mais nuançada — talvez não seja "sem guess" mas "toda decisão tem base informacional".

---

## 12. Padrões de Dedução

### 12.1 Subset Counting (a base)

Se as células desconhecidas de A são subconjunto das de B, e `count(B) − count(A) == |desconhecidas(B) \ desconhecidas(A)|`, então **todas as células em (B \ A) são minas**.

Recíproco: se `count(A) == count(B)` e A ⊆ B, então todas as células em (B \ A) são **seguras**.

Todo padrão nomeado abaixo é uma instância visual dessa regra.

### 12.2 Padrão 1-1 (fronteira reta)

Dois "1" adjacentes numa fronteira reta, um deles com uma desconhecida a mais que o outro:

```
? ? ?     ← três desconhecidas na fronteira de cima
1 1 x     ← "1", "1", célula sem número já resolvida
- - -
```

Se a "1" da direita toca apenas `?₂` e `?₃`, e a "1" da esquerda toca `?₁`, `?₂`, `?₃`:
- direita: mina em `{?₂, ?₃}`, exatamente 1
- esquerda: mina em `{?₁, ?₂, ?₃}`, exatamente 1
- Subset: subconjunto direita ⊆ esquerda, contagens iguais → **`?₁` é seguro**.

### 12.3 Padrão 1-2-1

Sequência 1-2-1 ao longo de uma borda reta, com 3 desconhecidas do outro lado:

```
? ? ?
1 2 1
```

O "2" precisa de 2 minas nas 3 desconhecidas. Cada "1" precisa de 1 mina cada. Única solução consistente: **minas nas duas extremidades, meio é seguro.**

### 12.4 Padrão 1-2-2-1

Sequência 1-2-2-1 com 4 desconhecidas alinhadas:

```
? ? ? ?
1 2 2 1
```

Solução única: **duas minas centrais, extremidades seguras.**

### 12.5 Contagem Global (endgame)

Perto do fim, `minas_restantes = total_minas − flags`. Se restam poucas células desconhecidas, contagem global pode resolver ambiguidades que dedução local não consegue.

**Análise dos padrões.** Padrões nomeados existem porque **reconhecimento vence dedução em velocidade cognitiva**. Um jogador expert não deriva subset counting em tempo real — ele reconhece "isso é 1-2-1" e age em ~200ms. Isso tem duas implicações de design:

1. **Aprendizado tem platôs.** Pular do nível casual pro intermediário exige aprender padrões — sem eles, todo movimento é dedução pesada, o que fatiga.
2. **Variações quebram padrões.** Se seu jogo introduz mecânica que altera adjacência (ex: hexágonos, corredores irregulares), padrões visuais precisam ser reaprendidos — curva de aprendizado sobe. Trade-off entre originalidade e familiaridade.

---

## 13. Adaptações Sugeridas para MSDD

Anotações de como cada mecânica do original se traduz (ou não) pro contexto do MSDD:

- **Múltiplos tipos de conteúdo.** Original tem 1 (mina). MSDD tem N (inimigo, baú, armadilha, santuário). Números indicam quantidade TOTAL de coisas notáveis; ícones indicam TIPO. Isso aumenta densidade informacional por célula — trade-off entre riqueza de decisão e legibilidade.
- **Movimento tem custo.** Revelar em MS é grátis. Em MSDD, mover consome turnos — muda a matemática de exploração. Jogador não vai revelar tudo, vai revelar o mínimo pra atingir o objetivo. Isso enfraquece a dopamina do flood-fill (mais território revelado = mais tempo gasto) e força priorização.
- **Grid irregular / procedural.** Flood-fill em MS segue 8 vizinhos geométricos. Em MSDD (corredores, salas), flood-fill deve seguir **conectividade lógica**, não geométrica. Cascata para em portas fechadas, corredores não-descobertos, etc.
- **Chord.** Poderia virar "andar-e-revelar" (revela vizinhas e move o avatar pra célula chorded), ou não existir. Se existir, o "matar por bandeira errada" precisa de contexto narrativo (bandeira representa o quê? deduziu inimigo mas era baú → …?).
- **First-click safety.** Manter — mesma lógica, entrada da dungeon é sempre segura.
- **Solvabilidade.** Ver §11. Com múltiplos tipos, "solver lógico" fica mais complexo — talvez a decisão certa seja "informação suficiente pra decisão *ponderada*, não necessariamente única".
- **Bandeira.** Original: informativa. MSDD: pode ganhar peso mecânico (ex: gastar um recurso pra "sondar" antes de revelar; bandeiras representam sondagens confirmadas).
- **Cores dos números.** MSDD tem pixel art customizada — palette pode e deve seguir a convenção 1=azul, 2=verde, 3=vermelho pra aproveitar reconhecimento pré-existente. Divergir gratuitamente custa curva de aprendizado.

---

## Fontes

- Microsoft Minesweeper (Windows 3.1 → Windows 7)
- Simon Tatham's Portable Puzzle Collection — Mines
- Minesweeper.online (implementação canônica com telemetria e modos NG)
- Wikipedia: *Minesweeper (video game)*
