## Shows one bunny per worker on the parent Site, capped at MAX_VISIBLE for
## perf while the simulation keeps scaling.
class_name SiteBunnies
extends Node2D

const MAX_VISIBLE := 12
## Fan across the front of the bush instead of orbiting (a ring hid bunnies behind the sprite).
const ROW_RADIUS := [104.0, 150.0]
const ROW_CAPACITY := 6
const BUNNY_SCALE := 0.5

@export var bunny_scene: PackedScene

var _site: Site
var _bunnies: Array[Node2D] = []


func _ready() -> void:
	_site = get_parent() as Site
	if _site == null:
		push_error("SiteBunnies must be a child of a Site.")
		return
	Events.site_workers_changed.connect(_on_workers_changed)
	Events.game_loaded.connect(_sync)
	_sync()


func _on_workers_changed(site: Node, _workers: int) -> void:
	if site == _site:
		_sync()


func _sync() -> void:
	if bunny_scene == null or _site == null:
		return
	var want := mini(_site.workers, MAX_VISIBLE)
	while _bunnies.size() < want:
		var b := bunny_scene.instantiate() as Node2D
		add_child(b)
		_bunnies.append(b)
	while _bunnies.size() > want:
		var b: Node2D = _bunnies.pop_back()
		b.queue_free()
	_arrange()


## Lays bunnies in rows across the front arc.
func _arrange() -> void:
	var total := _bunnies.size()
	if total == 0:
		return
	var placed := 0
	var row := 0
	while placed < total:
		var in_row := mini(ROW_CAPACITY, total - placed)
		var radius: float = ROW_RADIUS[mini(row, ROW_RADIUS.size() - 1)]
		for i in in_row:
			# Sweep the front half only (below the bush in y-down space).
			var t := 0.5 if in_row == 1 else float(i) / float(in_row - 1)
			var angle := lerpf(PI * 0.88, PI * 0.12, t)
			var b := _bunnies[placed + i]
			b.position = Vector2(cos(angle) * radius, sin(angle) * radius * 0.42 + row * 30.0)
			b.scale = Vector2(BUNNY_SCALE, BUNNY_SCALE)
			# Face toward the bush they are foraging from.
			if cos(angle) < 0.0:
				b.scale.x = -BUNNY_SCALE
			# Nearer rows draw over farther ones.
			b.z_index = 2 + row
		placed += in_row
		row += 1
