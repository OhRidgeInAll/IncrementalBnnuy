## A harvestable spot in the world; tuned in .tres files. Passive yield comes
## from foragers (TaskDef), not workers parked here.
class_name SiteDef
extends Resource

@export_group("Identity")
@export var id: StringName = &"berry_bush"
@export var display_name: String = "Berry Bush"
@export var resource_id: StringName = &"berry"

@export_group("Hand Harvesting")
## Resources per manual click.
@export var click_yield: float = 1.0
