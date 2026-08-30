class_name Tile
extends Sprite2D

enum State { HIDDEN, REVEALED, FLAGGED, QUESTIONED }

const TEX_HIDDEN := preload("res://assets/minesweeper_tiles/masked_tile.png")
const TEX_REVEALED_EMPTY := preload("res://assets/minesweeper_tiles/revealed_tile.png")
const TEX_FLAG := preload("res://assets/minesweeper_tiles/masked_tile_flag.png")
const TEX_QUESTION := preload("res://assets/minesweeper_tiles/masked_tile_question_mark.png")
const TEX_BOMB := preload("res://assets/minesweeper_tiles/revealed_tile_bomb.png")
const TEX_EXPLODED := preload("res://assets/minesweeper_tiles/tile_exploded.png")
const TEX_WRONG_FLAG := preload("res://assets/minesweeper_tiles/tile_not_mine.png")
const TEX_NUMBERS := [
	null,
	preload("res://assets/minesweeper_tiles/revealed_tile_1.png"),
	preload("res://assets/minesweeper_tiles/revealed_tile_2.png"),
	preload("res://assets/minesweeper_tiles/revealed_tile_3.png"),
	preload("res://assets/minesweeper_tiles/revealed_tile_4.png"),
	preload("res://assets/minesweeper_tiles/revealed_tile_5.png"),
	preload("res://assets/minesweeper_tiles/revealed_tile_6.png"),
	preload("res://assets/minesweeper_tiles/revealed_tile_7.png"),
	preload("res://assets/minesweeper_tiles/revealed_tile_8.png"),
]

const HINT_SHADER := preload("res://tile_hint.gdshader")

var state: State = State.HIDDEN
var grid_pos: Vector2i
var is_bomb: bool = false
var adjacent_bombs: int = 0
var has_key: bool = false
var hint_rect: Rect2 = Rect2()
var hint_color: Color = Color.WHITE

func _ready() -> void:
	centered = false
	var mat := ShaderMaterial.new()
	mat.shader = HINT_SHADER
	material = mat
	_update_visual()

func reveal() -> bool:
	if state == State.FLAGGED or state == State.REVEALED:
		return false
	state = State.REVEALED
	_update_visual()
	return true

func cycle_mark() -> void:
	if state == State.REVEALED:
		return
	match state:
		State.HIDDEN:
			state = State.FLAGGED
		State.FLAGGED:
			state = State.QUESTIONED
		State.QUESTIONED:
			state = State.HIDDEN
	_update_visual()

func flag() -> void:
	if state == State.REVEALED:
		return
	state = State.FLAGGED
	_update_visual()

func show_as_bomb() -> void:
	state = State.REVEALED
	modulate = Color.WHITE
	texture = TEX_BOMB

func show_as_exploded() -> void:
	state = State.REVEALED
	modulate = Color.WHITE
	texture = TEX_EXPLODED

func show_as_wrong_flag() -> void:
	state = State.REVEALED
	modulate = Color.WHITE
	texture = TEX_WRONG_FLAG

func reset() -> void:
	state = State.HIDDEN
	is_bomb = false
	adjacent_bombs = 0
	has_key = false
	hint_rect = Rect2()
	hint_color = Color.WHITE
	modulate = Color.WHITE
	_update_visual()

func _update_visual() -> void:
	modulate = Color.WHITE
	var effective_rect := Vector4.ZERO
	var effective_tint := Vector4(1.0, 1.0, 1.0, 1.0)
	match state:
		State.HIDDEN:
			texture = TEX_HIDDEN
		State.FLAGGED:
			texture = TEX_FLAG
		State.QUESTIONED:
			texture = TEX_QUESTION
		State.REVEALED:
			if is_bomb:
				texture = TEX_BOMB
			elif has_key or adjacent_bombs == 0:
				texture = TEX_REVEALED_EMPTY
			else:
				texture = TEX_NUMBERS[adjacent_bombs]
			if not is_bomb and hint_rect.size.x > 0.0 and hint_rect.size.y > 0.0:
				effective_rect = Vector4(hint_rect.position.x, hint_rect.position.y, hint_rect.size.x, hint_rect.size.y)
				effective_tint = Vector4(hint_color.r, hint_color.g, hint_color.b, hint_color.a)
	var mat: ShaderMaterial = material as ShaderMaterial
	mat.set_shader_parameter("hint_rect", effective_rect)
	mat.set_shader_parameter("hint_tint", effective_tint)
