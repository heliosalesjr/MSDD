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

var base_position: Vector2 = Vector2.ZERO

var ui_layer: CanvasLayer
var timer_label: Label
var keys_label: Label
var danger_overlay: ColorRect
var win_overlay: Control

func _ready() -> void:
	_build_grid()
	_setup_key_sprites()
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

	win_overlay = Control.new()
	win_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	win_overlay.visible = false
	win_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var win_bg := ColorRect.new()
	win_bg.color = Color(0, 0, 0, 0.92)
	win_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	win_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	win_overlay.add_child(win_bg)

	var win_label := Label.new()
	win_label.text = "YOU WIN!\n\n(R pra reiniciar)"
	win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	win_label.add_theme_font_size_override("font_size", 72)
	win_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	win_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	win_overlay.add_child(win_label)

	ui_layer.add_child(win_overlay)

func _center_grid() -> void:
	var viewport_size := get_viewport_rect().size
	var grid_px := Vector2(GRID_WIDTH, GRID_HEIGHT) * CELL_PX
	base_position = ((viewport_size - grid_px) * 0.5).floor()
	position = base_position

func _reset_run() -> void:
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
	position = base_position
	danger_overlay.color.a = 0.0
	win_overlay.visible = false
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
	if time_remaining < 5.0:
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

	if not first_click_done:
		_place_bombs(Vector2i(x, y))
		_place_keys(Vector2i(x, y))
		first_click_done = true
		timer_running = true

	if t.is_bomb:
		_lose(t)
		return

	_flood_reveal(x, y)
	_check_keys_found()

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
		t.reveal()
		if t.adjacent_bombs == 0:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var nx: int = p.x + dx
					var ny: int = p.y + dy
					if nx < 0 or nx >= GRID_WIDTH or ny < 0 or ny >= GRID_HEIGHT:
						continue
					queue.push_back(Vector2i(nx, ny))

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
		key_sprites[i].visible = true
		any_found = true
		print("Chave %d/%d encontrada!" % [keys_found_count, KEYS_TO_WIN])

	if any_found:
		time_remaining = TIME_LIMIT
		if keys_found_count >= KEYS_TO_WIN:
			_win_run()

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
	for i in key_positions.size():
		if not keys_found_flags[i]:
			key_sprites[i].visible = true

func _win_run() -> void:
	won_run = true
	timer_running = false
	position = base_position
	danger_overlay.color.a = 0.0
	win_overlay.visible = true
	print("YOU WIN! Score final: %d" % score)
