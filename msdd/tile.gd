class_name Tile
extends Sprite2D

enum State { HIDDEN, REVEALED, FLAGGED, QUESTIONED }

const TEX_HIDDEN := preload("res://minesweeper_tiles/masked_tile.png")
const TEX_REVEALED_EMPTY := preload("res://minesweeper_tiles/revealed_tile.png")
const TEX_FLAG := preload("res://minesweeper_tiles/masked_tile_flag.png")
const TEX_QUESTION := preload("res://minesweeper_tiles/masked_tile_question_mark.png")
const TEX_BOMB := preload("res://minesweeper_tiles/revealed_tile_bomb.png")
const TEX_EXPLODED := preload("res://minesweeper_tiles/tile_exploded.png")
const TEX_WRONG_FLAG := preload("res://minesweeper_tiles/tile_not_mine.png")
const TEX_NUMBERS := [
	null,
	preload("res://minesweeper_tiles/revealed_tile_1.png"),
	preload("res://minesweeper_tiles/revealed_tile_2.png"),
	preload("res://minesweeper_tiles/revealed_tile_3.png"),
	preload("res://minesweeper_tiles/revealed_tile_4.png"),
	preload("res://minesweeper_tiles/revealed_tile_5.png"),
	preload("res://minesweeper_tiles/revealed_tile_6.png"),
	preload("res://minesweeper_tiles/revealed_tile_7.png"),
	preload("res://minesweeper_tiles/revealed_tile_8.png"),
]

const GOLD_TINT := Color(1.3, 1.1, 0.6)

var state: State = State.HIDDEN
var grid_pos: Vector2i
var is_bomb: bool = false
var adjacent_bombs: int = 0
var has_key: bool = false
var is_gold_adjacent: bool = false

func _ready() -> void:
	centered = false
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
	is_gold_adjacent = false
	modulate = Color.WHITE
	_update_visual()

func _update_visual() -> void:
	modulate = Color.WHITE
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
			if is_gold_adjacent and not is_bomb:
				modulate = GOLD_TINT
