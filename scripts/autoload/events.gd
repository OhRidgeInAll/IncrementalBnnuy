## Global signal bus
extends Node

## A resource was gained at position ; for spawning floating text.
signal harvested(resource_id: StringName, amount: BigNumber, world_pos: Vector2)

signal site_clicked(site: Node)

signal site_workers_changed(site: Node, workers: int)

signal balance_changed(resource_id: StringName, amount: BigNumber)

## Total production rate per second was recalculated.
signal rate_changed(resource_id: StringName, per_second: BigNumber)

## A save was loaded and the world should re-read game state.
signal game_loaded()

## Offline reapply for the welcome-back popup.
signal offline_progress(seconds: float, gains: Dictionary)
