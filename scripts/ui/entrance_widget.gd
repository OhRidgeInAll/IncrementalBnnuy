## Recruitment prompt anchored on the stump, plus the way down.
## Bunnies are hired here because they roam between bushes, not at one plant.
class_name EntranceWidget
extends VBoxContainer

@onready var _count_label: Label = %CountLabel
@onready var _hire_button: Button = %HireButton
@onready var _warren_button: Button = %WarrenButton

var _entrance: WarrenEntrance


func _ready() -> void:
	_entrance = get_parent() as WarrenEntrance
	if _entrance == null:
		push_error("EntranceWidget must be a child of a WarrenEntrance.")
		return
	_hire_button.pressed.connect(_on_hire_pressed)
	_warren_button.pressed.connect(_on_warren_pressed)
	Events.task_count_changed.connect(_on_task_count_changed)
	Events.unlocked.connect(_on_unlocked)
	Events.game_loaded.connect(_refresh)
	_refresh()


func _on_hire_pressed() -> void:
	_entrance.try_hire()
	_refresh()


## One button: digs the first time, walks down after.
func _on_warren_pressed() -> void:
	if not _entrance.is_warren_open():
		if not _entrance.try_dig_warren():
			return
		_refresh()
	var screens := Screens.manager(get_tree())
	if screens != null:
		screens.go_to(Screens.WARREN)


func _on_task_count_changed(_task_id: StringName, _count: int) -> void:
	_refresh()


func _on_unlocked(_id: StringName) -> void:
	_refresh()


func _process(_delta: float) -> void:
	if _entrance == null:
		return
	# Affordability and the gate drift every tick, so poll.
	_hire_button.disabled = not _entrance.can_hire()
	var offered := _entrance.warren_offered()
	if _warren_button.visible != offered:
		_refresh()
	elif offered and not _entrance.is_warren_open():
		_warren_button.disabled = not _entrance.can_dig_warren()


func _refresh() -> void:
	if _entrance == null or _entrance.task == null:
		return
	_count_label.text = "%d / %d bunnies" % [_entrance.count(), _entrance.max_workers()]
	if _entrance.count() >= _entrance.max_workers():
		_hire_button.text = "Warren full"
	else:
		_hire_button.text = "Hire bunny  %s" % Big.fmt(_entrance.next_hire_cost())

	_warren_button.visible = _entrance.warren_offered()
	if _entrance.is_warren_open():
		_warren_button.text = "Enter the warren"
		_warren_button.disabled = false
	else:
		_warren_button.text = "Dig into the stump  %s" \
			% Big.fmt(Big.from_float(_entrance.warren_dig_cost))
		_warren_button.disabled = not _entrance.can_dig_warren()
