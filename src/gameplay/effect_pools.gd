class_name EffectPools extends RefCounted

## M1's four effect families share the same bounded reusable-object behavior.
var debris := ObjectPool.new()
var dust := ObjectPool.new()
var sparks := ObjectPool.new()
var damage_numbers := ObjectPool.new()

func warm_all(per_pool: int = 50) -> void:
	debris.warm(per_pool)
	dust.warm(per_pool)
	sparks.warm(per_pool)
	damage_numbers.warm(per_pool)

func acquire(kind: StringName) -> Dictionary:
	return _pool_for(kind).acquire()

func release(kind: StringName, item: Dictionary) -> void:
	_pool_for(kind).release(item)

func _pool_for(kind: StringName) -> ObjectPool:
	match kind:
		&"debris": return debris
		&"dust": return dust
		&"sparks": return sparks
		&"damage_numbers": return damage_numbers
		_: push_error("Unknown effect pool: " + String(kind)); return debris
