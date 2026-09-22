## A chamber you dig out once and it stays dug. Lives in the warren scene,
## not a menu; sealed rooms still show so the warren never looks finished.
class_name WarrenRoom
extends Node2D

enum State {
	SEALED,      ## Not enough lifetime berries yet: visible, but not offered.
	AVAILABLE,   ## Offered, affordable or not.
	OPEN,        ## Dug out. Permanent.
}

@export var def: RoomDef

@onready var _panel: ColorRect = %Panel
@onready var _name_label: Label = %NameLabel
@onready var _status_label: Label = %StatusLabel
@onready var _button: Button = %DigButton

const COLOR_SEALED := Color(0.28, 0.19, 0.16, 1.0)
const COLOR_AVAILABLE := Color(0.45, 0.31, 0.22, 1.0)
const COLOR_OPEN := Color(0.40, 0.52, 0.28, 1.0)


func _ready() -> void:
	if def == null:
		push_error("WarrenRoom '%s' has no RoomDef assigned." % name)
		return
	_button.pressed.connect(_on_dig_pressed)
	Events.unlocked.connect(_on_unlocked)
	Events.game_loaded.connect(_refresh)
	Game.register_room(self)
	Game.register_producer(self)
	_refresh()


func _exit_tree() -> void:
	Game.unregister_room(self)
	Game.unregister_producer(self)


func state() -> State:
	if def == null:
		return State.SEALED
	if Game.is_unlocked(def.id):
		return State.OPEN
	# Gated on lifetime so spending never re-seals it.
	if Big.gte(Game.wallet.get_lifetime(&"berry"), def.requires_lifetime):
		return State.AVAILABLE
	return State.SEALED


func can_dig() -> bool:
	return state() == State.AVAILABLE \
		and Game.wallet.can_afford(def.cost_resource_id, def.unlock_cost)


func try_dig() -> bool:
	if not can_dig():
		return false
	if not Game.wallet.try_spend(def.cost_resource_id, def.unlock_cost):
		return false
	Game.unlock(def.id)
	return true


func _on_dig_pressed() -> void:
	try_dig()
	_refresh()


func _on_unlocked(id: StringName) -> void:
	if def != null and id == def.id:
		_refresh()


func _process(_delta: float) -> void:
	if def == null:
		return
	# Affordability and the gate drift every tick, so watch.
	var s := state()
	if s != _shown_state:
		_refresh()
	elif s == State.AVAILABLE:
		_button.disabled = not can_dig()


var _shown_state: State = State.SEALED


func _refresh() -> void:
	if def == null:
		return
	var s := state()
	_shown_state = s
	_name_label.text = def.display_name
	match s:
		State.OPEN:
			_panel.color = COLOR_OPEN
			_status_label.text = _effect_text()
			_button.visible = false
		State.AVAILABLE:
			_panel.color = COLOR_AVAILABLE
			_status_label.text = def.description
			_button.visible = true
			_button.text = "Dig out  %s" % Big.fmt(Big.from_float(def.unlock_cost))
			_button.disabled = not can_dig()
		State.SEALED:
			_panel.color = COLOR_SEALED
			_name_label.text = "???"
			_status_label.text = "Sealed. %s berries earned to reach it." \
				% Big.fmt(Big.from_float(def.requires_lifetime))
			_button.visible = false


## Plain-language list of the room's effects.
func _effect_text() -> String:
	var parts: Array[String] = []
	if def.extra_max_workers > 0.0:
		parts.append("+%d bunny slots" % int(def.extra_max_workers))
	if def.extra_offline_hours > 0.0:
		parts.append("+%d h offline" % int(def.extra_offline_hours))
	if def.berries_per_second > 0.0:
		parts.append("+%s berries/sec" % Big.fmt(Big.from_float(def.berries_per_second), -1, false))
	if parts.is_empty():
		return "Dug out."
	return ", ".join(parts)


## Same tick loop as everything, so catch-up covers it for free.
func production_request(_dt: float) -> Dictionary:
	if def == null or def.berries_per_second <= 0.0 or not Game.is_unlocked(def.id):
		return {}
	return {"produces": {&"berry": def.berries_per_second}, "consumes": {}}
