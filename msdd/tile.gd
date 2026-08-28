class_name Tile
extends Sprite2D

enum State { HIDDEN, REVEALED, FLAGGED, QUESTIONED }

const TEX_HIDDEN := preload("res://minesweeper_tiles/masked_tile.png")
const TEX_REVEALED := preload("res://minesweeper_tiles/revealed_tile.png")
const TEX_FLAG := preload("res://minesweeper_tiles/masked_tile_flag.png")
const TEX_QUESTION := preload("res://minesweeper_tiles/masked_tile_question_mark.png")

var state: State = State.HIDDEN
var grid_pos: Vector2i

func _ready() -> void:
	centered = false
	texture = TEX_HIDDEN

func reveal() -> void:
	if state == State.REVEALED or state == State.FLAGGED:
		return
	state = State.REVEALED
	texture = TEX_REVEALED

func toggle_flag() -> void:
	match state:
		State.HIDDEN:
			state = State.FLAGGED
			texture = TEX_FLAG
		State.FLAGGED:
			state = State.QUESTIONED
			texture = TEX_QUESTION
		State.QUESTIONED:
			state = State.HIDDEN
			texture = TEX_HIDDEN
