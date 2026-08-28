extends Node2D

const GRID_SIZE := 10
const TILE_SIZE := 16
const SCALE_FACTOR := 3
const CELL_PX := TILE_SIZE * SCALE_FACTOR
const BOMB_COUNT := 15

const KEY_SHEET := preload("res://minesweeper_tiles/KeyFly-Sheet.png")
const KEY_FRAME_SIZE := 64
const KEY_FRAME_COUNT := 4
const KEY_ANIMATION_FPS := 6.0
const KEY_POINTS := 100

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

func _ready() -> void:
	_build_grid()
	_setup_key_sprite()
	_center_grid()
	get_viewport().size_changed.connect(_center_grid)
	_reset_game()

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

func _center_grid() -> void:
	var viewport_size := get_viewport_rect().size
	var grid_px := GRID_SIZE * CELL_PX
	position = ((viewport_size - Vector2(grid_px, grid_px)) * 0.5).floor()

func _reset_game() -> void:
	first_click_done = false
	game_over = false
	non_bomb_revealed = 0
	non_bomb_total = GRID_SIZE * GRID_SIZE - BOMB_COUNT
	key_placed = false
	key_found = false
	key_sprite.visible = false
	key_sprite.stop()
	for row in tiles:
		for t in row:
			t.reset()
	print("Nova partida — %d bombas. R pra reiniciar. Score total: %d" % [BOMB_COUNT, score])

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

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_reset_game()
		return

	if game_over:
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

	if t.is_bomb:
		_lose(t)
		return

	_flood_reveal(x, y)
	_check_key_found()
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
	if t.state == Tile.State.REVEALED:
		key_found = true
		score += KEY_POINTS
		key_sprite.visible = true
		key_sprite.play()
		print("Chave encontrada! +%d pts (total: %d)" % [KEY_POINTS, score])

func _lose(exploded_tile: Tile) -> void:
	game_over = true
	exploded_tile.show_as_exploded()
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
	print("Boom! R pra reiniciar. Score total: %d" % score)

func _check_win() -> void:
	if non_bomb_revealed >= non_bomb_total:
		game_over = true
		for row in tiles:
			for t in row:
				if t.is_bomb and t.state != Tile.State.FLAGGED:
					t.flag()
		print("Vitória! R pra reiniciar. Score total: %d" % score)
