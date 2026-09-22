## Global signal bus

## A resource was gained at position ; for spawning floating text.
signal harvested(resource_id: StringName, amount: BigNumber, world_pos: Vector2)

signal site_clicked(site: Node)

## Bunnies assigned to a task changed. The world spawns foragers to match.
signal task_count_changed(task_id: StringName, count: int)

signal balance_changed(resource_id: StringName, amount: BigNumber)

## Total production rate per second was recalculated.
signal rate_changed(resource_id: StringName, per_second: BigNumber)

## Unlock flag: warren, moon, etc.
signal unlocked(id: StringName)

## The player moved between rooms: meadow, warren, moon, etc.
signal screen_changed(screen_id: StringName)

## A save was loaded and the world should re-read game state.
signal game_loaded()

## Offline earnings were applied, for the welcome-back popup.
signal offline_progress(seconds: float, gains: Dictionary)
