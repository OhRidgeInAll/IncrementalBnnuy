## A "+1" that drifts up and fades; pooled to avoid per-click allocs.
class_name FloatingText
extends Label

const RISE_PIXELS := 48.0
const LIFETIME := 0.9

var _elapsed := 0.0
var _start := Vector2.ZERO
var _active := false


func _ready() -> void:
	set_process(false)
	modulate.a = 0.0


func play(text_value: String, world_pos: Vector2) -> void:
	text = text_value
	_start = world_pos - Vector2(size.x * 0.5, 0.0)
	position = _start
	_elapsed = 0.0
	_active = true
	modulate.a = 1.0
	set_process(true)


func is_active() -> bool:
	return _active


func _process(delta: float) -> void:
	_elapsed += delta
	var t := _elapsed / LIFETIME
	if t >= 1.0:
		_active = false
		modulate.a = 0.0
		set_process(false)
		return
	# Ease-out rise so the number pops immediately then settles.
	position = _start + Vector2(0.0, -RISE_PIXELS * (1.0 - pow(1.0 - t, 3.0)))
	modulate.a = 1.0 - pow(t, 2.0)
