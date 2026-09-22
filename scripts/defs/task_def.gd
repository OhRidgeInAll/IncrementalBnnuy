## A job bunnies can be assigned to; headcount is tracked per task.
class_name TaskDef
extends Resource

@export_group("Identity")
@export var id: StringName = &"forage_berries"
@export var display_name: String = "Forager"
@export var resource_id: StringName = &"berry"

@export_group("Yield")
## Resources dropped at the warren each cycle.
@export var deposit_amount: float = 5.0
## Seconds for one round trip; rate = deposit_amount / cycle_seconds.
@export var cycle_seconds: float = 5.0

@export_group("Hiring")
@export var hire_cost_base: float = 10.0
## Cost multiplier per bunny (1.15 = Cookie Clicker default).
@export var hire_cost_growth: float = 1.15
@export var cost_resource_id: StringName = &"berry"
## Cap on bunnies for this task.
@export var max_workers: int = 12


## Per-bunny rate per second.
func rate_per_worker() -> float:
	if cycle_seconds <= 0.0:
		return 0.0
	return deposit_amount / cycle_seconds
