## Data for a production site; tuned in .tres files, not code.
class_name SiteDef
extends Resource

@export_group("Identity")
@export var id: StringName = &"berry_bush"
@export var display_name: String = "Berry Bush"
@export var resource_id: StringName = &"berry"

@export_group("Hand Harvesting")
## Resources granted per manual click.
@export var click_yield: float = 1.0

@export_group("Workers")
## Resources per second contributed by each assigned worker.
@export var yield_per_worker: float = 0.5
@export var max_workers: int = 5
## Cost of the first worker, in `cost_resource_id`.
@export var worker_cost_base: float = 10.0
## Cost multiplier per worker (1.15 = Cookie Clicker default).
@export var worker_cost_growth: float = 1.15
@export var cost_resource_id: StringName = &"berry"
