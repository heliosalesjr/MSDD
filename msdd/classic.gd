extends Node2D

const GRID_WIDTH := 24
const GRID_HEIGHT := 14
const TILE_SIZE := 16
const SCALE_FACTOR := 2
const CELL_PX := TILE_SIZE * SCALE_FACTOR
const TRAP_COUNT := 50

const MAX_HP := 5
const TRAP_DIFFICULTY := 7
const DAMAGE_MIN := 1
const DAMAGE_MAX := 3
const DISARM_BONUS := 5

# O ritmo da cascata (passo por anel, jitter) vive em tile.gd.

var tiles: Array = []
var first_click_done: bool = false
var game_over: bool = false
var won: bool = false

var hp: int = MAX_HP
var gold: int = 0

# Quando a última cascata agendada termina de abrir (ms do relógio do engine).
var cascade_end_msec: int = 0
# Incrementa a cada expedição, pra descartar timers de uma run já encerrada.
var run_id: int = 0

var base_position: Vector2 = Vector2.ZERO

var ui_layer: CanvasLayer
var status_label: Label
var log_label: Label
var end_overlay: Control
var end_message_label: Label
var end_subtitle_label: Label

func _ready() -> void:
	_build_grid()
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

func _center_grid() -> void:
	var viewport_size := get_viewport_rect().size
	var grid_px := Vector2(GRID_WIDTH, GRID_HEIGHT) * CELL_PX
	base_position = ((viewport_size - grid_px) * 0.5).floor()
	position = base_position

func _setup_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	status_label = Label.new()
	status_label.position = Vector2(20, 20)
	status_label.add_theme_font_size_override("font_size", 22)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(status_label)

	log_label = Label.new()
	log_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	log_label.offset_top = -60
	log_label.offset_bottom = -20
	log_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	log_label.add_theme_font_size_override("font_size", 18)
	log_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.72))
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
	hp = MAX_HP
	gold = 0
	position = base_position
	end_overlay.visible = false
	for row in tiles:
		for t in row:
			t.reset()
	log_label.text = "Você entra na cripta."
	_update_status()
	print("Nova expedição — %d armadilhas, HP %d." % [TRAP_COUNT, MAX_HP])

func _update_status() -> void:
	status_label.text = "HP: %d/%d    Ouro: %d    Armadilhas: %d" % [hp, MAX_HP, gold, TRAP_COUNT]

func _place_traps(safe_center: Vector2i) -> void:
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
	var count: int = mini(TRAP_COUNT, candidates.size())
	for i in count:
		var p: Vector2i = candidates[i]
		tiles[p.y][p.x].is_bomb = true

	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			if not tiles[y][x].is_bomb:
				tiles[y][x].adjacent_bombs = _count_adjacent_traps(x, y)

func _count_adjacent_traps(cx: int, cy: int) -> int:
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

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_reset_run()
		return

	if game_over or won:
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
		_place_traps(Vector2i(x, y))
		first_click_done = true

	if t.is_bomb:
		_resolve_trap(t)
		return

	_flood_reveal(x, y)
	_update_status()
	_check_win()

func _handle_right(x: int, y: int) -> void:
	tiles[y][x].cycle_mark()

func _resolve_trap(t: Tile) -> void:
	var d1: int = randi_range(1, 6)
	var d2: int = randi_range(1, 6)
	var roll: int = d1 + d2

	if roll >= TRAP_DIFFICULTY:
		# Disarmed: clear trap, recompute adjacencies, flood-reveal, bonus gold.
		var pos := t.grid_pos
		t.is_bomb = false
		t.adjacent_bombs = _count_adjacent_traps(pos.x, pos.y)
		_recompute_neighbors_of(pos)
		_flood_reveal(pos.x, pos.y)
		gold += DISARM_BONUS
		log_label.text = "Você desarmou a armadilha (rolou %d vs %d). +%d ouro." % [roll, TRAP_DIFFICULTY, DISARM_BONUS + 1]
		_update_status()
		_check_win()
	else:
		# Failed: trap fires, damage capped 1-3, tile shows exploded texture.
		var damage: int = clampi(TRAP_DIFFICULTY - roll, DAMAGE_MIN, DAMAGE_MAX)
		hp -= damage
		t.show_as_exploded()
		log_label.text = "A armadilha disparou (rolou %d vs %d). -%d HP." % [roll, TRAP_DIFFICULTY, damage]
		_update_status()
		if hp <= 0:
			hp = 0
			_update_status()
			_retreat(t.grid_pos)

func _recompute_neighbors_of(pos: Vector2i) -> void:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx: int = pos.x + dx
			var ny: int = pos.y + dy
			if nx < 0 or nx >= GRID_WIDTH or ny < 0 or ny >= GRID_HEIGHT:
				continue
			var nt: Tile = tiles[ny][nx]
			if nt.is_bomb:
				continue
			nt.adjacent_bombs = _count_adjacent_traps(nx, ny)
			if nt.state == Tile.State.REVEALED:
				nt._update_visual()

# O estado lógico (ouro, REVEALED) muda na hora; só a abertura visual é
# escalonada, pra que win check e cliques nunca fiquem fora de sincronia.
func _flood_reveal(sx: int, sy: int) -> void:
	# Cada entrada é [posição, anel]. BFS garante que o primeiro visitante
	# de um tile chega pelo caminho mais curto, ou seja, pelo menor anel.
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
		if t.reveal(delay):
			gold += 1
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
	# Um reset durante a espera invalida este fim de expedição.
	if run_id != expected_run:
		return
	_show_end(main_text, subtitle_text)

func _check_win() -> void:
	for row in tiles:
		for t in row:
			if not t.is_bomb and t.state != Tile.State.REVEALED:
				return
	won = true
	for row in tiles:
		for t in row:
			if t.is_bomb and t.state != Tile.State.FLAGGED:
				t.flag()
	_show_end_after_cascade("AVENTURA COMPLETA", "Você mapeou toda a cripta.\nOuro: %d    HP restante: %d/%d" % [gold, hp, MAX_HP])
	print("Aventura completa! Ouro: %d, HP: %d" % [gold, hp])

# A revelação final irradia da armadilha que derrubou o último HP, em anéis
# de Chebyshev — aqui não há caminho aberto pra seguir, a onda é geométrica.
func _retreat(epicenter: Vector2i) -> void:
	game_over = true
	var max_delay := 0.0
	for row in tiles:
		for t in row:
			var ring: int = maxi(
				absi(t.grid_pos.x - epicenter.x),
				absi(t.grid_pos.y - epicenter.y)
			)
			var delay: float = Tile.defeat_delay(ring)
			if t.is_bomb and t.state != Tile.State.FLAGGED and t.state != Tile.State.REVEALED:
				t.show_as_bomb(delay)
				max_delay = maxf(max_delay, delay)
			elif not t.is_bomb and t.state == Tile.State.FLAGGED:
				t.show_as_wrong_flag(delay)
				max_delay = maxf(max_delay, delay)
	_note_cascade(max_delay)
	_show_end_after_cascade("VOCÊ RECUA", "HP esgotado. Ouro coletado: %d" % gold)
	print("Recuada. Ouro: %d" % gold)

func _show_end(main_text: String, subtitle_text: String) -> void:
	end_message_label.text = main_text
	end_subtitle_label.text = subtitle_text
	end_overlay.visible = true

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://menu.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
