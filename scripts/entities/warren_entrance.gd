## The stump: recruits bunnies, takes their haul, and leads down into the warren.
## Holds no headcount; it just spawns foragers to match Game.task_counts.
class_name WarrenEntrance
extends Node2D

@export var task: TaskDef
@export var forager_scene: PackedScene

@export_group("The Way Down")
## Progression flag set once the player has dug through into the warren.
@export var warren_id: StringName = &"warren"
## Lifetime berries before the way down is even mentioned.
@export var warren_requires_lifetime: float = 150.0
@export var warren_dig_cost: float = 200.0

var _foragers: Array[Forager] = []


func _ready() -> void:
	if task == null:
		push_error("WarrenEntrance has no TaskDef assigned.")
		return
	Events.task_count_changed.connect(_on_task_count_changed)
	Events.game_loaded.connect(_sync)
	Game.register_producer(self)
	_sync()


func _exit_tree() -> void:
	Game.unregister_producer(self)


func _on_task_count_changed(task_id: StringName, _count: int) -> void:
	if task != null and task_id == task.id:
		_sync()


## Brings the world in line with the saved headcount.
func _sync() -> void:
	if task == null or forager_scene == null:
		return
	var want := mini(Game.get_task_count(task.id), max_workers())
	while _foragers.size() < want:
		_spawn_forager()
	while _foragers.size() > want:
		var f: Forager = _foragers.pop_back()
		f.queue_free()


func _spawn_forager() -> void:
	var f := forager_scene.instantiate() as Forager
	f.task = task
	# Home is the stump; foragers scatter their own unloading spot.
	f.home_position = global_position
	add_child(f)
	# Stagger arrivals so a reload doesn't dump every haul on one frame.
	f.stagger(randf())
	_foragers.append(f)


#region Hiring

func count() -> int:
	return Game.get_task_count(task.id) if task != null else 0


## base * growth^n.
func next_hire_cost() -> BigNumber:
	if task == null:
		return Big.zero()
	var growth := Big.from_float(task.hire_cost_growth)
	return Big.mul(Big.from_float(task.hire_cost_base), Big.pow_big(growth, float(count())))


## Headcount cap, plus whatever rooms add to it.
func max_workers() -> int:
	if task == null:
		return 0
	return task.max_workers + int(Game.room_bonus(&"extra_max_workers"))


func can_hire() -> bool:
	if task == null or count() >= max_workers():
		return false
	return Game.wallet.can_afford(task.cost_resource_id, next_hire_cost())


func try_hire() -> bool:
	if not can_hire():
		return false
	if not Game.wallet.try_spend(task.cost_resource_id, next_hire_cost()):
		return false
	Game.set_task_count(task.id, count() + 1)
	return true

#endregion


#region The way down

## Whether the player has broken through into the warren yet.
func is_warren_open() -> bool:
	return Game.is_unlocked(warren_id)


## Whether to show the way down at all (lifetime-gated, so spending won't hide it).
func warren_offered() -> bool:
	return Big.gte(Game.wallet.get_lifetime(&"berry"), warren_requires_lifetime)


func can_dig_warren() -> bool:
	return not is_warren_open() and warren_offered() \
		and Game.wallet.can_afford(&"berry", warren_dig_cost)


func try_dig_warren() -> bool:
	if not can_dig_warren():
		return false
	if not Game.wallet.try_spend(&"berry", warren_dig_cost):
		return false
	Game.unlock(warren_id)
	return true

#endregion


## Covers time the sim didn't run (offline / stalls). Foragers pay for live
## time themselves, so this only handles the remainder.
func catchup_request(_seconds: float) -> Dictionary:
	if task == null:
		return {}
	var heads := mini(count(), task.max_workers)
	if heads <= 0:
		return {}
	return {
		"produces": {task.resource_id: task.rate_per_worker() * heads},
		"consumes": {},
	}
