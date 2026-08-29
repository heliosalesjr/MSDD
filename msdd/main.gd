extends Node2D

const GRID_SIZE := 10
const TILE_SIZE := 16
const SCALE_FACTOR := 3
const CELL_PX := TILE_SIZE * SCALE_FACTOR
const BOMB_COUNT := 15

const KEY_SHEET := preload("res://assets/minesweeper_tiles/KeyFly-Sheet.png")
const KEY_FRAME_SIZE := 64
const KEY_FRAME_COUNT := 4
const KEY_ANIMATION_FPS := 6.0
const KEY_POINTS := 100

const TIME_LIMIT := 15.0
const ADVANCE_DELAY := 1.0
const KEYS_TO_ADVANCE := 5

var tiles: Array = []
var first_click_done: bool = false
var game_over: bool = false
var non_bomb_revealed: int = 0
var non_bomb_total: int = 0

var key_sprite: AnimatedSprite2D
var key_pos: Vector2i
var key_placed: bool = false
var key_found: bool = false
var score: int = 0

var time_remaining: float = 0.0
var timer_running: bool = false
var advancing: bool = false
var advance_timer: float = 0.0
var keys_found_this_run: int = 0
var won_run: bool = false

var base_position: Vector2 = Vector2.ZERO

var ui_layer: CanvasLayer
var timer_label: Label
var keys_label: Label
var danger_overlay: ColorRect
var coming_soon_overlay: Control

func _ready() -> void:
	_build_grid()
	_setup_key_sprite()
	_setup_ui()
	_center_grid()
	get_viewport().size_changed.connect(_center_grid)
	_reset_run()

func _build_grid() -> void:
	for y in GRID_SIZE:
		var row: Array = []
		for x in GRID_SIZE:
			var t := Tile.new()
			t.grid_pos = Vector2i(x, y)
			t.position = Vector2(x, y) * CELL_PX
			t.scale = Vector2.ONE * SCALE_FACTOR
			add_child(t)
			row.append(t)
		tiles.append(row)

func _setup_key_sprite() -> void:
	var frames := SpriteFrames.new()
	frames.set_animation_loop("default", true)
	frames.set_animation_speed("default", KEY_ANIMATION_FPS)
	for i in KEY_FRAME_COUNT:
		var atlas := AtlasTexture.new()
		atlas.atlas = KEY_SHEET
		atlas.region = Rect2(i * KEY_FRAME_SIZE, 0, KEY_FRAME_SIZE, KEY_FRAME_SIZE)
		frames.add_frame("default", atlas)

	key_sprite = AnimatedSprite2D.new()
	key_sprite.sprite_frames = frames
	key_sprite.animation = "default"
	key_sprite.scale = Vector2.ONE * (SCALE_FACTOR * 0.5)
	key_sprite.visible = false
	key_sprite.z_index = 1
	add_child(key_sprite)

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
	keys_label.text = "0 / %d" % KEYS_TO_ADVANCE
	ui_layer.add_child(keys_label)

	coming_soon_overlay = Control.new()
	coming_soon_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	coming_soon_overlay.visible = false
	coming_soon_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var cs_bg := ColorRect.new()
	cs_bg.color = Color(0, 0, 0, 0.92)
	cs_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	cs_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coming_soon_overlay.add_child(cs_bg)

	var cs_label := Label.new()
	cs_label.text = "COMING SOON\n\n(R pra reiniciar)"
	cs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cs_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cs_label.add_theme_font_size_override("font_size", 48)
	cs_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	cs_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coming_soon_overlay.add_child(cs_label)

	ui_layer.add_child(coming_soon_overlay)

func _center_grid() -> void:
	var viewport_size := get_viewport_rect().size
	var grid_px := GRID_SIZE * CELL_PX
	base_position = ((viewport_size - Vector2(grid_px, grid_px)) * 0.5).floor()
	position = base_position

func _reset_run() -> void:
	keys_found_this_run = 0
	won_run = false
	score = 0
	coming_soon_overlay.visible = false
	_new_dungeon()

func _new_dungeon() -> void:
	first_click_done = false
	game_over = false
	advancing = false
	non_bomb_revealed = 0
	non_bomb_total = GRID_SIZE * GRID_SIZE - BOMB_COUNT
	key_placed = false
	key_found = false
	key_sprite.visible = false
	key_sprite.stop()
	time_remaining = TIME_LIMIT
	timer_running = false
	position = base_position
	danger_overlay.color.a = 0.0
	for row in tiles:
		for t in row:
			t.reset()
	_update_ui()
	print("Dungeon %d/%d — %d bombas. Score: %d" % [keys_found_this_run + 1, KEYS_TO_ADVANCE, BOMB_COUNT, score])

func _place_bombs(safe_center: Vector2i) -> void:
	var safe_zone := {}
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			safe_zone[safe_center + Vector2i(dx, dy)] = true

	var candidates: Array[Vector2i] = []
	for y in GRID_SIZE:
		for x in GRID_SIZE:
			var p := Vector2i(x, y)
			if not safe_zone.has(p):
				candidates.append(p)

	candidates.shuffle()
	var count: int = min(BOMB_COUNT, candidates.size())
	for i in count:
		var p: Vector2i = candidates[i]
		tiles[p.y][p.x].is_bomb = true

	for y in GRID_SIZE:
		for x in GRID_SIZE:
			if not tiles[y][x].is_bomb:
				tiles[y][x].adjacent_bombs = _count_adjacent_bombs(x, y)

func _place_key(safe_center: Vector2i) -> void:
	var safe_zone := {}
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			safe_zone[safe_center + Vector2i(dx, dy)] = true

	var candidates: Array[Vector2i] = []
	for y in GRID_SIZE:
		for x in GRID_SIZE:
			var p := Vector2i(x, y)
			if safe_zone.has(p):
				continue
			var t: Tile = tiles[p.y][p.x]
			if t.is_bomb:
				continue
			if t.adjacent_bombs < 1:
				continue
			candidates.append(p)

	if candidates.is_empty():
		push_warning("Nenhum candidato válido pra chave — placement pulado")
		return

	candidates.shuffle()
	key_pos = candidates[0]
	key_placed = true
	tiles[key_pos.y][key_pos.x].has_key = true

	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var np := key_pos + Vector2i(dx, dy)
			if np.x < 0 or np.x >= GRID_SIZE or np.y < 0 or np.y >= GRID_SIZE:
				continue
			var nt: Tile = tiles[np.y][np.x]
			if not nt.is_bomb:
				nt.is_gold_adjacent = true

	key_sprite.position = Vector2(key_pos) * CELL_PX + Vector2.ONE * CELL_PX * 0.5

func _count_adjacent_bombs(cx: int, cy: int) -> int:
	var n := 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx: int = cx + dx
			var ny: int = cy + dy
			if nx < 0 or nx >= GRID_SIZE or ny < 0 or ny >= GRID_SIZE:
				continue
			if tiles[ny][nx].is_bomb:
				n += 1
	return n

func _process(delta: float) -> void:
	if advancing:
		advance_timer -= delta
		if advance_timer <= 0.0:
			advancing = false
			if keys_found_this_run >= KEYS_TO_ADVANCE:
				_win_run()
			else:
				_new_dungeon()
		return

	if timer_running and not game_over:
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
	keys_label.text = "%d / %d" % [keys_found_this_run, KEYS_TO_ADVANCE]

	var color := Color.WHITE
	if time_remaining < 5.0:
		color = Color(1.0, 0.25, 0.25)
	elif time_remaining < 10.0:
		color = Color(1.0, 0.85, 0.2)
	timer_label.add_theme_color_override("font_color", color)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_reset_run()
		return

	if game_over or advancing or won_run:
		return
	if not (event is InputEventMouseButton) or not event.pressed:
		return

	var local := to_local(event.position)
	var gx := int(local.x / CELL_PX)
	var gy := int(local.y / CELL_PX)
	if gx < 0 or gx >= GRID_SIZE or gy < 0 or gy >= GRID_SIZE:
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

	if not first_click_done:
		_place_bombs(Vector2i(x, y))
		_place_key(Vector2i(x, y))
		first_click_done = true
		timer_running = true

	if t.is_bomb:
		_lose(t)
		return

	_flood_reveal(x, y)
	_check_key_found()
	if not advancing:
		_check_win()

func _handle_right(x: int, y: int) -> void:
	tiles[y][x].cycle_mark()

func _flood_reveal(sx: int, sy: int) -> void:
	var queue: Array[Vector2i] = [Vector2i(sx, sy)]
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		var t: Tile = tiles[p.y][p.x]
		if t.state == Tile.State.REVEALED or t.state == Tile.State.FLAGGED:
			continue
		if t.is_bomb:
			continue
		if t.reveal():
			non_bomb_revealed += 1
		if t.adjacent_bombs == 0:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var nx: int = p.x + dx
					var ny: int = p.y + dy
					if nx < 0 or nx >= GRID_SIZE or ny < 0 or ny >= GRID_SIZE:
						continue
					queue.push_back(Vector2i(nx, ny))

func _check_key_found() -> void:
	if not key_placed or key_found:
		return
	var t: Tile = tiles[key_pos.y][key_pos.x]
	if t.state != Tile.State.REVEALED:
		return
	key_found = true
	keys_found_this_run += 1
	score += KEY_POINTS
	key_sprite.visible = true
	key_sprite.play()
	timer_running = false
	advancing = true
	advance_timer = ADVANCE_DELAY
	print("Chave %d/%d encontrada! +%d pts (total: %d)" % [keys_found_this_run, KEYS_TO_ADVANCE, KEY_POINTS, score])

func _timeout() -> void:
	game_over = true
	timer_running = false
	position = base_position
	danger_overlay.color.a = 0.0
	_reveal_board_on_loss()
	print("Tempo esgotado! R pra reiniciar. Score final: %d" % score)

func _lose(exploded_tile: Tile) -> void:
	game_over = true
	timer_running = false
	position = base_position
	danger_overlay.color.a = 0.0
	exploded_tile.show_as_exploded()
	_reveal_board_on_loss(exploded_tile)
	print("Boom! R pra reiniciar. Score final: %d" % score)

func _reveal_board_on_loss(exploded_tile: Tile = null) -> void:
	for row in tiles:
		for t in row:
			if t == exploded_tile:
				continue
			if t.is_bomb and t.state != Tile.State.FLAGGED:
				t.show_as_bomb()
			elif not t.is_bomb and t.state == Tile.State.FLAGGED:
				t.show_as_wrong_flag()
	if key_placed and not key_found:
		key_sprite.visible = true
		key_sprite.play()

func _check_win() -> void:
	if non_bomb_revealed >= non_bomb_total:
		game_over = true
		timer_running = false
		for row in tiles:
			for t in row:
				if t.is_bomb and t.state != Tile.State.FLAGGED:
					t.flag()
		print("Board limpo! (chave já foi contabilizada) Score: %d" % score)

func _win_run() -> void:
	won_run = true
	timer_running = false
	position = base_position
	danger_overlay.color.a = 0.0
	coming_soon_overlay.visible = true
	print("VITÓRIA — 5 chaves! Coming Soon. R pra reiniciar. Score final: %d" % score)
