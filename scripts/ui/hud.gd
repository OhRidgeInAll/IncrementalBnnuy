## Top-bar readout: how many berries, and how fast they are coming in.
extends CanvasLayer

@onready var _berry_label: Label = %BerryLabel
@onready var _rate_label: Label = %RateLabel


func _ready() -> void:
	Events.balance_changed.connect(_on_balance_changed)
	Events.rate_changed.connect(_on_rate_changed)
	Events.offline_progress.connect(_on_offline_progress)
	_on_balance_changed(&"berry", Game.wallet.get_amount(&"berry"))
	_on_rate_changed(&"berry", Game.rate_of(&"berry"))


func _on_balance_changed(resource_id: StringName, amount: BigNumber) -> void:
	if resource_id != &"berry":
		return
	_berry_label.text = "%s berries" % Big.fmt(amount)


func _on_rate_changed(resource_id: StringName, per_second: BigNumber) -> void:
	if resource_id != &"berry":
		return
	if Big.is_zero(per_second):
		_rate_label.text = ""
	else:
		# Keep decimals: "5 / sec" would lie about 5.5.
		_rate_label.text = "%s / sec" % Big.fmt(per_second, -1, false)


func _process(_delta: float) -> void:
	# Cheaper to poll once a frame than signal through every source.
	_on_rate_changed(&"berry", Game.rate_of(&"berry"))


func _on_offline_progress(seconds: float, gains: Dictionary) -> void:
	var mins := int(seconds / 60.0)
	var berry: BigNumber = gains.get(&"berry", Big.zero())
	print("Welcome back! Your bunnies gathered %s berries over %d minutes." % [Big.fmt(berry), mins])
