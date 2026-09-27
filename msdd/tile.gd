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

# --- Animação de abertura ---
# Duração total do "pop" de um tile. O chamador usa isto para saber
# quanto tempo uma cascata inteira leva pra terminar.
const OPEN_DURATION := 0.16
# Escala inicial do tile revelado (o tile encolhe um tico e cresce de volta,
# dando a impressão de que a tampa abriu e a casa surgiu por baixo).
const OPEN_SCALE_FROM := 0.82
# Overshoot antes de assentar em 1.0.
const OPEN_SCALE_PUNCH := 1.06
# Clarão no instante da abertura.
const OPEN_FLASH := Color(1.55, 1.45, 1.25)

var state: State = State.HIDDEN
var grid_pos: Vector2i
var is_bomb: bool = false
var adjacent_bombs: int = 0
var has_key: bool = false
var hint_rect: Rect2 = Rect2()
var hint_color: Color = Color.WHITE

# Verdadeiro entre o reveal() lógico e o instante em que a abertura visual
# começa: o estado já é REVEALED, mas o sprite continua mostrando a tampa.
var reveal_pending: bool = false

var _open_tween: Tween
var _flash_tween: Tween
var _rest_captured: bool = false
var _rest_scale: Vector2 = Vector2.ONE
var _rest_position: Vector2 = Vector2.ZERO
var _rest_size: Vector2 = Vector2.ONE * 16.0
var _rest_z: int = 0

func _ready() -> void:
	centered = false
	var mat := ShaderMaterial.new()
	mat.shader = HINT_SHADER
	material = mat
	_update_visual()

# delay < 0 revela na hora, sem animação (comportamento dos outros protótipos).
# delay >= 0 agenda a abertura visual para daqui a `delay` segundos; o estado
# lógico muda imediatamente de qualquer forma.
func reveal(delay: float = -1.0) -> bool:
	if state == State.FLAGGED or state == State.REVEALED:
		return false
	state = State.REVEALED
	if delay < 0.0:
		_update_visual()
	else:
		reveal_pending = true
		_update_visual()
		_play_open(delay)
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
	_cancel_open()
	state = State.REVEALED
	modulate = Color.WHITE
	texture = TEX_BOMB

func show_as_exploded() -> void:
	_cancel_open()
	state = State.REVEALED
	modulate = Color.WHITE
	texture = TEX_EXPLODED

func show_as_wrong_flag() -> void:
	_cancel_open()
	state = State.REVEALED
	modulate = Color.WHITE
	texture = TEX_WRONG_FLAG

func reset() -> void:
	_cancel_open()
	state = State.HIDDEN
	is_bomb = false
	adjacent_bombs = 0
	has_key = false
	hint_rect = Rect2()
	hint_color = Color.WHITE
	modulate = Color.WHITE
	_update_visual()

func _play_open(delay: float) -> void:
	_capture_rest()
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	_set_open_progress(1.0)
	_open_tween = create_tween()
	if delay > 0.0:
		_open_tween.tween_interval(delay)
	_open_tween.tween_callback(_on_open_start)
	_open_tween.tween_method(
		_set_open_progress, OPEN_SCALE_FROM, OPEN_SCALE_PUNCH, OPEN_DURATION * 0.55
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_open_tween.tween_method(
		_set_open_progress, OPEN_SCALE_PUNCH, 1.0, OPEN_DURATION * 0.45
	).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_open_tween.tween_callback(_on_open_finished)

func _on_open_start() -> void:
	reveal_pending = false
	_update_visual()
	z_index = _rest_z + 1
	_set_open_progress(OPEN_SCALE_FROM)
	modulate = OPEN_FLASH
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "modulate", Color.WHITE, OPEN_DURATION)

func _on_open_finished() -> void:
	_set_open_progress(1.0)
	z_index = _rest_z
	modulate = Color.WHITE
	_open_tween = null

# Escala a partir do centro do tile: Sprite2D não tem pivô, então
# compensamos a posição na mão.
func _set_open_progress(s: float) -> void:
	scale = _rest_scale * s
	position = _rest_position + _rest_size * _rest_scale * (1.0 - s) * 0.5

func _capture_rest() -> void:
	if _rest_captured:
		return
	_rest_captured = true
	_rest_scale = scale
	_rest_position = position
	_rest_z = z_index
	if texture != null:
		_rest_size = texture.get_size()

func _cancel_open() -> void:
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	_open_tween = null
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = null
	reveal_pending = false
	if _rest_captured:
		scale = _rest_scale
		position = _rest_position
		z_index = _rest_z

func _update_visual() -> void:
	modulate = Color.WHITE
	var effective_rect := Vector4.ZERO
	var effective_tint := Vector4(1.0, 1.0, 1.0, 1.0)
	if reveal_pending:
		# Já revelado na lógica, mas a onda de abertura ainda não chegou aqui.
		texture = TEX_HIDDEN
	else:
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
