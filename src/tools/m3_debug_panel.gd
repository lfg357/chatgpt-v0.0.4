class_name M3DebugPanel extends Panel

@export var controller_path: NodePath
var controller: Node
@onready var info: Label = $Info
func _ready() -> void:
	controller = get_node_or_null(controller_path); visible = false
	$Success.pressed.connect(func(): controller.request_extract())
	$Destroy.pressed.connect(func(): controller._damage(999, &"debug"))
	$Abandon.pressed.connect(func(): controller.request_abandon())
	$Timeout.pressed.connect(func(): controller.force_boiler_timeout())
func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed and event.keycode == KEY_F10: visible = not visible
func _process(_delta: float) -> void:
	if not visible or controller == null or controller.generated_map == null: return
	var map = controller.generated_map; var report = preload("res://src/domain/map_validator.gd").new().validate(map)
	info.text = "M3 DEBUG\n%s seed=%d\nhash %s\nrooms=%d fallback=%s\nreachable=%d/%d\ndirty=%d pools=%d" % [map.layer_id, map.seed, map.topology_hash.substr(0, 12), map.room_instances.size(), map.used_fallback, report.reachable_required_nodes, report.required_nodes, controller.terrain.terrain.dirty_chunks.size(), controller.get_tree().get_node_count()]
