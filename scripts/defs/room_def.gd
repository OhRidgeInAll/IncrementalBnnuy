## A room dug out of the warren. Each is a .tres file, and its effects are
## plain numbers that Game.room_bonus() sums across unlocked rooms.
class_name RoomDef
extends Resource

@export_group("Identity")
@export var id: StringName = &"nursery"
@export var display_name: String = "Nursery"
@export_multiline var description: String = ""

@export_group("Unlocking")
## Lifetime berries earned before the room is even visible (a gate, not a price).
@export var requires_lifetime: float = 0.0
## Cost to dig it out.
@export var unlock_cost: float = 100.0
@export var cost_resource_id: StringName = &"berry"

@export_group("Effects")
## Raises the headcount cap on every task.
@export var extra_max_workers: float = 0.0
## Extends how long an absence keeps paying out.
@export var extra_offline_hours: float = 0.0
## Flat berries per second, no bunny required.
@export var berries_per_second: float = 0.0
