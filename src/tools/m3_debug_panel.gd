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
	$Regenerate.pressed.connect(_regenerate)
	$Entry.pressed.connect(func(): controller.debug_teleport(&"entry"))
	$Supply.pressed.connect(func(): controller.debug_teleport(&"supply"))
	$Relic.pressed.connect(func(): controller.debug_teleport(&"relic"))
	$Core.pressed.connect(func(): controller.debug_teleport(&"core"))
	$Exit.pressed.connect(func(): controller.debug_teleport(&"exit"))
	$SelectedRoom.pressed.connect(_teleport_selected)
	$Routes.toggled.connect(func(value): controller.show_routes = value; controller.queue_redraw())
	$Anchors.toggled.connect(func(value): controller.show_anchors = value; controller.queue_redraw())
	$Budgets.toggled.connect(func(value): controller.show_budgets = value; controller.queue_redraw())
	$Chunks.toggled.connect(func(value): controller.show_chunks = value; controller.queue_redraw())
	$Export.pressed.connect(func(): $Export.text = "EXPORTED" if controller.debug_export() else "EXPORT FAILED")
	for layer in ["layer_industrial", "layer_bio", "layer_mech"]: $Layer.add_item(layer)
	if controller != null and controller.generated_map != null:
		$Seed.value = controller.generated_map.seed
		_refresh_rooms()
func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed and event.keycode == KEY_F10: visible = not visible
func _process(_delta: float) -> void:
	if not visible or controller == null or controller.generated_map == null: return
	var map = controller.generated_map; var report = preload("res://src/domain/map_validator.gd").new().validate(map)
	info.text = "M3 DEBUG\n%s seed=%d\nhash %s\nrooms=%d fallback=%s\nreachable=%d/%d\ndirty=%d pools=%d" % [map.layer_id, map.seed, map.topology_hash.substr(0, 12), map.room_instances.size(), map.used_fallback, report.reachable_required_nodes, report.required_nodes, controller.terrain.terrain.dirty_chunks.size(), controller.get_tree().get_node_count()]

func _regenerate() -> void:
	controller.debug_restart(StringName($Layer.get_item_text($Layer.selected)), int($Seed.value))
func _refresh_rooms() -> void:
	$Room.clear()
	for room in controller.generated_map.room_instances: $Room.add_item(String(room.module_id)); $Room.set_item_metadata($Room.item_count - 1, room.module_id)
func _teleport_selected() -> void:
	if $Room.item_count > 0: controller.debug_teleport($Room.get_item_metadata($Room.selected))
