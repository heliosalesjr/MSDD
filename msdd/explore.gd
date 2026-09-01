extends Node2D

const CHUNK_W := 24
const CHUNK_H := 14
const TILE_SIZE := 16
const SCALE_FACTOR := 2
const CELL_PX := TILE_SIZE * SCALE_FACTOR
const CHUNK_BOMBS := 35
const KNIGHT_SCALE := 2

const PORTAL_COLOR := Color(0.3, 0.7, 1.4)

const AXIS_VERTICAL := 0    # portais N/S
const AXIS_HORIZONTAL := 1  # portais E/W

const NO_CHUNK := Vector2i(2147483647, 2147483647)

const KnightScene := preload("res://knight.tscn")

var world_tiles: Dictionary = {}         # Vector2i (world tile) -> Tile
var chunks_spawned: Dictionary = {}      # Vector2i (chunk coord) -> true
var chunk_orientation: Dictionary = {}   # Vector2i (chunk coord) -> AXIS_*
var chunk_entry: Dictionary = {}         # Vector2i (chunk coord) -> Vector2i (world tile)
var portals_by_pos: Dictionary = {}      # Vector2i (world tile) -> true

var knight: CharacterBody2D
var camera: Camera2D
var current_chunk: Vector2i = Vector2i.ZERO
var game_over: bool = false
var chunks_first_clicked: Dictionary = {}   # Vector2i (chunk coord) -> true

var world_root: Node2D
var background: ColorRect

var ui_layer: CanvasLayer
var end_overlay: Control
var end_message_label: Label
var end_subtitle_label: Label
var status_label: Label

func _ready() -> void:
	_setup_background()
	_setup_world_root()
	_setup_ui()
	_spawn_chunk(Vector2i.ZERO)
	_spawn_knight()

func _setup_background() -> void:
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -1
	add_child(bg_layer)
	background = ColorRect.new()
	background.color = Color(0.04, 0.04, 0.07)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_layer.add_child(background)

func _setup_world_root() -> void:
	world_root = Node2D.new()
	world_root.name = "World"
	add_child(world_root)

func _setup_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	status_label = Label.new()
	status_label.position = Vector2(20, 20)
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label.text = "Chunks: 1"
	ui_layer.add_child(status_label)

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

func _spawn_knight() -> void:
	knight = KnightScene.instantiate()
	knight.scale = Vector2.ONE * KNIGHT_SCALE
	knight.z_index = 10
	world_root.add_child(knight)
	knight.setup(CELL_PX)
	var center := Vector2i(CHUNK_W / 2, CHUNK_H / 2)
	knight.set_tile(center)
	knight.reached_target.connect(_on_knight_reached)

	var t: Tile = world_tiles[center]
	if not t.is_bomb and t.state != Tile.State.REVEALED:
		t.reveal()

	# Camera is independent of the knight — it centers on the current chunk.
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	camera.position = _chunk_center_world(Vector2i.ZERO)
	camera.make_current()
	add_child(camera)

func _chunk_center_world(chunk_coord: Vector2i) -> Vector2:
	var origin: Vector2i = chunk_coord * Vector2i(CHUNK_W, CHUNK_H)
	var center_tile: Vector2i = origin + Vector2i(CHUNK_W / 2, CHUNK_H / 2)
	return Vector2(center_tile) * CELL_PX + Vector2.ONE * CELL_PX * 0.5

func _spawn_chunk(chunk_coord: Vector2i, entry_from: Vector2i = NO_CHUNK) -> void:
	if chunks_spawned.has(chunk_coord):
		return
	chunks_spawned[chunk_coord] = true

	var origin: Vector2i = chunk_coord * Vector2i(CHUNK_W, CHUNK_H)

	var axis: int = AXIS_VERTICAL if (randi() % 2) == 0 else AXIS_HORIZONTAL
	chunk_orientation[chunk_coord] = axis

	var portal_locals: Array[Vector2i] = []
	if axis == AXIS_VERTICAL:
		portal_locals = [
			Vector2i(CHUNK_W / 2, 0),
			Vector2i(CHUNK_W / 2, CHUNK_H - 1),
		]
	else:
		portal_locals = [
			Vector2i(0, CHUNK_H / 2),
			Vector2i(CHUNK_W - 1, CHUNK_H / 2),
		]

	var portal_worlds: Array[Vector2i] = []
	for pl in portal_locals:
		portal_worlds.append(origin + pl)

	# Entry tile — where player lands when arriving in this chunk
	var entry_world: Vector2i
	if entry_from == NO_CHUNK:
		entry_world = origin + Vector2i(CHUNK_W / 2, CHUNK_H / 2)
	else:
		var from_chunk_coord: Vector2i = _world_to_chunk(entry_from)
		var direction: Vector2i = chunk_coord - from_chunk_coord
		entry_world = entry_from + direction
	chunk_entry[chunk_coord] = entry_world

	# Safe zone: 3x3 around each portal + 3x3 around entry
	var safe_set := {}
	for pw in portal_worlds:
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				safe_set[pw + Vector2i(dx, dy)] = true
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			safe_set[entry_world + Vector2i(dx, dy)] = true

	# Create tiles
	for local_y in CHUNK_H:
		for local_x in CHUNK_W:
			var wp: Vector2i = origin + Vector2i(local_x, local_y)
			var t := Tile.new()
			t.grid_pos = wp
			t.position = Vector2(wp) * CELL_PX
			t.scale = Vector2.ONE * SCALE_FACTOR
			world_root.add_child(t)
			world_tiles[wp] = t

	# Place bombs (candidates = non-safe tiles in this chunk)
	var candidates: Array[Vector2i] = []
	for local_y in CHUNK_H:
		for local_x in CHUNK_W:
			var wp: Vector2i = origin + Vector2i(local_x, local_y)
			if not safe_set.has(wp):
				candidates.append(wp)
	candidates.shuffle()
	var count: int = mini(CHUNK_BOMBS, candidates.size())
	for i in count:
		world_tiles[candidates[i]].is_bomb = true

	# Portals: pre-revealed, blue tint via hint shader
	for pw in portal_worlds:
		portals_by_pos[pw] = true
		var t: Tile = world_tiles[pw]
		t.is_bomb = false
		t.hint_rect = Rect2(0.0, 0.0, 1.0, 1.0)
		t.hint_color = PORTAL_COLOR
		t.reveal()

	# Entry tile: always safe + revealed (may or may not be a portal)
	var entry_tile: Tile = world_tiles[entry_world]
	entry_tile.is_bomb = false
	if entry_tile.state != Tile.State.REVEALED:
		entry_tile.reveal()

	_recompute_adjacencies_around(chunk_coord)

	if status_label:
		status_label.text = "Chunks: %d" % chunks_spawned.size()

func _recompute_adjacencies_around(chunk_coord: Vector2i) -> void:
	for cx in [-1, 0, 1]:
		for cy in [-1, 0, 1]:
			var cc: Vector2i = chunk_coord + Vector2i(cx, cy)
			if not chunks_spawned.has(cc):
				continue
			var origin: Vector2i = cc * Vector2i(CHUNK_W, CHUNK_H)
			for local_y in CHUNK_H:
				for local_x in CHUNK_W:
					var wp: Vector2i = origin + Vector2i(local_x, local_y)
					if not world_tiles.has(wp):
						continue
					var t: Tile = world_tiles[wp]
					if t.is_bomb:
						continue
					var new_count: int = _count_bombs_around(wp)
					if new_count != t.adjacent_bombs:
						t.adjacent_bombs = new_count
						if t.state == Tile.State.REVEALED:
							t._update_visual()

func _count_bombs_around(wp: Vector2i) -> int:
	var n := 0
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var np: Vector2i = wp + Vector2i(dx, dy)
			if world_tiles.has(np) and world_tiles[np].is_bomb:
				n += 1
	return n

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()
		return

	if game_over:
		return
	if knight and knight.walking:
		return
	if not (event is InputEventMouseButton) or not event.pressed:
		return

	var world_pos: Vector2 = get_global_mouse_position()
	var tp := Vector2i(floori(world_pos.x / CELL_PX), floori(world_pos.y / CELL_PX))
	if not world_tiles.has(tp):
		return

	match event.button_index:
		MOUSE_BUTTON_LEFT:
			_handle_left(tp)
		MOUSE_BUTTON_RIGHT:
			world_tiles[tp].cycle_mark()

func _handle_left(tp: Vector2i) -> void:
	var t: Tile = world_tiles[tp]
	if t.state == Tile.State.FLAGGED or t.state == Tile.State.REVEALED:
		return
	var chunk_of_click: Vector2i = _world_to_chunk(tp)
	if not chunks_first_clicked.has(chunk_of_click):
		chunks_first_clicked[chunk_of_click] = true
		_ensure_safe_first_click(tp)
	if t.is_bomb:
		_lose(t)
		return
	_flood_reveal(tp)
	_check_and_walk()

func _ensure_safe_first_click(tp: Vector2i) -> void:
	# Move any bombs at tp + 8 neighbors to safe destinations elsewhere.
	var to_move: Array[Vector2i] = []
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var np: Vector2i = tp + Vector2i(dx, dy)
			if world_tiles.has(np) and world_tiles[np].is_bomb:
				to_move.append(np)
	if to_move.is_empty():
		return

	# Candidate destinations: non-bomb, not adjacent to tp, not a portal
	var destinations: Array[Vector2i] = []
	for wp in world_tiles.keys():
		var wt: Tile = world_tiles[wp]
		if wt.is_bomb:
			continue
		if portals_by_pos.has(wp):
			continue
		var d: Vector2i = wp - tp
		if maxi(absi(d.x), absi(d.y)) <= 1:
			continue
		destinations.append(wp)
	destinations.shuffle()

	var moved := 0
	for src in to_move:
		if moved >= destinations.size():
			break
		world_tiles[src].is_bomb = false
		world_tiles[destinations[moved]].is_bomb = true
		moved += 1

	# Recompute adjacencies for all tiles (bombs moved, counts may shift anywhere)
	for wp in world_tiles.keys():
		var wt: Tile = world_tiles[wp]
		if wt.is_bomb:
			continue
		var new_count: int = _count_bombs_around(wp)
		if new_count != wt.adjacent_bombs:
			wt.adjacent_bombs = new_count
			if wt.state == Tile.State.REVEALED:
				wt._update_visual()

func _flood_reveal(start: Vector2i) -> void:
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		if not world_tiles.has(p):
			continue
		var t: Tile = world_tiles[p]
		if t.state == Tile.State.REVEALED or t.state == Tile.State.FLAGGED:
			continue
		if t.is_bomb:
			continue
		t.reveal()
		if t.adjacent_bombs == 0:
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					if dx == 0 and dy == 0:
						continue
					queue.push_back(p + Vector2i(dx, dy))

func _check_and_walk() -> void:
	if knight == null or knight.walking:
		return
	var path: Array[Vector2i] = _find_path_to_portal(knight.tile_pos)
	if path.is_empty():
		return
	knight.walk_along_path(path)

func _find_path_to_portal(start: Vector2i) -> Array[Vector2i]:
	var visited := {start: null}
	var queue: Array[Vector2i] = [start]
	var found: Variant = null
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		if p != start and portals_by_pos.has(p):
			# Skip portals adjacent to start (avoids trivial 1-step walks
			# to the entry portal of the just-entered chunk).
			var dist: int = maxi(absi(p.x - start.x), absi(p.y - start.y))
			# Only accept portals that belong to the current chunk (where the
			# camera is). This prevents the player from walking to a still-open
			# portal in a previously-explored chunk when both portals of the
			# origin chunk were exposed at the same time.
			var portal_chunk: Vector2i = _world_to_chunk(p)
			if dist > 1 and _portal_leads_to_new_chunk(p) and portal_chunk == current_chunk:
				found = p
				break
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var np: Vector2i = p + dir
			if visited.has(np):
				continue
			if not world_tiles.has(np):
				continue
			var t: Tile = world_tiles[np]
			if t.state != Tile.State.REVEALED:
				continue
			if t.is_bomb:
				continue
			visited[np] = p
			queue.append(np)
	if found == null:
		return []
	var path: Array[Vector2i] = []
	var cur: Variant = found
	while cur != null:
		path.push_front(cur)
		cur = visited[cur]
	return path

func _on_knight_reached(tile_pos: Vector2i) -> void:
	if game_over:
		return
	if not portals_by_pos.has(tile_pos):
		return
	var new_chunk: Vector2i = _try_spawn_adjacent_chunk(tile_pos)
	if new_chunk == NO_CHUNK:
		return
	# Camera slides to center of the new chunk; player stays put until a new portal is opened.
	current_chunk = new_chunk
	camera.position = _chunk_center_world(new_chunk)

func _try_spawn_adjacent_chunk(portal_world_pos: Vector2i) -> Vector2i:
	var adjacent: Vector2i = _adjacent_chunk_of_portal(portal_world_pos)
	if adjacent == NO_CHUNK:
		return NO_CHUNK
	if chunks_spawned.has(adjacent):
		return NO_CHUNK
	_spawn_chunk(adjacent, portal_world_pos)
	return adjacent

func _adjacent_chunk_of_portal(portal_world_pos: Vector2i) -> Vector2i:
	var chunk_coord: Vector2i = _world_to_chunk(portal_world_pos)
	var origin: Vector2i = chunk_coord * Vector2i(CHUNK_W, CHUNK_H)
	var local: Vector2i = portal_world_pos - origin
	if local.y == 0:
		return chunk_coord + Vector2i(0, -1)
	elif local.y == CHUNK_H - 1:
		return chunk_coord + Vector2i(0, 1)
	elif local.x == 0:
		return chunk_coord + Vector2i(-1, 0)
	elif local.x == CHUNK_W - 1:
		return chunk_coord + Vector2i(1, 0)
	return NO_CHUNK

func _portal_leads_to_new_chunk(portal_world_pos: Vector2i) -> bool:
	var adjacent: Vector2i = _adjacent_chunk_of_portal(portal_world_pos)
	if adjacent == NO_CHUNK:
		return false
	return not chunks_spawned.has(adjacent)

func _world_to_chunk(wp: Vector2i) -> Vector2i:
	return Vector2i(floori(float(wp.x) / CHUNK_W), floori(float(wp.y) / CHUNK_H))

func _lose(exploded_tile: Tile) -> void:
	game_over = true
	exploded_tile.show_as_exploded()
	for wp in world_tiles.keys():
		var t: Tile = world_tiles[wp]
		if t == exploded_tile:
			continue
		if t.is_bomb and t.state != Tile.State.FLAGGED:
			t.show_as_bomb()
		elif not t.is_bomb and t.state == Tile.State.FLAGGED:
			t.show_as_wrong_flag()
	_show_end("GAME OVER", "Boom! Chunks explorados: %d" % chunks_spawned.size())
	print("Boom! Chunks: %d" % chunks_spawned.size())

func _show_end(main_text: String, subtitle_text: String) -> void:
	end_message_label.text = main_text
	end_subtitle_label.text = subtitle_text
	end_overlay.visible = true

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://menu.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
