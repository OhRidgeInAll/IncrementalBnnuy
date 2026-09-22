## The warren notice board: who's working what.
class_name JobBoard
extends VBoxContainer

## Jobs to show; add a TaskDef here to add a job.
@export var tasks: Array[TaskDef] = []

@onready var _rows: VBoxContainer = %Rows

var _labels: Dictionary = {}          ## StringName -> Label


func _ready() -> void:
	for task in tasks:
		if task == null:
			continue
		var row := Label.new()
		row.add_theme_font_size_override("font_size", 15)
		row.add_theme_color_override("font_color", Color(0.88, 0.85, 0.75))
		_rows.add_child(row)
		_labels[task.id] = row
	Events.task_count_changed.connect(_on_changed)
	Events.unlocked.connect(_on_unlocked)
	Events.game_loaded.connect(_refresh)
	_refresh()


func _on_changed(_task_id: StringName, _count: int) -> void:
	_refresh()


func _on_unlocked(_id: StringName) -> void:
	# The Nursery changes the ceiling every row displays.
	_refresh()


func _refresh() -> void:
	var cap_bonus := int(Game.room_bonus(&"extra_max_workers"))
	for task in tasks:
		if task == null or not _labels.has(task.id):
			continue
		var label: Label = _labels[task.id]
		label.text = "%s   %d / %d" % [
			task.display_name,
			Game.get_task_count(task.id),
			task.max_workers + cap_bonus,
		]
