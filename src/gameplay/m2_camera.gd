class_name M2Camera extends Camera2D

@export var map_bounds := Rect2(0, 0, 512, 208)
@export var shake_percent := 70.0
var trauma := 0.0
var _shake_time := 0.0

func update_target(rig_position: Vector2, aim: Vector2, movement: Vector2, delta: float) -> void:
	var target := rig_position + aim.normalized() * 48.0 + movement.normalized() * 16.0
	var viewport_size := get_viewport_rect().size
	if map_bounds.size.x <= viewport_size.x: target.x = map_bounds.get_center().x
	else: target.x = clampf(target.x, map_bounds.position.x + viewport_size.x * .5, map_bounds.end.x - viewport_size.x * .5)
	if map_bounds.size.y <= viewport_size.y: target.y = map_bounds.get_center().y
	else: target.y = clampf(target.y, map_bounds.position.y + viewport_size.y * .5, map_bounds.end.y - viewport_size.y * .5)
	global_position = global_position.lerp(target, minf(1.0, delta * 8.0))
	trauma = maxf(0.0, trauma - delta * 1.8)
	_shake_time += delta
	offset = shake_offset()
	rotation = deg_to_rad(sin(_shake_time * 43.0) * trauma * 0.5 * shake_percent / 100.0)

func add_trauma(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)

func shake_offset() -> Vector2:
	if shake_percent <= 0.0: return Vector2.ZERO
	var amount := trauma * 6.0 * shake_percent / 100.0
	return Vector2(sin(_shake_time * 37.0) * amount, cos(_shake_time * 53.0) * amount)
