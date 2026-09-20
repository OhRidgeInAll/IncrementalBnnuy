## spending is guarded so an overdraw can't silently credit the player.
class_name Wallet
extends RefCounted

## Emitted when a balance changes; carries a copy.
signal balance_changed(resource_id: StringName, amount: BigNumber)

var _balances: Dictionary = {}          ## StringName -> BigNumber (owned)
var _lifetime: Dictionary = {}          ## StringName -> BigNumber (owned, never spent down)


func get_amount(resource_id: StringName) -> BigNumber:
	if not _balances.has(resource_id):
		return Big.zero()
	return Big.copy(_balances[resource_id])


## Total ever earned
func get_lifetime(resource_id: StringName) -> BigNumber:
	if not _lifetime.has(resource_id):
		return Big.zero()
	return Big.copy(_lifetime[resource_id])


func add(resource_id: StringName, amount: Variant) -> void:
	var delta := Big.coerce(amount)
	if Big.is_zero(delta):
		return
	_balances[resource_id] = Big.add(get_amount(resource_id), delta)
	_lifetime[resource_id] = Big.add(get_lifetime(resource_id), delta)
	balance_changed.emit(resource_id, Big.copy(_balances[resource_id]))


func can_afford(resource_id: StringName, cost: Variant) -> bool:
	return Big.gte(get_amount(resource_id), cost)


func try_spend(resource_id: StringName, cost: Variant) -> bool:
	var price := Big.coerce(cost)
	if not can_afford(resource_id, price):
		return false
	_balances[resource_id] = Big.sub(get_amount(resource_id), price)
	balance_changed.emit(resource_id, Big.copy(_balances[resource_id]))
	return true


func try_spend_many(costs: Dictionary) -> bool:
	for resource_id: StringName in costs:
		if not can_afford(resource_id, costs[resource_id]):
			return false
	for resource_id: StringName in costs:
		try_spend(resource_id, costs[resource_id])
	return true


func resource_ids() -> Array:
	return _balances.keys()


func to_save() -> Dictionary:
	var balances := {}
	for k: StringName in _balances:
		balances[String(k)] = Big.to_save(_balances[k])
	var lifetime := {}
	for k: StringName in _lifetime:
		lifetime[String(k)] = Big.to_save(_lifetime[k])
	return {"balances": balances, "lifetime": lifetime}


func from_save(data: Dictionary) -> void:
	_balances.clear()
	_lifetime.clear()
	for k: String in data.get("balances", {}):
		_balances[StringName(k)] = Big.from_save(data["balances"][k])
	for k: String in data.get("lifetime", {}):
		_lifetime[StringName(k)] = Big.from_save(data["lifetime"][k])
	for k: StringName in _balances:
		balance_changed.emit(k, Big.copy(_balances[k]))
