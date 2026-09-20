## Floating hire prompt above a Site; assignment happens on the bush itself.
class_name SiteWidget
extends VBoxContainer

@onready var _workers_label: Label = %WorkersLabel
@onready var _hire_button: Button = %HireButton

var _site: Site


func _ready() -> void:
	_site = get_parent() as Site
	if _site == null:
		push_error("SiteWidget must be a child of a Site.")
		return
	_hire_button.pressed.connect(_on_hire_pressed)
	Events.site_workers_changed.connect(_on_workers_changed)
	_refresh()


func _on_hire_pressed() -> void:
	_site.try_hire()
	_refresh()


func _on_workers_changed(site: Node, _workers: int) -> void:
	if site == _site:
		_refresh()


func _process(_delta: float) -> void:
	# Affordability drifts every tick, so poll it.
	_hire_button.disabled = not _site.can_hire()


func _refresh() -> void:
	if _site == null or _site.def == null:
		return
	_workers_label.text = "%d / %d bunnies" % [_site.workers, _site.def.max_workers]
	if _site.workers >= _site.def.max_workers:
		_hire_button.text = "Full"
	else:
		_hire_button.text = "Hire  %s" % Big.fmt(_site.next_worker_cost())
