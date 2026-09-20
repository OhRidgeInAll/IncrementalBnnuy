## Spawns and recycles FloatingText instances in response to harvests.
class_name FloatingTextLayer
extends Node2D

const POOL_SIZE := 24

var _pool: Array[FloatingText] = []


func _ready() -> void:
	for i in POOL_SIZE:
		var ft := FloatingText.new()
		ft.add_theme_font_size_override("font_size", 22)
		ft.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
		ft.add_theme_color_override("font_outline_color", Color(0.15, 0.1, 0.05))
		ft.add_theme_constant_override("outline_size", 5)
		ft.z_index = 100
		add_child(ft)
		_pool.append(ft)
	Events.harvested.connect(_on_harvested)


func _on_harvested(_resource_id: StringName, amount: BigNumber, world_pos: Vector2) -> void:
	var ft := _next_free()
	if ft == null:
		return
	# Jitter so rapid clicks on one bush do not stack into an unreadable blur.
	var jitter := Vector2(randf_range(-14.0, 14.0), randf_range(-6.0, 6.0))
	ft.play("+%s" % Big.fmt(amount), world_pos + jitter)


func _next_free() -> FloatingText:
	for ft in _pool:
		if not ft.is_active():
			return ft
	return null
