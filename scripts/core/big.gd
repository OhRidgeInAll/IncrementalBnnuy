## Safe wrapper over the `big_number` addon. The raw type folds mantissas,
## strips negatives, and returns abs value on underflow -- so build, copy, and
## mutate only through here.
class_name Big
extends RefCounted

## Display styles for `fmt()`.
enum Format {
	SHORT_SCALE,   ## 1.23 thousand, 4.56 million
	AA,            ## 1.23k, 4.56m, 7.89aa
	METRIC,        ## 1.23k, 4.56M, 7.89G
	SCIENTIFIC,    ## 1.23e45
}

## Style used by `fmt()` when no explicit style is passed.
static var default_format: Format = Format.SHORT_SCALE


## Builds a BigNumber from already-normalized parts.
static func _raw(mantissa: float, exponent: int) -> BigNumber:
	var b := BigNumber.new()
	b.mantissa = mantissa
	b.exponent = exponent
	return b


static func zero() -> BigNumber:
	return _raw(0.0, 0)


static func one() -> BigNumber:
	return _raw(1.0, 0)


## Float -> BigNumber. Non-positive or non-finite values collapse to zero.
static func from_float(v: float) -> BigNumber:
	if not is_finite(v) or v <= 0.0:
		return zero()
	var e := int(floor(log(v) / log(10.0)))
	var m := v / pow(10.0, e)
	# Fix mantissa drift from log rounding so the setter doesn't eat a decade.
	while m >= 10.0:
		m /= 10.0
		e += 1
	while m < 1.0 and m > 0.0:
		m *= 10.0
		e -= 1
	return _raw(m, e)


## Rebuilds a BigNumber from (mantissa, exponent), re-normalizing defensively.
static func from_parts(mantissa: float, exponent: int) -> BigNumber:
	if not is_finite(mantissa) or mantissa <= 0.0:
		return zero()
	var m := absf(mantissa)
	var e := exponent
	while m >= 10.0:
		m /= 10.0
		e += 1
	while m < 1.0:
		m *= 10.0
		e -= 1
	return _raw(m, e)


## Accepts a float, int or BigNumber and returns an owned BigNumber.
static func coerce(v: Variant) -> BigNumber:
	if v is BigNumber:
		return copy(v)
	if v is float or v is int:
		return from_float(float(v))
	push_error("Big.coerce: unsupported type %s" % typeof(v))
	return zero()


## Defensive copy, and the chokepoint that keeps every value normalized.
##
## Addon arithmetic can return un-normalized results: `0 + 1e3` comes back as
## mantissa 10.0, exponent 2. to_float() reports 1000, so it looks fine until
## something copies it -- the setter folds 10.0 to 1.0 without touching the
## exponent and the value silently becomes 100. Normalizing here stops any such
## value escaping Big, so a balance cannot lose a decade just by being read.
static func copy(n: BigNumber) -> BigNumber:
	if n == null:
		return zero()
	return from_parts(n.mantissa, n.exponent)


static func is_zero(n: BigNumber) -> bool:
	return n == null or n.mantissa <= 0.0


## a + b, without mutating either operand. Every result is routed through
## `copy()` so it comes back normalized -- see the note there.
static func add(a: BigNumber, b: Variant) -> BigNumber:
	return copy(a.plus(coerce(b)))


## a - b, clamped at zero (raw minus gives abs value on underflow).
static func sub(a: BigNumber, b: Variant) -> BigNumber:
	var rhs := coerce(b)
	if not gte(a, rhs):
		return zero()
	return copy(a.minus(rhs))


static func mul(a: BigNumber, b: Variant) -> BigNumber:
	return copy(a.multiply(coerce(b)))


static func div(a: BigNumber, b: Variant) -> BigNumber:
	var rhs := coerce(b)
	if is_zero(rhs):
		push_error("Big.div: division by zero")
		return zero()
	return copy(a.divide(rhs))


static func pow_big(a: BigNumber, exp: float) -> BigNumber:
	return copy(a.power(exp))


static func gte(a: BigNumber, b: Variant) -> bool:
	return a.is_greater_than_or_equal_to(coerce(b))


static func gt(a: BigNumber, b: Variant) -> bool:
	return a.is_greater_than(coerce(b))


static func lt(a: BigNumber, b: Variant) -> bool:
	return a.is_less_than(coerce(b))


static func eq(a: BigNumber, b: Variant) -> bool:
	return a.is_equal_to(coerce(b))


## HUD text. `compact` drops decimals under a thousand ("7 berries") but lies
## about rates -- pass false where the fractional part matters.
static func fmt(n: BigNumber, style: int = -1, compact: bool = true) -> String:
	if n == null:
		return "0"
	var s: Format = default_format if style < 0 else style as Format
	match s:
		Format.AA:
			return n.to_aa(compact, true, false)
		Format.METRIC:
			return n.to_metric_symbol(compact)
		Format.SCIENTIFIC:
			return n.to_scientific(compact, false)
		_:
			return _space_suffix(n.to_short_scale(compact))


## Addon writes "1.50thousand"; insert the missing space.
static func _space_suffix(text: String) -> String:
	var re := RegEx.new()
	re.compile("^([0-9.,]+)([A-Za-z].*)$")
	var m := re.search(text)
	if m == null:
		return text
	return "%s %s" % [m.get_string(1), m.get_string(2)]


## Serializes without going through float, so values beyond 1e308 survive.
## Normalizes first -- saving a raw mantissa of 10.0 would reload as a tenth.
static func to_save(n: BigNumber) -> Dictionary:
	if n == null:
		return {"m": 0.0, "e": 0}
	var c := copy(n)
	return {"m": c.mantissa, "e": c.exponent}


static func from_save(d: Variant) -> BigNumber:
	if d is Dictionary and d.has("m") and d.has("e"):
		return from_parts(float(d["m"]), int(d["e"]))
	return zero()
