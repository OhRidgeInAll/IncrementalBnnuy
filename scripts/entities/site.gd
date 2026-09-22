## A clickable harvest spot in the world, and a waypoint foragers path to.
##
## Sites hold no headcount. Bunnies roam to a random bush each trip rather than
## being stationed at one, so "who works here" is not a property of the bush.
## When jobs become assignable in Stage 2, assignment lands on the task, and
## sites gain a role then rather than carrying an unused one now.
class_name Site
extends Area2D

## Foragers locate bushes through this group rather than a scene path.
const GROUP := &"harvest_sites"

@export var def: SiteDef


func _ready() -> void:
	if def == null:
		push_error("Site '%s' has no SiteDef assigned." % name)
		return
	add_to_group(GROUP)
	input_pickable = true
	input_event.connect(_on_input_event)


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
