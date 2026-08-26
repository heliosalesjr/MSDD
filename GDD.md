# MSDD — Game Design Document (v0.1 / Foundational)

> Rascunho inicial. Compila as decisões fundamentais tomadas em sessão de brainstorming.
> Tudo aqui é revisável — o objetivo é servir de âncora conceitual, não de contrato.

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
5. Escolher versão do Godot e montar projeto base.
