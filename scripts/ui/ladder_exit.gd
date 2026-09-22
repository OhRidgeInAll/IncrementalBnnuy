## The ladder back up to the meadow.
class_name LadderExit
extends Button


func _ready() -> void:
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	var screens := Screens.manager(get_tree())
	if screens != null:
		screens.go_to(Screens.MEADOW)
