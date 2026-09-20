## location assign site holding N workers (one bunny is just N=1).
class_name Site
extends Area2D

@export var def: SiteDef

var workers: int = 0:
	set(value):
		var clamped := clampi(value, 0, def.max_workers if def else 0)
		if clamped == workers:
			return
		workers = clamped
		Game._recalculate_rates()
		Events.site_workers_changed.emit(self, workers)


func _ready() -> void:
	if def == null:
		push_error("Site '%s' has no SiteDef assigned." % name)
		return
	input_pickable = true
	input_event.connect(_on_input_event)
	Game.register_producer(self)


func _exit_tree() -> void:
	Game.unregister_producer(self)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			harvest_by_hand()


## The Stage 1 core verb: click a bush, get a berry.
func harvest_by_hand() -> void:
	if def == null:
		return
	var amount := Big.from_float(def.click_yield)
	Game.wallet.add(def.resource_id, amount)
	Events.harvested.emit(def.resource_id, amount, global_position)
	Events.site_clicked.emit(self)


## worker cost scale
func next_worker_cost() -> BigNumber:
	if def == null:
		return Big.zero()
	var growth := Big.from_float(def.worker_cost_growth)
	return Big.mul(Big.from_float(def.worker_cost_base), Big.pow_big(growth, float(workers)))


func can_hire() -> bool:
	if def == null or workers >= def.max_workers:
		return false
	return Game.wallet.can_afford(def.cost_resource_id, next_worker_cost())


func try_hire() -> bool:
	if not can_hire():
		return false
	if not Game.wallet.try_spend(def.cost_resource_id, next_worker_cost()):
		return false
	workers += 1
	return true


## Called by Game each tick. Returns intent, Game commits
func production_request(_dt: float) -> Dictionary:
	if def == null or workers <= 0:
		return {}
	return {
		"produces": {def.resource_id: def.yield_per_worker * workers},
		"consumes": {},
	}
