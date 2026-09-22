## Game loop: Handled in ticks, fps agnostic
##
## Producers implement one or both of:
##   production_request(dt)   -- continuous output, committed every live tick.
##   catchup_request(seconds) -- aggregate output over a long gap.
## A producer that pays out on discrete events (a forager finishing a round
## trip) implements only the second: its bunnies credit themselves while the
## game is open, so charging the wallet again each tick would pay twice.
extends Node

const TICK_HZ := 10.0
const TICK_DT := 1.0 / TICK_HZ

## Ticks allowed in a single frame before the remainder is bulk-credited.
## Without a ceiling, one long stall would try to simulate the whole gap tick by
## tick and stall the game further.
const MAX_TICKS_PER_FRAME := 20

## How long until we move to bulk credit
const MAX_LIVE_DELTA := 20 * (1.0 / 10.0)

## large gaps get credited in large chunks
const CATCHUP_CHUNKS := 10

## No AFK wins
const MAX_OFFLINE_SECONDS := 8.0 * 3600.0

## Resources granted by offline and catch-up progress.
const CATCHUP_RESOURCES: Array[StringName] = [&"berry", &"jam"]

var wallet: Wallet = Wallet.new()

## Bunny/task used as guideline for spawning.
var task_counts: Dictionary = {}

## offline time not yet applied. Waits until producers so it has a rate to apply catch up.
var _pending_offline := 0.0
var _accumulator := 0.0
var _producers: Array[Node] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	wallet.balance_changed.connect(_on_balance_changed)


func _on_balance_changed(resource_id: StringName, amount: BigNumber) -> void:
	Events.balance_changed.emit(resource_id, amount)


#region Task headcount

func get_task_count(task_id: StringName) -> int:
	return int(task_counts.get(task_id, 0))


func set_task_count(task_id: StringName, count: int) -> void:
	var clamped := maxi(0, count)
	if get_task_count(task_id) == clamped:
		return
	task_counts[task_id] = clamped
	Events.task_count_changed.emit(task_id, clamped)
	_recalculate_rates()

#endregion


#region Progression

var unlocked: Dictionary = {}

var _rooms: Array[Node] = []


func is_unlocked(id: StringName) -> bool:
	return bool(unlocked.get(id, false))


func unlock(id: StringName) -> void:
	if is_unlocked(id):
		return
	unlocked[id] = true
	Events.unlocked.emit(id)
	_recalculate_rates()


## Rooms self-register
func register_room(room: Node) -> void:
	if room not in _rooms:
		_rooms.append(room)


func unregister_room(room: Node) -> void:
	_rooms.erase(room)


## Sums one numeric perk across every unlocked room. Rooms declare their effects
## as plain exported numbers, so a new room is a .tres file rather than code.
func room_bonus(field: StringName) -> float:
	var total := 0.0
	for r in _rooms:
		if not is_instance_valid(r) or r.def == null:
			continue
		if not is_unlocked(r.def.id):
			continue
		total += float(r.def.get(field))
	return total

#endregion


## producer responsible to register themself.
func register_producer(node: Node) -> void:
	if node not in _producers:
		_producers.append(node)
		_recalculate_rates()
		if _pending_offline > 0.0:
			_apply_offline()


func unregister_producer(node: Node) -> void:
	_producers.erase(node)
	_recalculate_rates()


func _process(delta: float) -> void:
	_accumulator += delta
	var ticks := 0
	while _accumulator >= TICK_DT and ticks < MAX_TICKS_PER_FRAME:
		_accumulator -= TICK_DT
		_tick(TICK_DT)
		ticks += 1

	# Still behind? Credit the backlog in bulk
	if _accumulator >= TICK_DT:
		var carry := fmod(_accumulator, TICK_DT)
		grant_elapsed(_accumulator - carry)
		_accumulator = carry


## producer intent
func _gather(dt: float, catchup: bool) -> Array[Dictionary]:
	var requests: Array[Dictionary] = []
	for p in _producers:
		if not is_instance_valid(p):
			continue
		var req: Dictionary = {}
		if catchup and p.has_method("catchup_request"):
			req = p.catchup_request(dt)
		elif p.has_method("production_request"):
			req = p.production_request(dt)
		if not req.is_empty():
			requests.append(req)
	return requests


func _tick(dt: float, catchup: bool = false) -> void:
	for req in _gather(dt, catchup):
		var consumes: Dictionary = req.get("consumes", {})
		if not consumes.is_empty():
			var basket := {}
			for id: StringName in consumes:
				basket[id] = Big.from_float(float(consumes[id]) * dt)
			# A converter whose inputs are unaffordable starves for this tick
			# rather than going negative.
			if not wallet.try_spend_many(basket):
				continue
		var produces: Dictionary = req.get("produces", {})
		for id: StringName in produces:
			var gain := float(produces[id]) * dt
			if gain > 0.0:
				wallet.add(id, gain)


## Simulates 'seconds' elapsed
func grant_elapsed(seconds: float) -> Dictionary:
	if seconds <= 0.0 or _producers.is_empty():
		return {}
	var before := {}
	for id: StringName in CATCHUP_RESOURCES:
		before[id] = wallet.get_amount(id)

	var chunk := seconds / float(CATCHUP_CHUNKS)
	for i in CATCHUP_CHUNKS:
		_tick(chunk, true)

	var gains := {}
	for id: StringName in CATCHUP_RESOURCES:
		var delta := Big.sub(wallet.get_amount(id), before[id])
		if not Big.is_zero(delta):
			gains[id] = delta
	return gains


## Average per-second output across all producers, for the HUD.

func rate_of(resource_id: StringName) -> BigNumber:
	var total := Big.zero()
	for req in _gather(1.0, true):
		var produces: Dictionary = req.get("produces", {})
		if produces.has(resource_id):
			total = Big.add(total, float(produces[resource_id]))
	return total


func _recalculate_rates() -> void:
	Events.rate_changed.emit(&"berry", rate_of(&"berry"))


## How long an absence still pays out. The Vault extends this, which is the
## whole reason a returning player would care about it.
func max_offline_seconds() -> float:
	return MAX_OFFLINE_SECONDS + room_bonus(&"extra_offline_hours") * 3600.0


## Queues offline time to be granted once producers exist. A backwards clock
## (timezone change, manual adjustment) clamps to zero rather than granting.
func queue_offline(seconds: float) -> void:
	_pending_offline = clampf(seconds, 0.0, max_offline_seconds())


func _apply_offline() -> void:
	var seconds := _pending_offline
	_pending_offline = 0.0
	if seconds <= 0.0:
		return
	var gains := grant_elapsed(seconds)
	if not gains.is_empty():
		Events.offline_progress.emit(seconds, gains)


func to_save() -> Dictionary:
	var tasks := {}
	for id: StringName in task_counts:
		tasks[String(id)] = int(task_counts[id])
	var opened := []
	for id: StringName in unlocked:
		if unlocked[id]:
			opened.append(String(id))
	return {"wallet": wallet.to_save(), "tasks": tasks, "unlocked": opened}


func from_save(data: Dictionary) -> void:
	wallet.from_save(data.get("wallet", {}))

	# Every task the world currently knows about has to hear about the load
	var touched := {}
	for id: StringName in task_counts:
		touched[id] = true

	task_counts.clear()
	var tasks: Dictionary = data.get("tasks", {})
	for id: String in tasks:
		task_counts[StringName(id)] = int(tasks[id])
		touched[StringName(id)] = true

	var was_unlocked := unlocked.duplicate()
	unlocked.clear()
	for id: String in data.get("unlocked", []):
		unlocked[StringName(id)] = true

	for id: StringName in touched:
		Events.task_count_changed.emit(id, get_task_count(id))
	for id: StringName in was_unlocked:
		Events.unlocked.emit(id)
	for id: StringName in unlocked:
		Events.unlocked.emit(id)
	_recalculate_rates()
