## A bunny that roams out to a bush and hauls back to the warren.
## The walk is cosmetic; only the deposit at cycle's end credits berries.
class_name Forager
extends Node2D

enum Phase { TO_BUSH, AT_BUSH, TO_WARREN, DEPOSIT }

## Fractions of one cycle, in phase order. Must sum to 1.0.
const PHASE_SHARE := {
	Phase.TO_BUSH: 0.30,
	Phase.AT_BUSH: 0.28,
	Phase.TO_WARREN: 0.34,
	Phase.DEPOSIT: 0.08,
}

const HOP_HEIGHT := 7.0
const HOP_SPEED := 9.0

var task: TaskDef
var home_position: Vector2 = Vector2.ZERO

var _phase: Phase = Phase.TO_BUSH
var _phase_elapsed := 0.0
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _sprite: AnimatedSprite2D


func _ready() -> void:
	_sprite = get_node_or_null("Sprite") as AnimatedSprite2D
	global_position = home_position
	_from = home_position
	_to = home_position


## Starts a bunny mid-cycle so the warren doesn't move in lockstep.
## Done by hand because _begin_phase would set out from the wrong spot.
func stagger(fraction: float) -> void:
	var cycle := _cycle_seconds()
	var target := fraction * cycle
	var walked := 0.0
	for phase in [Phase.TO_BUSH, Phase.AT_BUSH, Phase.TO_WARREN, Phase.DEPOSIT]:
		var dur := _phase_duration(phase)
		if target <= walked + dur:
			_phase = phase
			break
		walked += dur
	_phase_elapsed = target - walked

	var bush := _pick_bush()
	var den := _warren_spot()
	match _phase:
		Phase.TO_BUSH:
			_from = den
			_to = bush
		Phase.AT_BUSH:
			_from = bush
			_to = bush
		Phase.TO_WARREN:
			_from = bush
			_to = den
		Phase.DEPOSIT:
			_from = den
			_to = den
	var t := clampf(_phase_elapsed / maxf(_phase_duration(_phase), 0.0001), 0.0, 1.0)
	global_position = _from.lerp(_to, t)
	_face_travel()


func _cycle_seconds() -> float:
	return task.cycle_seconds if task != null else 5.0


func _phase_duration(phase: Phase) -> float:
	return _cycle_seconds() * float(PHASE_SHARE[phase])


func _process(delta: float) -> void:
	if task == null:
		return
	# Clamp a stall so live sim and catch-up don't pay for the same time twice.
	_phase_elapsed += minf(delta, Game.MAX_LIVE_DELTA)
	var duration := _phase_duration(_phase)
	while _phase_elapsed >= duration:
		_phase_elapsed -= duration
		_advance_phase()
		duration = _phase_duration(_phase)

	var t := clampf(_phase_elapsed / maxf(duration, 0.0001), 0.0, 1.0)
	match _phase:
		Phase.TO_BUSH, Phase.TO_WARREN:
			# Ease in and out so bunnies settle rather than snapping to a stop.
			global_position = _from.lerp(_to, smoothstep(0.0, 1.0, t))
			_hop()
		_:
			global_position = _to


func _hop() -> void:
	if _sprite == null:
		return
	# Cosmetic bob. Sits on the sprite so it cannot drift the logical position.
	_sprite.position.y = -absf(sin(_phase_elapsed * HOP_SPEED)) * HOP_HEIGHT


func _advance_phase() -> void:
	match _phase:
		Phase.TO_BUSH:
			_phase = Phase.AT_BUSH
		Phase.AT_BUSH:
			_phase = Phase.TO_WARREN
		Phase.TO_WARREN:
			_phase = Phase.DEPOSIT
		Phase.DEPOSIT:
			_phase = Phase.TO_BUSH
	_begin_phase(_phase, true)


func _begin_phase(phase: Phase, do_deposit: bool) -> void:
	match phase:
		Phase.TO_BUSH:
			_from = global_position
			_to = _pick_bush()
			_face_travel()
		Phase.AT_BUSH:
			_from = global_position
			_to = global_position
			if _sprite != null:
				_sprite.position.y = 0.0
		Phase.TO_WARREN:
			_from = global_position
			_to = _warren_spot()
			_face_travel()
		Phase.DEPOSIT:
			_from = global_position
			_to = global_position
			if _sprite != null:
				_sprite.position.y = 0.0
			if do_deposit:
				_deposit()


## Picks a fresh bush each trip.
func _pick_bush() -> Vector2:
	var sites := get_tree().get_nodes_in_group(Site.GROUP)
	if sites.is_empty():
		return _warren_spot()
	var site: Node2D = sites[randi() % sites.size()]
	var spread := Vector2(randf_range(-92.0, 92.0), randf_range(26.0, 64.0))
	return site.global_position + spread


## A spread-out spot to stand while unloading.
func _warren_spot() -> Vector2:
	return home_position + Vector2(randf_range(-104.0, 104.0), randf_range(58.0, 104.0))


func _face_travel() -> void:
	if _sprite == null:
		return
	_sprite.scale.x = -absf(_sprite.scale.x) if _to.x < _from.x else absf(_sprite.scale.x)


func _deposit() -> void:
	if task == null:
		return
	var amount := Big.from_float(task.deposit_amount)
	Game.wallet.add(task.resource_id, amount)
	Events.harvested.emit(task.resource_id, amount, global_position)
