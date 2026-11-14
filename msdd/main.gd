extends Node2D

const GRID_WIDTH := 24
const GRID_HEIGHT := 14
const TILE_SIZE := 16
const SCALE_FACTOR := 2
const CELL_PX := TILE_SIZE * SCALE_FACTOR
const BOMB_COUNT := 50

const KEY_SHEET := preload("res://assets/minesweeper_tiles/KeyFly-Sheet.png")
const KEY_FRAME_SIZE := 64
const KEY_FRAME_COUNT := 4
const KEY_ANIMATION_FPS := 6.0
const KEY_POINTS := 100
const KEY_SCALE := 1.5
const KEYS_TO_WIN := 5
const KEY_MIN_DISTANCE := 4

const KEY_COLORS := [
	Color(1.2, 0.4, 0.4),    # vermelho
	Color(0.4, 0.6, 1.2),    # azul
	Color(0.4, 1.2, 0.4),    # verde
	Color(1.2, 1.2, 0.4),    # amarelo
	Color(0.75, 0.75, 0.8),  # cinza
]

const TIME_LIMIT := 15.0

# --- Bônus de tempo (relógio) ---
# O relógio é a válvula de escape da corrida: 5 segundos a mais pra quem abre a
# casa certa. Ele fica escondido dentro do tile, como as moedas do protótipo 4 —
# só salta quando a casa abre. O que a regra controla é a hora de ESCONDER: nada
# é alocado antes do quinto clique, senão a cascata de abertura engoliria os
# bônus antes de o tempo começar a apertar. No máximo três por partida, pra que
# a corrida continue sendo uma corrida.
const CLOCK_BONUS_SECONDS := 5.0
const CLOCK_MAX_PER_RUN := 3
const CLOCK_MIN_CLICKS := 5
# Chance de esconder um relógio num clique elegível.
const CLOCK_SPAWN_CHANCE := 0.40
# Quantos podem estar escondidos ao mesmo tempo, esperando ser achados.
const CLOCK_MAX_HIDDEN := 2
# Distância (Chebyshev) do clique até a casa escolhida. O relógio é escondido
# na borda do campo aberto, no caminho que o jogador já está trilhando — longe
# demais ele nunca seria achado, e um bônus que não se acha não ajuda ninguém.
# A casa nunca tem bomba nem chave.
const CLOCK_MIN_RANGE := 1
const CLOCK_MAX_RANGE := 5

const CLOCK_PX := 15
const CLOCK_FRAME_COUNT := 8
const CLOCK_FPS := 8.0
const CLOCK_SCALE := 1.6
# Giro um pouco diferente em cada relógio, pra dois achados juntos não
# andarem em uníssono.
const CLOCK_SPIN_SCALE := Vector2(0.80, 1.40)

# O salto é a mesma parábola integrada das moedas: sai com CLOCK_LAUNCH, a
# gravidade o traz de volta, quica uma vez e se apaga no apogeu do quique.
const CLOCK_LAUNCH := 150.0        # velocidade de saída, px/s
const CLOCK_GRAVITY := 340.0       # px/s²
const CLOCK_RESTITUTION := 0.45    # quanto sobra da velocidade no quique
const CLOCK_DRIFT_MAX := 12.0      # deriva lateral ao longo do voo, px
const CLOCK_LAUNCH_JITTER := 0.12

# Quanto tempo o cronômetro fica verde depois de um bônus.
const CLOCK_FLASH_TIME := 0.7
const CLOCK_ACCENT := Color(0.45, 1.0, 0.55)
# O "+5s" sobe do lugar da casa e se apaga.
const CLOCK_POPUP_RISE := 34.0
const CLOCK_POPUP_TIME := 0.9

const CLOCK_RIM := Color(0.88, 0.74, 0.26)
const CLOCK_RIM_SHADE := Color(0.55, 0.42, 0.12)
const CLOCK_FACE := Color(0.97, 0.96, 0.90)
const CLOCK_FACE_SHADE := Color(0.78, 0.76, 0.70)
const CLOCK_MARK := Color(0.45, 0.42, 0.40)
const CLOCK_HAND := Color(0.13, 0.12, 0.16)

var tiles: Array = []
var first_click_done: bool = false
var game_over: bool = false
var won_run: bool = false

var key_sprites: Array[AnimatedSprite2D] = []
var key_positions: Array[Vector2i] = []
var keys_found_flags: Array[bool] = []
var keys_found_count: int = 0
var score: int = 0

var time_remaining: float = 0.0
var timer_running: bool = false

# --- Bônus de tempo ---
# Cliques que abriram alguma casa nesta partida: é o que destrava a alocação.
var clicks_done: int = 0
var clocks_placed: int = 0
var clock_sprites: Array[AnimatedSprite2D] = []
var clock_cell: Array[Vector2i] = []   # casa de cada relógio do pool
var clock_hidden: Array[bool] = []     # escondido no campo, ainda não achado
var clock_home: Array[Vector2] = []    # centro da casa, de onde ele salta
var clock_tweens: Array = []           # tween do salto, ou null
var clock_flight: Array = []           # parâmetros do voo atual
var clock_at: Dictionary = {}          # Vector2i -> índice no pool
var clock_flash_until_msec: int = 0

var base_position: Vector2 = Vector2.ZERO

# Quando a última cascata agendada termina de abrir (ms do relógio do engine).
# O ritmo da onda (passo por anel, jitter) vive em tile.gd.
var cascade_end_msec: int = 0
# Incrementa a cada partida, pra descartar timers de uma run já encerrada.
var run_id: int = 0
# Epicentro da onda quando o tempo esgota: não há bomba pisada, então a
# revelação irradia de onde a atenção do jogador estava.
var last_click_pos: Vector2i = Vector2i(GRID_WIDTH >> 1, GRID_HEIGHT >> 1)

var ui_layer: CanvasLayer
var timer_label: Label
var keys_label: Label
var danger_overlay: ColorRect
var end_overlay: Control
var end_message_label: Label
var end_subtitle_label: Label

func _ready() -> void:
	_build_grid()
	_setup_key_sprites()
	_setup_clock_sprites()
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

func _setup_key_sprites() -> void:
	var frames := SpriteFrames.new()
	frames.set_animation_loop("default", true)
	frames.set_animation_speed("default", KEY_ANIMATION_FPS)
	for i in KEY_FRAME_COUNT:
		var atlas := AtlasTexture.new()
		atlas.atlas = KEY_SHEET
		atlas.region = Rect2(i * KEY_FRAME_SIZE, 0, KEY_FRAME_SIZE, KEY_FRAME_SIZE)
		frames.add_frame("default", atlas)

	for i in KEYS_TO_WIN:
		var s := AnimatedSprite2D.new()
		s.sprite_frames = frames
		s.animation = "default"
		s.scale = Vector2.ONE * KEY_SCALE
		s.visible = false
		s.z_index = 1
		s.modulate = KEY_COLORS[i]
		s.play()
		add_child(s)
		key_sprites.append(s)

func _setup_clock_sprites() -> void:
	var frames := SpriteFrames.new()
	frames.set_animation_loop("default", true)
	frames.set_animation_speed("default", CLOCK_FPS)
	for tex in _make_clock_frames():
		frames.add_frame("default", tex)

	for _i in CLOCK_MAX_PER_RUN:
		var s := AnimatedSprite2D.new()
		s.sprite_frames = frames
		s.animation = "default"
		s.scale = Vector2.ONE * CLOCK_SCALE
		s.visible = false
		s.z_index = 10   # acima dos tiles, inclusive do pop deles (que sobe pra 1)
		add_child(s)
		clock_sprites.append(s)
		clock_cell.append(Vector2i(-1, -1))
		clock_hidden.append(false)
		clock_home.append(Vector2.ZERO)
		clock_tweens.append(null)
		clock_flight.append({})

# Um relógio de bolso desenhado na mão, no espírito das moedas do protótipo 4:
# aro dourado, mostrador claro e os dois ponteiros girando — o de minutos dá a
# volta completa em CLOCK_FRAME_COUNT quadros, o de horas anda um quarto disso.
# É o giro que diz "tempo" de longe, mesmo num sprite de 15 px.
func _make_clock_frames() -> Array:
	var out: Array = []
	var c := (CLOCK_PX - 1) * 0.5
	var r := CLOCK_PX * 0.5 - 1.5
	# O mostrador desce 1 px pra abrir espaço pra coroa no topo.
	var center := Vector2(c, c + 1.0)
	for f in CLOCK_FRAME_COUNT:
		var img := Image.create(CLOCK_PX, CLOCK_PX, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for y in CLOCK_PX:
			for x in CLOCK_PX:
				var d: float = Vector2(x, y).distance_to(center) / r
				if d > 1.0:
					continue
				# Luz vinda do canto superior-esquerdo, como nas moedas.
				var lum: float = -((x - center.x) * 0.55 + (y - center.y) * 0.78) / r
				var col: Color
				if d > 0.76:
					col = CLOCK_RIM if lum > -0.25 else CLOCK_RIM_SHADE
				else:
					col = CLOCK_FACE if lum > -0.45 else CLOCK_FACE_SHADE
				img.set_pixel(x, y, col)
		# Marcas das 12, 3, 6 e 9.
		for i in 4:
			var a: float = TAU * float(i) / 4.0
			_plot(img, center + Vector2(sin(a), -cos(a)) * r * 0.62, CLOCK_MARK)
		# Coroa, no topo.
		_plot(img, Vector2(center.x, center.y - r - 1.0), CLOCK_RIM)
		_plot(img, Vector2(center.x, center.y - r - 2.0), CLOCK_RIM_SHADE)
		# Ponteiros e o pino do centro.
		var minute: float = TAU * float(f) / float(CLOCK_FRAME_COUNT)
		_draw_hand(img, center, minute, r * 0.70)
		_draw_hand(img, center, minute * 0.25, r * 0.45)
		_plot(img, center, CLOCK_HAND)
		out.append(ImageTexture.create_from_image(img))
	return out

# Ponteiro: uma linha do centro pra fora, amostrada de meio em meio pixel pra
# não abrir buraco nas diagonais.
func _draw_hand(img: Image, center: Vector2, angle: float, length: float) -> void:
	var dir := Vector2(sin(angle), -cos(angle))
	var steps: int = int(length * 2.0) + 1
	for i in range(1, steps + 1):
		_plot(img, center + dir * (length * float(i) / float(steps)), CLOCK_HAND)

func _plot(img: Image, p: Vector2, col: Color) -> void:
	var px: int = int(round(p.x))
	var py: int = int(round(p.y))
	if px < 0 or px >= img.get_width() or py < 0 or py >= img.get_height():
		return
	img.set_pixel(px, py, col)

func _setup_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	danger_overlay = ColorRect.new()
	danger_overlay.color = Color(1, 0, 0, 0)
	danger_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	danger_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(danger_overlay)

	timer_label = Label.new()
	timer_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	timer_label.offset_top = 15
	timer_label.offset_bottom = 75
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 48)
	timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_label.text = "%0.1f" % TIME_LIMIT
	ui_layer.add_child(timer_label)

	keys_label = Label.new()
	keys_label.position = Vector2(20, 20)
	keys_label.add_theme_font_size_override("font_size", 24)
	keys_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	keys_label.text = "0 / %d" % KEYS_TO_WIN
	ui_layer.add_child(keys_label)

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

func _center_grid() -> void:
	var viewport_size := get_viewport_rect().size
	var grid_px := Vector2(GRID_WIDTH, GRID_HEIGHT) * CELL_PX
	base_position = ((viewport_size - grid_px) * 0.5).floor()
	position = base_position

func _reset_run() -> void:
	run_id += 1
	cascade_end_msec = 0
	first_click_done = false
	game_over = false
	won_run = false
	keys_found_count = 0
	key_positions.clear()
	keys_found_flags.clear()
	for s in key_sprites:
		s.visible = false
	score = 0
	time_remaining = TIME_LIMIT
	timer_running = false
	_reset_clocks()
	position = base_position
	danger_overlay.color.a = 0.0
	end_overlay.visible = false
	for row in tiles:
		for t in row:
			t.reset()
	_update_ui()
	print("Nova partida — %d bombas, %d chaves." % [BOMB_COUNT, KEYS_TO_WIN])

func _place_bombs(safe_center: Vector2i) -> void:
	var safe_zone := {}
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			safe_zone[safe_center + Vector2i(dx, dy)] = true

	var candidates: Array[Vector2i] = []
	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			var p := Vector2i(x, y)
			if not safe_zone.has(p):
				candidates.append(p)

	candidates.shuffle()
	var count: int = min(BOMB_COUNT, candidates.size())
	for i in count:
		var p: Vector2i = candidates[i]
		tiles[p.y][p.x].is_bomb = true

	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			if not tiles[y][x].is_bomb:
				tiles[y][x].adjacent_bombs = _count_adjacent_bombs(x, y)

func _place_keys(safe_center: Vector2i) -> void:
	var safe_zone := {}
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			safe_zone[safe_center + Vector2i(dx, dy)] = true

	var candidates: Array[Vector2i] = []
	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			var p := Vector2i(x, y)
			if safe_zone.has(p):
				continue
			var t: Tile = tiles[p.y][p.x]
			if t.is_bomb:
				continue
			if t.adjacent_bombs < 1:
				continue
			candidates.append(p)

	if candidates.size() < KEYS_TO_WIN:
		push_warning("Poucos candidatos pra 5 chaves (%d)" % candidates.size())
		return

	var placed: Array[Vector2i] = []
	var min_dist := KEY_MIN_DISTANCE
	while placed.size() < KEYS_TO_WIN and min_dist >= 3:
		placed = _try_place_keys(candidates, min_dist)
		if placed.size() < KEYS_TO_WIN:
			min_dist -= 1

	if placed.size() < KEYS_TO_WIN:
		push_warning("Placement incompleto: %d chaves posicionadas" % placed.size())

	for i in placed.size():
		_apply_key_placement(i, placed[i])

func _try_place_keys(candidates: Array[Vector2i], min_dist: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var attempts_per_key := 100
	for _key_idx in KEYS_TO_WIN:
		var placed_this := false
		for _try in attempts_per_key:
			var c: Vector2i = candidates[randi() % candidates.size()]
			var valid := true
			for prev in result:
				if maxi(absi(c.x - prev.x), absi(c.y - prev.y)) < min_dist:
					valid = false
					break
			if valid:
				result.append(c)
				placed_this = true
				break
		if not placed_this:
			return result
	return result

func _apply_key_placement(idx: int, pos: Vector2i) -> void:
	key_positions.append(pos)
	keys_found_flags.append(false)
	var color: Color = KEY_COLORS[idx]

	var key_tile: Tile = tiles[pos.y][pos.x]
	key_tile.has_key = true
	key_tile.hint_rect = Rect2(0.0, 0.0, 1.0, 1.0)
	key_tile.hint_color = color

	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var np := pos + Vector2i(dx, dy)
			if np.x < 0 or np.x >= GRID_WIDTH or np.y < 0 or np.y >= GRID_HEIGHT:
				continue
			var nt: Tile = tiles[np.y][np.x]
			if nt.is_bomb:
				continue
			nt.hint_rect = _rect_toward(-dx, -dy)
			nt.hint_color = color

	var sprite: AnimatedSprite2D = key_sprites[idx]
	sprite.position = Vector2(pos) * CELL_PX + Vector2.ONE * CELL_PX * 0.5

func _rect_toward(tx: int, ty: int) -> Rect2:
	var rx := 0.0
	var ry := 0.0
	var rw := 1.0
	var rh := 1.0
	if tx > 0:
		rx = 0.5
		rw = 0.5
	elif tx < 0:
		rw = 0.5
	if ty > 0:
		ry = 0.5
		rh = 0.5
	elif ty < 0:
		rh = 0.5
	return Rect2(rx, ry, rw, rh)

func _count_adjacent_bombs(cx: int, cy: int) -> int:
	var n := 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx: int = cx + dx
			var ny: int = cy + dy
			if nx < 0 or nx >= GRID_WIDTH or ny < 0 or ny >= GRID_HEIGHT:
				continue
			if tiles[ny][nx].is_bomb:
				n += 1
	return n

func _process(delta: float) -> void:
	if timer_running and not game_over and not won_run:
		time_remaining -= delta
		if time_remaining <= 0.0:
			time_remaining = 0.0
			_timeout()

	_update_dramatic_effects()
	_update_ui()

func _update_dramatic_effects() -> void:
	if not timer_running or game_over or won_run:
		position = base_position
		danger_overlay.color.a = 0.0
		return

	var shake_amp := 0.0
	if time_remaining < 3.0:
		shake_amp = (3.0 - time_remaining) * 2.5
	var shake := Vector2(randf_range(-shake_amp, shake_amp), randf_range(-shake_amp, shake_amp))
	position = base_position + shake

	if time_remaining < 7.5:
		var intensity: float = 1.0 - (time_remaining / 7.5)
		var pulse_speed: float = 3.0 + intensity * 6.0
		var pulse: float = (sin(Time.get_ticks_msec() / 1000.0 * pulse_speed * TAU) + 1.0) * 0.5
		danger_overlay.color.a = intensity * 0.28 + intensity * 0.15 * pulse
	else:
		danger_overlay.color.a = 0.0

func _update_ui() -> void:
	timer_label.text = "%0.1f" % time_remaining
	keys_label.text = "%d / %d" % [keys_found_count, KEYS_TO_WIN]

	var color := Color.WHITE
	if Time.get_ticks_msec() < clock_flash_until_msec:
		color = CLOCK_ACCENT
	elif time_remaining < 5.0:
		color = Color(1.0, 0.25, 0.25)
	elif time_remaining < 10.0:
		color = Color(1.0, 0.85, 0.2)
	timer_label.add_theme_color_override("font_color", color)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_reset_run()
		return

	if game_over or won_run:
		return
	if not (event is InputEventMouseButton) or not event.pressed:
		return

	var local := to_local(event.position)
	var gx := int(local.x / CELL_PX)
	var gy := int(local.y / CELL_PX)
	if gx < 0 or gx >= GRID_WIDTH or gy < 0 or gy >= GRID_HEIGHT:
		return

	match event.button_index:
		MOUSE_BUTTON_LEFT:
			_handle_left(gx, gy)
		MOUSE_BUTTON_RIGHT:
			_handle_right(gx, gy)

func _handle_left(x: int, y: int) -> void:
	var t: Tile = tiles[y][x]
	if t.state == Tile.State.FLAGGED or t.state == Tile.State.REVEALED:
		return

	last_click_pos = Vector2i(x, y)
	clicks_done += 1

	if not first_click_done:
		_place_bombs(Vector2i(x, y))
		_place_keys(Vector2i(x, y))
		first_click_done = true
		timer_running = true

	if t.is_bomb:
		_lose(t)
		return

	_flood_reveal(x, y)
	# A chave primeiro: ela recarrega o cronômetro, e o bônus soma por cima.
	_check_keys_found()
	_collect_clocks()
	_maybe_hide_clock()

func _handle_right(x: int, y: int) -> void:
	tiles[y][x].cycle_mark()

# O estado lógico (REVEALED, score, timer) muda na hora; só a abertura visual
# é escalonada, pra que a animação nunca custe tempo ao jogador.
func _flood_reveal(sx: int, sy: int) -> void:
	# Cada entrada é [posição, anel]. BFS garante que o primeiro visitante de
	# um tile chega pelo caminho mais curto, ou seja, pelo menor anel.
	var queue: Array = [[Vector2i(sx, sy), 0]]
	var max_delay := 0.0
	while not queue.is_empty():
		var entry: Array = queue.pop_front()
		var p: Vector2i = entry[0]
		var ring: int = entry[1]
		var t: Tile = tiles[p.y][p.x]
		if t.state == Tile.State.REVEALED or t.state == Tile.State.FLAGGED:
			continue
		if t.is_bomb:
			continue
		var delay: float = Tile.cascade_delay(ring)
		max_delay = maxf(max_delay, delay)
		t.reveal(delay)
		if t.adjacent_bombs == 0:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var nx: int = p.x + dx
					var ny: int = p.y + dy
					if nx < 0 or nx >= GRID_WIDTH or ny < 0 or ny >= GRID_HEIGHT:
						continue
					queue.push_back([Vector2i(nx, ny), ring + 1])
	_note_cascade(max_delay)

func _note_cascade(max_delay: float) -> void:
	cascade_end_msec = maxi(cascade_end_msec, Tile.cascade_finish_msec(max_delay))

# Deixa a onda em curso assentar antes de cobrir a tela com o overlay.
func _show_end_after_cascade(main_text: String, subtitle_text: String) -> void:
	var remaining: float = float(cascade_end_msec - Time.get_ticks_msec()) / 1000.0
	if remaining <= 0.0:
		_show_end(main_text, subtitle_text)
		return
	var timer := get_tree().create_timer(remaining)
	timer.timeout.connect(_on_cascade_settled.bind(run_id, main_text, subtitle_text))

func _on_cascade_settled(expected_run: int, main_text: String, subtitle_text: String) -> void:
	# Um reset durante a espera invalida este fim de partida.
	if run_id != expected_run:
		return
	_show_end(main_text, subtitle_text)

func _check_keys_found() -> void:
	var any_found := false
	for i in key_positions.size():
		if keys_found_flags[i]:
			continue
		var t: Tile = tiles[key_positions[i].y][key_positions[i].x]
		if t.state != Tile.State.REVEALED:
			continue
		keys_found_flags[i] = true
		keys_found_count += 1
		score += KEY_POINTS
		_show_key_when_tile_opens(i)
		any_found = true
		print("Chave %d/%d encontrada!" % [keys_found_count, KEYS_TO_WIN])

	if any_found:
		# Recarga, nunca corte: se os bônus deixaram o relógio acima do teto,
		# a chave não pode cobrar essa sobra de volta.
		time_remaining = maxf(time_remaining, TIME_LIMIT)
		if keys_found_count >= KEYS_TO_WIN:
			_win_run()

# A chave aparece quando o tile dela abre, não quando a lógica a encontra —
# senão o sprite flutuaria sobre uma tampa ainda fechada. O score e o reset
# do timer continuam imediatos: a animação não cobra tempo do jogador.
func _show_key_when_tile_opens(idx: int) -> void:
	var pos: Vector2i = key_positions[idx]
	var wait: float = tiles[pos.y][pos.x].time_until_open()
	_show_key_sprite_after(idx, wait)

func _show_key_sprite_after(idx: int, wait: float) -> void:
	if wait <= 0.0:
		key_sprites[idx].visible = true
		return
	get_tree().create_timer(wait).timeout.connect(_reveal_key_sprite.bind(idx, run_id))

func _reveal_key_sprite(idx: int, expected_run: int) -> void:
	if run_id != expected_run:
		return
	key_sprites[idx].visible = true

# --- Bônus de tempo ---

func _reset_clocks() -> void:
	clicks_done = 0
	clocks_placed = 0
	clock_at.clear()
	clock_flash_until_msec = 0
	for i in clock_sprites.size():
		var tw: Tween = clock_tweens[i]
		if tw != null and tw.is_valid():
			tw.kill()
		clock_tweens[i] = null
		clock_flight[i] = {}
		clock_cell[i] = Vector2i(-1, -1)
		clock_hidden[i] = false
		clock_home[i] = Vector2.ZERO
		var s: AnimatedSprite2D = clock_sprites[i]
		s.visible = false
		s.stop()
		s.modulate = Color.WHITE
		s.scale = Vector2.ONE * CLOCK_SCALE

# A alocação roda no fim de cada clique, do quinto em diante. Esconder depois do
# clique (e não no início da partida) é o que faz a regra valer: o relógio vai
# pra uma casa que ainda está fechada agora, na borda do que acabou de abrir.
func _maybe_hide_clock() -> void:
	if game_over or won_run:
		return
	if clocks_placed >= CLOCK_MAX_PER_RUN:
		return
	if clicks_done < CLOCK_MIN_CLICKS:
		return
	if _hidden_clock_count() >= CLOCK_MAX_HIDDEN:
		return
	if randf() > CLOCK_SPAWN_CHANCE:
		return
	var cell := _pick_clock_cell()
	if cell.x < 0:
		return
	_hide_clock_at(cell)

func _hidden_clock_count() -> int:
	var n := 0
	for hidden in clock_hidden:
		if hidden:
			n += 1
	return n

# Casa fechada, sem bomba e sem chave, perto do clique. Entre as candidatas, as
# que tocam o campo já aberto vêm primeiro: são as que o jogador tem chance de
# abrir em seguida, e um relógio escondido no breu morre sem ser achado.
func _pick_clock_cell() -> Vector2i:
	var touching: Array[Vector2i] = []
	var loose: Array[Vector2i] = []
	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			var p := Vector2i(x, y)
			var ring: int = maxi(
				absi(p.x - last_click_pos.x),
				absi(p.y - last_click_pos.y)
			)
			if ring < CLOCK_MIN_RANGE or ring > CLOCK_MAX_RANGE:
				continue
			var t: Tile = tiles[y][x]
			if t.is_bomb or t.has_key:
				continue
			if t.state != Tile.State.HIDDEN and t.state != Tile.State.QUESTIONED:
				continue
			if clock_at.has(p):
				continue
			if _touches_revealed(p):
				touching.append(p)
			else:
				loose.append(p)
	var pool: Array[Vector2i] = loose
	if not touching.is_empty():
		pool = touching
	if pool.is_empty():
		return Vector2i(-1, -1)
	return pool[randi() % pool.size()]

func _touches_revealed(p: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var np := p + Vector2i(dx, dy)
			if np.x < 0 or np.x >= GRID_WIDTH or np.y < 0 or np.y >= GRID_HEIGHT:
				continue
			if tiles[np.y][np.x].state == Tile.State.REVEALED:
				return true
	return false

# Esconder é só contabilidade: nada aparece na tela até a casa abrir.
func _hide_clock_at(cell: Vector2i) -> void:
	var idx := -1
	for i in clock_sprites.size():
		if clock_cell[i].x < 0:
			idx = i
			break
	if idx < 0:
		return

	clocks_placed += 1
	clock_cell[idx] = cell
	clock_hidden[idx] = true
	clock_home[idx] = Vector2(cell) * CELL_PX + Vector2.ONE * CELL_PX * 0.5
	clock_at[cell] = idx
	print("Relógio %d/%d escondido em %s." % [clocks_placed, CLOCK_MAX_PER_RUN, cell])

# Os segundos entram no instante em que a casa é aberta na lógica, igual às
# chaves: a animação nunca cobra tempo do jogador. Só o salto do relógio espera
# a tampa abrir, pra ele não pular de dentro de uma casa ainda fechada.
func _collect_clocks() -> void:
	for i in clock_sprites.size():
		if not clock_hidden[i]:
			continue
		var cell: Vector2i = clock_cell[i]
		var t: Tile = tiles[cell.y][cell.x]
		if t.state != Tile.State.REVEALED:
			continue
		clock_hidden[i] = false
		clock_at.erase(cell)
		time_remaining += CLOCK_BONUS_SECONDS
		clock_flash_until_msec = Time.get_ticks_msec() + int(CLOCK_FLASH_TIME * 1000.0)
		_schedule_clock_hop(i, t.time_until_open())
		print("Relógio achado: +%0.0fs (restam %0.1fs)." % [CLOCK_BONUS_SECONDS, time_remaining])

func _schedule_clock_hop(idx: int, wait: float) -> void:
	if wait <= 0.0:
		_play_clock_hop(idx)
		return
	get_tree().create_timer(wait).timeout.connect(_on_clock_hop_due.bind(idx, run_id))

func _on_clock_hop_due(idx: int, expected_run: int) -> void:
	# Um reset durante a espera invalida esta coleta.
	if run_id != expected_run:
		return
	_play_clock_hop(idx)

# O relógio salta da casa, gira no ar, quica uma vez e se apaga — e deixa um
# "+5s" subindo no lugar. Nada fica para trás: o registro do bônus é o
# cronômetro, que pisca verde no mesmo instante.
func _play_clock_hop(idx: int) -> void:
	var s: AnimatedSprite2D = clock_sprites[idx]
	var old: Tween = clock_tweens[idx]
	if old != null and old.is_valid():
		old.kill()

	s.position = clock_home[idx]
	s.scale = Vector2.ONE * CLOCK_SCALE
	s.modulate = Color.WHITE
	s.visible = true
	s.frame = randi() % CLOCK_FRAME_COUNT
	s.speed_scale = randf_range(CLOCK_SPIN_SCALE.x, CLOCK_SPIN_SCALE.y)
	s.play()

	var v0: float = CLOCK_LAUNCH * randf_range(
		1.0 - CLOCK_LAUNCH_JITTER, 1.0 + CLOCK_LAUNCH_JITTER
	)
	var g: float = CLOCK_GRAVITY
	var drift: float = randf_range(-CLOCK_DRIFT_MAX, CLOCK_DRIFT_MAX)
	# Arco inteiro (subida + queda), mais a SUBIDA do quique: é nela que o
	# relógio se apaga, então o voo termina no apogeu do quique.
	var first_arc: float = 2.0 * v0 / g
	var second_rise: float = CLOCK_RESTITUTION * v0 / g
	var total: float = first_arc + second_rise

	clock_flight[idx] = {
		"v0": v0, "g": g, "drift": drift,
		"total": total, "bounce": first_arc,
	}

	var tw := create_tween()
	# O tempo corre linear; quem desenha a curva é _clock_height.
	tw.tween_method(_set_clock_flight.bind(idx), 0.0, total, total).set_trans(Tween.TRANS_LINEAR)
	var fade_start: float = first_arc + second_rise * 0.30
	tw.parallel().tween_property(s, "modulate:a", 0.0, total - fade_start).set_delay(fade_start)
	tw.chain().tween_callback(_retire_clock.bind(idx))
	clock_tweens[idx] = tw

	_show_bonus_popup(clock_home[idx])

# Altura acima da casa no instante t do voo: dois arcos balísticos, o do
# lançamento e o do quique.
func _clock_height(t: float, f: Dictionary) -> float:
	var g: float = f["g"]
	var bounce: float = f["bounce"]
	if t < bounce:
		return maxf(f["v0"] * t - 0.5 * g * t * t, 0.0)
	var t2: float = t - bounce
	var v1: float = f["v0"] * CLOCK_RESTITUTION
	return maxf(v1 * t2 - 0.5 * g * t2 * t2, 0.0)

func _set_clock_flight(t: float, idx: int) -> void:
	var f: Dictionary = clock_flight[idx]
	if f.is_empty():
		return
	# Sem força horizontal, a deriva é velocidade constante: linear no tempo.
	var x: float = f["drift"] * (t / f["total"])
	clock_sprites[idx].position = clock_home[idx] + Vector2(x, -_clock_height(t, f))

func _retire_clock(idx: int) -> void:
	clock_sprites[idx].visible = false
	clock_sprites[idx].stop()
	clock_flight[idx] = {}

# O destaque do bônus: um "+5s" verde com contorno, subindo de onde o relógio
# estava. É o único texto que nasce dentro do tabuleiro, então ele vai contra a
# onda de tiles abrindo e precisa desse contorno pra se ler.
func _show_bonus_popup(at: Vector2) -> void:
	var lbl := Label.new()
	lbl.text = "+%0.0fs" % CLOCK_BONUS_SECONDS
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", CLOCK_ACCENT)
	lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.10, 0.04))
	lbl.add_theme_constant_override("outline_size", 8)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.z_index = 11
	lbl.position = at + Vector2(-24.0, -34.0)
	add_child(lbl)

	var tw := create_tween()
	tw.tween_property(
		lbl, "position", lbl.position + Vector2(0.0, -CLOCK_POPUP_RISE), CLOCK_POPUP_TIME
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(
		lbl, "modulate:a", 0.0, CLOCK_POPUP_TIME * 0.45
	).set_delay(CLOCK_POPUP_TIME * 0.55)
	tw.chain().tween_callback(lbl.queue_free)

func _timeout() -> void:
	game_over = true
	timer_running = false
	position = base_position
	danger_overlay.color.a = 0.0
	_reveal_board_on_loss(last_click_pos)
	_show_end_after_cascade("GAME OVER", "Tempo esgotado. Score: %d" % score)
	print("Tempo esgotado! Score final: %d" % score)

func _lose(exploded_tile: Tile) -> void:
	game_over = true
	timer_running = false
	position = base_position
	danger_overlay.color.a = 0.0
	exploded_tile.show_as_exploded()
	_reveal_board_on_loss(exploded_tile.grid_pos, exploded_tile)
	_show_end_after_cascade("GAME OVER", "Boom! Score: %d" % score)
	print("Boom! Score final: %d" % score)

# A revelação final irradia do epicentro em anéis de Chebyshev — aqui não há
# caminho aberto pra seguir, a onda é geométrica.
func _reveal_board_on_loss(epicenter: Vector2i, exploded_tile: Tile = null) -> void:
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
	# As chaves perdidas surgem conforme a onda passa por elas.
	for i in key_positions.size():
		if keys_found_flags[i]:
			continue
		var kp: Vector2i = key_positions[i]
		var key_ring: int = maxi(absi(kp.x - epicenter.x), absi(kp.y - epicenter.y))
		var key_delay: float = Tile.defeat_delay(key_ring)
		max_delay = maxf(max_delay, key_delay)
		_show_key_sprite_after(i, key_delay)
	_note_cascade(max_delay)

func _win_run() -> void:
	won_run = true
	timer_running = false
	position = base_position
	danger_overlay.color.a = 0.0
	_show_end_after_cascade("YOU WIN!", "Score final: %d" % score)
	print("YOU WIN! Score final: %d" % score)

func _show_end(main_text: String, subtitle_text: String) -> void:
	end_message_label.text = main_text
	end_subtitle_label.text = subtitle_text
	end_overlay.visible = true

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://menu.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
