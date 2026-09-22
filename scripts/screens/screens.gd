## Switches between the meadow and the warren. Both stay alive and earning;
## hidden screens get picking turned off explicitly (Area2D ignores visibility).
class_name Screens
extends Node

const MEADOW := &"meadow"
const WARREN := &"warren"
const GROUP := &"screen_manager"

var current: StringName = MEADOW

var _screens: Dictionary = {}


## Reach the manager via group instead of a scene path.
static func manager(tree: SceneTree) -> Screens:
	return tree.get_first_node_in_group(GROUP) as Screens


func _ready() -> void:
	add_to_group(GROUP)
	_screens = {
		MEADOW: get_node_or_null("%Meadow"),
		WARREN: get_node_or_null("%WarrenInterior"),
	}
	for id: StringName in _screens:
		if _screens[id] == null:
			push_error("Screens: no node found for screen '%s'." % id)
	go_to(MEADOW)


func go_to(id: StringName) -> void:
	if not _screens.has(id) or _screens[id] == null:
		push_error("Screens: unknown screen '%s'." % id)
		return
	current = id
	for key: StringName in _screens:
		var screen: CanvasItem = _screens[key]
		if screen == null:
			continue
		var active := key == id
		screen.visible = active
		_set_picking(screen, active)
	Events.screen_changed.emit(id)


func toggle() -> void:
	go_to(WARREN if current == MEADOW else MEADOW)


## Hidden screens must not keep responding to clicks.
func _set_picking(node: Node, enabled: bool) -> void:
	if node is CollisionObject2D:
		(node as CollisionObject2D).input_pickable = enabled
	for c in node.get_children():
		_set_picking(c, enabled)
