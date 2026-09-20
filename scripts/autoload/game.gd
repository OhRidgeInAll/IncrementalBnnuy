
extends Node

const TICK_HZ := 10.0
const TICK_DT := 1.0 / TICK_HZ

## Max ticks per frame before the backlog is bulk-credited.
const MAX_TICKS_PER_FRAME := 20

## Long gaps run as this many coarse ticks, bounding converter error.
const CATCHUP_CHUNKS := 10

## No AFK wins
const MAX_OFFLINE_SECONDS := 8.0 * 3600.0

## Resources granted by offline and catch-up progress.
const CATCHUP_RESOURCES: Array[StringName] = [&"berry", &"jam"]

var wallet: Wallet = Wallet.new()

## Offline seconds held until producers register.
var _pending_offline := 0.0
var _accumulator := 0.0
var _producers: Array[Node] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	wallet.balance_changed.connect(_on_balance_changed)


func _on_balance_changed(resource_id: StringName, amount: BigNumber) -> void:
	Events.balance_changed.emit(resource_id, amount)


## producer responsible to register themself.
## returning {"produces": {id: rate}, "consumes": {id: rate}}.
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

	if _accumulator >= TICK_DT:
		var carry := fmod(_accumulator, TICK_DT)
		grant_elapsed(_accumulator - carry)
		_accumulator = carry


func _tick(dt: float) -> void:
	# intents
	var requests: Array[Dictionary] = []
	for p in _producers:
		if not is_instance_valid(p):
			continue
		if p.has_method("production_request"):
			var req: Dictionary = p.production_request(dt)
			if not req.is_empty():
				requests.append(req)

	# commit, starve unafforded
	for req in requests:
		var consumes: Dictionary = req.get("consumes", {})
		if not consumes.is_empty():
			var basket := {}
			for id: StringName in consumes:
				basket[id] = Big.from_float(float(consumes[id]) * dt)
			if not wallet.try_spend_many(basket):
				continue
		var produces: Dictionary = req.get("produces", {})
		for id: StringName in produces:
			var gain := float(produces[id]) * dt
			if gain > 0.0:
				wallet.add(id, gain)


## Simulates `seconds` in a few coarse ticks; shared by offline and catch-up.
func grant_elapsed(seconds: float) -> Dictionary:
	if seconds <= 0.0 or _producers.is_empty():
		return {}
	var before := {}
	for id: StringName in CATCHUP_RESOURCES:
		before[id] = wallet.get_amount(id)

	var chunk := seconds / float(CATCHUP_CHUNKS)
	for i in CATCHUP_CHUNKS:
		_tick(chunk)

	var gains := {}
	for id: StringName in CATCHUP_RESOURCES:
		var delta := Big.sub(wallet.get_amount(id), before[id])
		if not Big.is_zero(delta):
			gains[id] = delta
	return gains


## Total per-second output across all producers, for the HUD.
func rate_of(resource_id: StringName) -> BigNumber:
	var total := Big.zero()
	for p in _producers:
		if not is_instance_valid(p) or not p.has_method("production_request"):
			continue
		var req: Dictionary = p.production_request(1.0)
		var produces: Dictionary = req.get("produces", {})
		if produces.has(resource_id):
			total = Big.add(total, float(produces[resource_id]))
	return total


func _recalculate_rates() -> void:
	Events.rate_changed.emit(&"berry", rate_of(&"berry"))


func queue_offline(seconds: float) -> void:
	_pending_offline = clampf(seconds, 0.0, MAX_OFFLINE_SECONDS)


func _apply_offline() -> void:
	var seconds := _pending_offline
	_pending_offline = 0.0
	if seconds <= 0.0:
		return
	var gains := grant_elapsed(seconds)
	if not gains.is_empty():
		Events.offline_progress.emit(seconds, gains)


func to_save() -> Dictionary:
	return {"wallet": wallet.to_save()}


func from_save(data: Dictionary) -> void:
	wallet.from_save(data.get("wallet", {}))
