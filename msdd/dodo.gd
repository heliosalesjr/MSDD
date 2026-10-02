extends Node2D

# Grid bem maior que os outros protótipos, com tiles de 16px (metade do
# tamanho onscreen dos demais) pra caber na tela. Dimensões ÍMPARES de
# propósito: garantem um tile central exato, que é onde o Dodo fica.
const GRID_WIDTH := 71
const GRID_HEIGHT := 35
const TILE_SIZE := 16
const SCALE_FACTOR := 1
const CELL_PX := TILE_SIZE * SCALE_FACTOR
const BOMB_DENSITY := 0.15

# 3 anéis concêntricos. A fronteira é medida em distância NORMALIZADA do
# centro (0 no Dodo, 1 na borda), não em Chebyshev puro — assim os anéis
# acompanham a proporção do grid em vez de virarem quadrados num grid
# achatado, onde o anel externo sobraria só nas laterais.
const ZONE_COUNT := 3
const ZONE_INNER_EDGE := 1.0 / 3.0   # dentro disto = zona do Dodo
const ZONE_OUTER_EDGE := 2.0 / 3.0   # fora disto = zona da borda

const QUADRANT_COUNT := 4
const QUADRANT_NAMES := ["NO", "NE", "SO", "SE"]

const ZONE_NAMES := ["Orla", "Mata", "Clareira"]

# Cada zona tem a sua própria cor, formando um gradiente da borda pro centro:
# a Orla é sombra fria de mata fechada, a Clareira é luz quente onde o Dodo
# está. É isso que dá ao jogador a leitura de profundidade que antes só
# existia no código — sem isso ele enxerga "liberado vs bloqueado" e nada mais.
const ZONE_TINTS := [
	Color(0.78, 0.83, 0.94),   # Orla — fria e escura
	Color(0.94, 0.96, 0.94),   # Mata — neutra
	Color(1.14, 1.08, 0.88),   # Clareira — quente e clara
]
# Véu aplicado sobre a cor da zona enquanto ela está bloqueada. É um
# MULTIPLICADOR, não uma cor fixa: com cor fixa, Mata e Clareira ficariam
# idênticas no começo da partida e o jogador veria só duas regiões.
# E é um multiplicador POR ZONA, mais fraco quanto mais fundo: a Clareira
# "brilha através" da névoa, como uma luz distante que você está tentando
# alcançar. Com um véu único os dois anéis apagados ficavam separados por
# apenas 0.06 de luma — na prática, uma massa escura só.
const LOCKED_VEIL := [0.42, 0.46, 0.56]
const TINT_DODO := Color(1.35, 1.15, 0.55)

# Quanto tempo a zona recém-liberada leva pra acender, de fora pra dentro.
const ZONE_SWEEP_DURATION := 0.55

const DODO_SHEET := preload("res://assets/Farm RPG FREE 16x16 - Tiny Asset Pack/Farm RPG FREE 16x16 - Tiny Asset Pack/Farm Animals/Chicken Blonde  Green.png")
# Moedas: espalhadas como as bombas, mas sorteadas DEPOIS delas, entre as
# casas que sobraram. Não há sprite de moeda utilizável no projeto, então ela
# é desenhada em código — e desenhada GIRANDO, o que é o que dá o volume:
# a largura aparente acompanha o cosseno do ângulo, e quando a moeda fica de
# perfil o que sobra é a espessura dela. A moeda não permanece na casa; ela
# salta e some, e o que fica é a contagem.
const COIN_COUNT := 50
const COIN_PX := 15          # quase o tamanho de uma casa (16px)
const COIN_FRAMES := 8       # um giro completo
const COIN_SPIN_FPS := 14.0
# O salto não é uma sequência de trechos com easing escolhido a dedo: é uma
# parábola integrada de verdade. A moeda sai com COIN_LAUNCH, a gravidade a
# traz de volta, e ela quica devolvendo uma fração da velocidade de impacto.
# Duas coisas saem de graça disso:
#   1. O "easing" natural — a curva É a física, então a desaceleração na
#      subida e a aceleração na queda são exatas, não aproximadas.
#   2. A duração total EMERGE dos parâmetros em vez de ser imposta. Logo,
#      sortear os parâmetros varia altura, tempo e ritmo de forma coerente
#      ENTRE SI: a moeda que sobe mais alto também fica mais tempo no ar.
# Isso é o que impede cinco moedas coletadas juntas de se moverem em bloco.
const COIN_LAUNCH := 167.0        # velocidade de saída, px/s
const COIN_GRAVITY := 368.0       # px/s²

# Variação por moeda. O jitter é multiplicativo pra que a física continue
# coerente — não se sorteia "duração", se sorteia o impulso e o peso.
# As faixas são largas de propósito: com gravidade alta o voo médio é curto,
# e é a amplitude que faz um punhado de moedas parecer um punhado de moedas
# em vez de uma animação repetida cinco vezes.
const COIN_LAUNCH_JITTER := 0.20
const COIN_GRAVITY_JITTER := 0.18
const COIN_RESTITUTION_RANGE := Vector2(0.55, 0.92)
const COIN_DRIFT_MAX := 16.0      # deriva lateral ao longo do voo, px
const COIN_SPIN_SCALE := Vector2(0.60, 1.70)
# Espessura mínima: é ela que a moeda mostra quando está de perfil, e é o que
# impede que o frame de 90° simplesmente desapareça.
const COIN_HALF_THICKNESS := 1.6

# Quatro tons pra dar volume à face, mais o contorno e a cor da espessura.
const COIN_RIM := Color(0.34, 0.21, 0.03)
const COIN_SHADE := Color(0.70, 0.46, 0.07)
const COIN_BODY := Color(0.94, 0.72, 0.16)
const COIN_SHINE := Color(1.00, 0.96, 0.72)
const COIN_SIDE := Color(0.80, 0.55, 0.10)

const DODO_FRAME_SIZE := 16
const DODO_FRAME_COUNT := 4
const DODO_FPS := 4.0
# 1.5 e não 2.0: a 2x o sprite cobriria os números das casas vizinhas, que
# é justamente onde o jogador precisa enxergar pra fechar o cerco.
const DODO_SCALE := 1.5

var tiles: Array = []            # [y][x] -> Tile
var zone_of: Array = []          # [y][x] -> int 0..2 (0 = orla)
var quadrant_of: Array = []      # [y][x] -> int 0..3
var zone_local_of: Array = []    # [y][x] -> float 0 (borda externa da zona) .. 1 (interna)
var zone_members: Array = []     # [zona] -> Array[Vector2i]

var dodo_pos: Vector2i
var dodo_sprite: AnimatedSprite2D

var coin_at: Dictionary = {}          # Vector2i -> índice da moeda
var coin_home: Array[Vector2] = []    # de onde cada moeda salta
var coin_sprites: Array[AnimatedSprite2D] = []
var coin_tweens: Array = []           # Tween do salto, ou null
var coin_flight: Array = []           # parâmetros do voo atual de cada moeda
var coin_collected: Array[bool] = []
var coins_found: int = 0

var unlocked_zone: int = 0
var quadrants_done: Array[bool] = [false, false, false, false]

var first_click_done: bool = false
var game_over: bool = false
var won: bool = false

var cascade_end_msec: int = 0
var run_id: int = 0

var base_position: Vector2 = Vector2.ZERO

var ui_layer: CanvasLayer
var status_label: Label
var log_label: Label
var end_overlay: Control
var end_message_label: Label
var end_subtitle_label: Label

func _ready() -> void:
	dodo_pos = Vector2i(GRID_WIDTH >> 1, GRID_HEIGHT >> 1)
	_build_grid()
	_classify_tiles()
	_setup_coins()
	_setup_dodo()
	_setup_ui()
	_center_grid()
	get_viewport().size_changed.connect(_center_grid)
	_reset_run()

func _build_grid() -> void:
	for y in GRID_HEIGHT:
		var row: Array = []
		for x in GRID_WIDTH:
			var t := Tile.new()
			t.grid_pos = Vector2i(x, y)
			t.position = Vector2(x, y) * CELL_PX
			t.scale = Vector2.ONE * SCALE_FACTOR
			add_child(t)
			row.append(t)
		tiles.append(row)

# Zona, quadrante e posição dentro da zona são fixos pro grid inteiro, então
# calculamos uma vez só no boot em vez de a cada clique.
func _classify_tiles() -> void:
	var half_w := float(GRID_WIDTH >> 1)
	var half_h := float(GRID_HEIGHT >> 1)
	for _i in ZONE_COUNT:
		zone_members.append([])
	for y in GRID_HEIGHT:
		var zrow: Array = []
		var qrow: Array = []
		var lrow: Array = []
		for x in GRID_WIDTH:
			var dx := float(x - dodo_pos.x)
			var dy := float(y - dodo_pos.y)
			# Distância normalizada: 0 no Dodo, 1 na borda mais próxima.
			var dist: float = maxf(absf(dx) / half_w, absf(dy) / half_h)

			var zone := 0
			var outer := 1.0
			var inner := ZONE_OUTER_EDGE
			if dist <= ZONE_INNER_EDGE:
				zone = 2
				outer = ZONE_INNER_EDGE
				inner = 0.0
			elif dist <= ZONE_OUTER_EDGE:
				zone = 1
				outer = ZONE_OUTER_EDGE
				inner = ZONE_INNER_EDGE

			# 0 na borda externa da zona, 1 na interna — usado pra acender a
			# zona de fora pra dentro quando ela é liberada.
			var span: float = maxf(outer - inner, 0.0001)
			lrow.append(clampf((outer - dist) / span, 0.0, 1.0))

			# Quadrante relativo ao Dodo. O >= 0 nos dois eixos garante que a
			# linha e a coluna centrais caiam num quadrante em vez de ficarem
			# órfãs.
			var q := 0
			if dx >= 0.0:
				q += 1
			if dy >= 0.0:
				q += 2

			zrow.append(zone)
			qrow.append(q)
			zone_members[zone].append(Vector2i(x, y))
		zone_of.append(zrow)
		quadrant_of.append(qrow)
		zone_local_of.append(lrow)

func _setup_coins() -> void:
	var frames := SpriteFrames.new()
	frames.set_animation_loop("default", true)
	frames.set_animation_speed("default", COIN_SPIN_FPS)
	for tex in _make_coin_frames():
		frames.add_frame("default", tex)
	for _i in COIN_COUNT:
		var sp := AnimatedSprite2D.new()
		sp.sprite_frames = frames
		sp.animation = "default"
		sp.visible = false
		sp.z_index = 15   # acima dos tiles (que sobem pra 1 no pop), abaixo do Dodo
		add_child(sp)
		coin_sprites.append(sp)
		coin_tweens.append(null)
		coin_flight.append({})

# Um giro completo em COIN_FRAMES quadros. O volume vem de três coisas:
# a largura encolhendo com o cosseno, a face de trás recebendo menos luz, e
# a espessura aparecendo quando a moeda passa de perfil.
func _make_coin_frames() -> Array:
	var out: Array = []
	var c := (COIN_PX - 1) * 0.5
	var r := COIN_PX * 0.5 - 0.5
	for f in COIN_FRAMES:
		var theta := TAU * float(f) / float(COIN_FRAMES)
		var cosv := cos(theta)
		var half_w: float = maxf(absf(cosv) * r, COIN_HALF_THICKNESS)
		var showing_back := cosv < 0.0
		var edge_on := absf(cosv) < 0.34
		var img := Image.create(COIN_PX, COIN_PX, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for y in COIN_PX:
			for x in COIN_PX:
				var nx := (x - c) / half_w
				var ny := (y - c) / r
				var d := sqrt(nx * nx + ny * ny)
				if d > 1.0:
					continue
				var col: Color
				if d > 0.76:
					col = COIN_RIM
				elif edge_on:
					# Quase de perfil: o que se vê é a lateral da moeda.
					col = COIN_SIDE
				else:
					# Luz vinda do canto superior-esquerdo.
					var lum := -(nx * 0.55 + ny * 0.78)
					if showing_back:
						lum -= 0.5
					if lum > 0.45:
						col = COIN_SHINE
					elif lum > -0.15:
						col = COIN_BODY
					else:
						col = COIN_SHADE
				img.set_pixel(x, y, col)
		out.append(ImageTexture.create_from_image(img))
	return out

func _setup_dodo() -> void:
	var frames := SpriteFrames.new()
	frames.set_animation_loop("default", true)
	frames.set_animation_speed("default", DODO_FPS)
	# Linha 0 da sheet (a de baixo é outra pose); 4 frames de 16x16.
	for i in DODO_FRAME_COUNT:
		var atlas := AtlasTexture.new()
		atlas.atlas = DODO_SHEET
		atlas.region = Rect2(i * DODO_FRAME_SIZE, 0, DODO_FRAME_SIZE, DODO_FRAME_SIZE)
		frames.add_frame("default", atlas)

	dodo_sprite = AnimatedSprite2D.new()
	dodo_sprite.sprite_frames = frames
	dodo_sprite.animation = "default"
	dodo_sprite.scale = Vector2.ONE * DODO_SCALE
	dodo_sprite.z_index = 20
	dodo_sprite.position = Vector2(dodo_pos) * CELL_PX + Vector2.ONE * CELL_PX * 0.5
	dodo_sprite.play()
	add_child(dodo_sprite)

func _center_grid() -> void:
	var viewport_size := get_viewport_rect().size
	var grid_px := Vector2(GRID_WIDTH, GRID_HEIGHT) * CELL_PX
	base_position = ((viewport_size - grid_px) * 0.5).floor()
	position = base_position

func _setup_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	status_label = Label.new()
	status_label.position = Vector2(20, 18)
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(status_label)

	log_label = Label.new()
	log_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	log_label.offset_top = -56
	log_label.offset_bottom = -18
	log_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	log_label.add_theme_font_size_override("font_size", 18)
	log_label.add_theme_color_override("font_color", Color(0.88, 0.94, 0.80))
	log_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(log_label)

	_build_end_overlay()

func _build_end_overlay() -> void:
	end_overlay = Control.new()
	end_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_overlay.visible = false

	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.55)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	end_overlay.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_overlay.add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)

	end_message_label = Label.new()
	end_message_label.text = ""
	end_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_message_label.add_theme_font_size_override("font_size", 56)
	vbox.add_child(end_message_label)

	end_subtitle_label = Label.new()
	end_subtitle_label.text = ""
	end_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_subtitle_label.add_theme_font_size_override("font_size", 20)
	end_subtitle_label.modulate = Color(0.85, 0.85, 0.85)
	vbox.add_child(end_subtitle_label)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 20)
	vbox.add_child(button_row)

	var menu_button := Button.new()
	menu_button.text = "Voltar ao menu"
	menu_button.custom_minimum_size = Vector2(180, 50)
	menu_button.add_theme_font_size_override("font_size", 18)
	menu_button.pressed.connect(_on_menu_pressed)
	button_row.add_child(menu_button)

	var quit_button := Button.new()
	quit_button.text = "Quit"
	quit_button.custom_minimum_size = Vector2(180, 50)
	quit_button.add_theme_font_size_override("font_size", 18)
	quit_button.pressed.connect(_on_quit_pressed)
	button_row.add_child(quit_button)

	ui_layer.add_child(end_overlay)

func _reset_run() -> void:
	run_id += 1
	cascade_end_msec = 0
	first_click_done = false
	game_over = false
	won = false
	unlocked_zone = 0
	quadrants_done = [false, false, false, false]
	coin_at.clear()
	coin_home.clear()
	coin_collected.clear()
	coins_found = 0
	for i in coin_sprites.size():
		var tw: Tween = coin_tweens[i]
		if tw != null and tw.is_valid():
			tw.kill()
		coin_tweens[i] = null
		coin_flight[i] = {}
		coin_sprites[i].visible = false
		coin_sprites[i].stop()
	position = base_position
	end_overlay.visible = false
	for row in tiles:
		for t in row:
			t.reset()
	_apply_all_zone_tints()
	log_label.text = "O Dodo está preso na clareira. Abra caminho pelos quatro lados."
	_update_status()
	print("Nova expedição — grid %dx%d, Dodo em %s." % [GRID_WIDTH, GRID_HEIGHT, dodo_pos])

# A cor de um tile é a da sua zona, escurecida pelo véu se ela ainda não caiu.
func _zone_tint(zone: int, unlocked: bool) -> Color:
	var c: Color = ZONE_TINTS[zone]
	if unlocked:
		return c
	var veil: float = LOCKED_VEIL[zone]
	return Color(c.r * veil, c.g * veil, c.b * veil, 1.0)

func _apply_all_zone_tints() -> void:
	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			var z: int = zone_of[y][x]
			tiles[y][x].set_base_tint(_zone_tint(z, z <= unlocked_zone))
	tiles[dodo_pos.y][dodo_pos.x].set_base_tint(TINT_DODO)

func _update_status() -> void:
	var marks := ""
	for q in QUADRANT_COUNT:
		var mark := "OK" if quadrants_done[q] else "--"
		marks += "%s%s  " % [QUADRANT_NAMES[q], mark]
	var purse := "Moedas: %d" % coins_found
	if unlocked_zone >= ZONE_COUNT - 1:
		status_label.text = "Zona %d/%d — %s    %s    O caminho até o Dodo está aberto" % [
			unlocked_zone + 1, ZONE_COUNT, ZONE_NAMES[unlocked_zone], purse
		]
	else:
		status_label.text = "Zona %d/%d — %s    %s    Quadrantes: %s" % [
			unlocked_zone + 1, ZONE_COUNT, ZONE_NAMES[unlocked_zone], purse, marks.strip_edges()
		]

func _in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.x < GRID_WIDTH and p.y >= 0 and p.y < GRID_HEIGHT

func _place_bombs(safe_center: Vector2i) -> void:
	var safe_zone := {}
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			safe_zone[safe_center + Vector2i(dx, dy)] = true
	# O Dodo e as 8 casas em volta nunca são bomba: se um dos quatro lados
	# dele fosse mina, a vitória seria impossível de alcançar em segurança.
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			safe_zone[dodo_pos + Vector2i(dx, dy)] = true

	var candidates: Array[Vector2i] = []
	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			var p := Vector2i(x, y)
			if not safe_zone.has(p):
				candidates.append(p)

	candidates.shuffle()
	var wanted: int = int(GRID_WIDTH * GRID_HEIGHT * BOMB_DENSITY)
	var count: int = mini(wanted, candidates.size())
	for i in count:
		var p: Vector2i = candidates[i]
		tiles[p.y][p.x].is_bomb = true

	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			if not tiles[y][x].is_bomb:
				tiles[y][x].adjacent_bombs = _count_adjacent_bombs(x, y)
	print("Bombas plantadas: %d de %d casas." % [count, GRID_WIDTH * GRID_HEIGHT])

# Roda depois de _place_bombs: as candidatas são as casas que sobraram. A
# casa do Dodo fica de fora porque nunca é revelada — moeda ali seria
# inalcançável.
func _place_coins() -> void:
	var candidates: Array[Vector2i] = []
	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			var p := Vector2i(x, y)
			if p == dodo_pos:
				continue
			if tiles[y][x].is_bomb:
				continue
			candidates.append(p)

	candidates.shuffle()
	var count: int = mini(COIN_COUNT, candidates.size())
	for i in count:
		var p: Vector2i = candidates[i]
		coin_at[p] = i
		coin_collected.append(false)
		coin_home.append(Vector2(p) * CELL_PX + Vector2.ONE * CELL_PX * 0.5)
	print("Moedas espalhadas: %d." % count)

# A moeda só aparece (e só conta) quando a casa dela abre de fato — a onda de
# revelação vai "catando" as moedas no caminho, em vez de o placar saltar
# antes de a tela mostrar o porquê.
func _schedule_coin_pickup(idx: int, wait: float) -> void:
	if wait <= 0.0:
		_pick_up_coin(idx, run_id)
		return
	get_tree().create_timer(wait).timeout.connect(_pick_up_coin.bind(idx, run_id))

func _pick_up_coin(idx: int, expected_run: int) -> void:
	if run_id != expected_run:
		return
	if idx >= coin_collected.size() or coin_collected[idx]:
		return
	coin_collected[idx] = true
	coins_found += 1
	_update_status()
	_play_coin_pop(idx)

# A moeda salta da casa, gira no ar e some. Nada fica para trás — o registro
# da coleta é o contador.
func _play_coin_pop(idx: int) -> void:
	var sp: AnimatedSprite2D = coin_sprites[idx]
	var old: Tween = coin_tweens[idx]
	if old != null and old.is_valid():
		old.kill()

	sp.position = coin_home[idx]
	sp.modulate = Color.WHITE
	sp.visible = true
	# Fase inicial aleatória: duas moedas coletadas juntas não giram em uníssono.
	sp.frame = randi() % COIN_FRAMES
	sp.speed_scale = randf_range(COIN_SPIN_SCALE.x, COIN_SPIN_SCALE.y)
	sp.play()

	var v0: float = COIN_LAUNCH * randf_range(1.0 - COIN_LAUNCH_JITTER, 1.0 + COIN_LAUNCH_JITTER)
	var g: float = COIN_GRAVITY * randf_range(1.0 - COIN_GRAVITY_JITTER, 1.0 + COIN_GRAVITY_JITTER)
	var rest: float = randf_range(COIN_RESTITUTION_RANGE.x, COIN_RESTITUTION_RANGE.y)
	var drift: float = randf_range(-COIN_DRIFT_MAX, COIN_DRIFT_MAX)

	# Primeiro arco inteiro (subida + queda), mais a SUBIDA do segundo: é
	# nela que a moeda se apaga, então o voo termina no apogeu do quique.
	var first_arc: float = 2.0 * v0 / g
	var second_rise: float = rest * v0 / g
	var total: float = first_arc + second_rise

	coin_flight[idx] = {
		"v0": v0, "g": g, "rest": rest,
		"drift": drift, "total": total, "bounce": first_arc,
	}

	var tw := create_tween()
	# O tempo corre linear; quem desenha a curva é _coin_height.
	tw.tween_method(_set_coin_flight.bind(idx), 0.0, total, total).set_trans(Tween.TRANS_LINEAR)
	# O fade corre junto com a segunda subida, começando depois que ela já
	# pegou altura — senão a moeda some antes de ficar claro que quicou.
	var fade_start: float = first_arc + second_rise * 0.30
	tw.parallel().tween_property(sp, "modulate:a", 0.0, total - fade_start).set_delay(fade_start)
	tw.chain().tween_callback(_hide_coin.bind(idx))
	coin_tweens[idx] = tw

# Altura acima da casa no instante t do voo. Dois arcos balísticos: o de
# lançamento e o do quique.
func _coin_height(t: float, f: Dictionary) -> float:
	var g: float = f["g"]
	var bounce: float = f["bounce"]
	if t < bounce:
		return maxf(f["v0"] * t - 0.5 * g * t * t, 0.0)
	var t2: float = t - bounce
	var v1: float = f["v0"] * f["rest"]
	return maxf(v1 * t2 - 0.5 * g * t2 * t2, 0.0)

func _set_coin_flight(t: float, idx: int) -> void:
	var f: Dictionary = coin_flight[idx]
	if f.is_empty():
		return
	# Sem força horizontal, a deriva é velocidade constante: linear no tempo.
	var x: float = f["drift"] * (t / f["total"])
	coin_sprites[idx].position = coin_home[idx] + Vector2(x, -_coin_height(t, f))

func _hide_coin(idx: int) -> void:
	coin_sprites[idx].visible = false
	coin_sprites[idx].stop()

func _count_adjacent_bombs(cx: int, cy: int) -> int:
	var n := 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var np := Vector2i(cx + dx, cy + dy)
			if not _in_bounds(np):
				continue
			if tiles[np.y][np.x].is_bomb:
				n += 1
	return n

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_reset_run()
		return

	if game_over or won:
		return
	if not (event is InputEventMouseButton) or not event.pressed:
		return

	var local := to_local(event.position)
	var gx := int(floor(local.x / CELL_PX))
	var gy := int(floor(local.y / CELL_PX))
	var p := Vector2i(gx, gy)
	if not _in_bounds(p):
		return

	match event.button_index:
		MOUSE_BUTTON_LEFT:
			_handle_left(p)
		MOUSE_BUTTON_RIGHT:
			_handle_right(p)

func _handle_left(p: Vector2i) -> void:
	if p == dodo_pos:
		log_label.text = "O Dodo não pode se libertar sozinho — chegue a um dos lados dele."
		return
	if zone_of[p.y][p.x] > unlocked_zone:
		var next_name: String = ZONE_NAMES[mini(unlocked_zone + 1, ZONE_COUNT - 1)]
		log_label.text = "A %s ainda está fechada. Abra um caminho em cada quadrante." % next_name
		return

	var t: Tile = tiles[p.y][p.x]
	if t.state == Tile.State.FLAGGED or t.state == Tile.State.REVEALED:
		return

	if not first_click_done:
		_place_bombs(p)
		_place_coins()
		first_click_done = true

	if t.is_bomb:
		_lose(t)
		return

	_flood_reveal(p)
	_check_zone_unlock()
	_update_status()
	_check_win()

func _handle_right(p: Vector2i) -> void:
	if p == dodo_pos or zone_of[p.y][p.x] > unlocked_zone:
		return
	tiles[p.y][p.x].cycle_mark()

# O flood NÃO atravessa a fronteira da zona liberada nem a casa do Dodo —
# se vazasse, o gating por quadrante não existiria na prática.
func _flood_reveal(start: Vector2i) -> void:
	var queue: Array = [[start, 0]]
	var max_delay := 0.0
	while not queue.is_empty():
		var entry: Array = queue.pop_front()
		var p: Vector2i = entry[0]
		var ring: int = entry[1]
		if p == dodo_pos:
			continue
		if zone_of[p.y][p.x] > unlocked_zone:
			continue
		var t: Tile = tiles[p.y][p.x]
		if t.state == Tile.State.REVEALED or t.state == Tile.State.FLAGGED:
			continue
		if t.is_bomb:
			continue
		var delay: float = Tile.cascade_delay(ring)
		max_delay = maxf(max_delay, delay)
		t.reveal(delay)
		if coin_at.has(p):
			_schedule_coin_pickup(coin_at[p], t.time_until_open())
		_mark_quadrant(p)
		if t.adjacent_bombs == 0:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var np := Vector2i(p.x + dx, p.y + dy)
					if not _in_bounds(np):
						continue
					queue.push_back([np, ring + 1])
	_note_cascade(max_delay)

# Só contam os tiles abertos DENTRO da zona atual: reabrir a orla depois de
# liberar a mata não deve adiantar o progresso da zona seguinte.
func _mark_quadrant(p: Vector2i) -> void:
	if zone_of[p.y][p.x] != unlocked_zone:
		return
	quadrants_done[quadrant_of[p.y][p.x]] = true

func _check_zone_unlock() -> void:
	if unlocked_zone >= ZONE_COUNT - 1:
		return
	for done in quadrants_done:
		if not done:
			return
	unlocked_zone += 1
	quadrants_done = [false, false, false, false]
	# A zona nova já conta o que estiver aberto nela (o flood pode ter
	# encostado na fronteira antes de ela abrir).
	for p in zone_members[unlocked_zone]:
		if tiles[p.y][p.x].state == Tile.State.REVEALED:
			quadrants_done[quadrant_of[p.y][p.x]] = true
	_sweep_zone_light(unlocked_zone)
	log_label.text = "Os quatro lados cederam. A %s se abre." % ZONE_NAMES[unlocked_zone]
	print("Zona %d liberada (%s)." % [unlocked_zone + 1, ZONE_NAMES[unlocked_zone]])

# A zona acende de fora pra dentro, no mesmo espírito da cascata do §18.
func _sweep_zone_light(zone: int) -> void:
	var tw := create_tween()
	tw.tween_method(_apply_zone_light.bind(zone), 0.0, 1.0, ZONE_SWEEP_DURATION)

func _apply_zone_light(progress: float, zone: int) -> void:
	var veiled: Color = _zone_tint(zone, false)
	var lit: Color = _zone_tint(zone, true)
	for p in zone_members[zone]:
		if p == dodo_pos:
			continue
		# Tiles mais externos da zona acendem primeiro.
		var head: float = zone_local_of[p.y][p.x] * 0.6
		var amount: float = clampf((progress - head) / 0.4, 0.0, 1.0)
		tiles[p.y][p.x].set_base_tint(veiled.lerp(lit, amount))

func _check_win() -> void:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var np: Vector2i = dodo_pos + d
		if not _in_bounds(np):
			continue
		if tiles[np.y][np.x].state != Tile.State.REVEALED:
			continue
		won = true
		log_label.text = "Você alcançou o Dodo. Ele está livre!"
		_show_end_after_cascade("DODO LIVRE!", "Você abriu caminho até o centro da ilha.")
		print("Dodo libertado.")
		return

func _lose(exploded_tile: Tile) -> void:
	game_over = true
	exploded_tile.show_as_exploded()
	var epicenter: Vector2i = exploded_tile.grid_pos
	var max_delay := 0.0
	for row in tiles:
		for t in row:
			if t == exploded_tile:
				continue
			var ring: int = maxi(
				absi(t.grid_pos.x - epicenter.x),
				absi(t.grid_pos.y - epicenter.y)
			)
			var delay: float = Tile.defeat_delay(ring)
			if t.is_bomb and t.state != Tile.State.FLAGGED:
				t.show_as_bomb(delay)
				max_delay = maxf(max_delay, delay)
			elif not t.is_bomb and t.state == Tile.State.FLAGGED:
				t.show_as_wrong_flag(delay)
				max_delay = maxf(max_delay, delay)
	_note_cascade(max_delay)
	log_label.text = "A armadilha disparou. O Dodo continua preso."
	_show_end_after_cascade("O DODO CONTINUA PRESO", "Você chegou até a %s." % ZONE_NAMES[unlocked_zone])
	print("Derrota na zona %d." % [unlocked_zone + 1])

func _note_cascade(max_delay: float) -> void:
	cascade_end_msec = maxi(cascade_end_msec, Tile.cascade_finish_msec(max_delay))

func _show_end_after_cascade(main_text: String, subtitle_text: String) -> void:
	var remaining: float = float(cascade_end_msec - Time.get_ticks_msec()) / 1000.0
	if remaining <= 0.0:
		_show_end(main_text, subtitle_text)
		return
	var timer := get_tree().create_timer(remaining)
	timer.timeout.connect(_on_cascade_settled.bind(run_id, main_text, subtitle_text))

func _on_cascade_settled(expected_run: int, main_text: String, subtitle_text: String) -> void:
	if run_id != expected_run:
		return
	_show_end(main_text, subtitle_text)

func _show_end(main_text: String, subtitle_text: String) -> void:
	end_message_label.text = main_text
	end_subtitle_label.text = subtitle_text
	end_overlay.visible = true

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://menu.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
