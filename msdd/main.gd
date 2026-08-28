extends Node2D

const GRID_SIZE := 10
const TILE_SIZE := 16
const SCALE_FACTOR := 3
const CELL_PX := TILE_SIZE * SCALE_FACTOR

var tiles: Array = []

func _ready() -> void:
	_build_grid()
	_center_grid()
	get_viewport().size_changed.connect(_center_grid)

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

func _center_grid() -> void:
	var viewport_size := get_viewport_rect().size
	var grid_px := GRID_SIZE * CELL_PX
	position = ((viewport_size - Vector2(grid_px, grid_px)) * 0.5).floor()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	var local := to_local(event.position)
	var gx := int(local.x / CELL_PX)
	var gy := int(local.y / CELL_PX)
	if gx < 0 or gx >= GRID_SIZE or gy < 0 or gy >= GRID_SIZE:
		return
	var tile: Tile = tiles[gy][gx]
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			tile.reveal()
		MOUSE_BUTTON_RIGHT:
			tile.toggle_flag()
