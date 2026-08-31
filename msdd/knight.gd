extends CharacterBody2D

signal reached_target(tile_pos: Vector2i)

const WALK_SPEED := 120.0

var tile_pos: Vector2i = Vector2i.ZERO
var walking: bool = false
var _path: Array[Vector2i] = []
var _current_target: Vector2 = Vector2.ZERO
var _cell_px: int = 32

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

func setup(cell_px: int) -> void:
	_cell_px = cell_px
	_sprite.play("idle")

func set_tile(pos: Vector2i) -> void:
	tile_pos = pos
	position = _tile_to_world(pos)

func walk_along_path(path: Array[Vector2i]) -> void:
	if path.is_empty():
		return
	_path = path.duplicate()
	if not _path.is_empty() and _path[0] == tile_pos:
		_path.pop_front()
	if _path.is_empty():
		return
	walking = true
	_sprite.play("walk")
	_pick_next()

func _pick_next() -> void:
	if _path.is_empty():
		walking = false
		_sprite.play("idle")
		reached_target.emit(tile_pos)
		return
	var next: Vector2i = _path.pop_front()
	var dx := next.x - tile_pos.x
	if dx > 0:
		_sprite.flip_h = false
	elif dx < 0:
		_sprite.flip_h = true
	tile_pos = next
	_current_target = _tile_to_world(next)

func _tile_to_world(pos: Vector2i) -> Vector2:
	return Vector2(pos) * _cell_px + Vector2.ONE * _cell_px * 0.5

func _physics_process(delta: float) -> void:
	if not walking:
		return
	var to_target := _current_target - position
	var step := WALK_SPEED * delta
	if to_target.length() <= step:
		position = _current_target
		_pick_next()
	else:
		position += to_target.normalized() * step
