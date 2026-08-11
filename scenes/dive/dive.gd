extends Control

const AppStateDefinition = preload("res://src/core/app_state.gd")

@onready var terrain_world = $TerrainWorld
@onready var title: Label = $Title
@onready var instruction: Label = $Instruction
@onready var status: Label = $Status
@onready var back_to_hub: Button = $BackToHub

func _ready() -> void:
	title.text = tr("dive.title")
	instruction.text = tr("dive.sandbox.instruction")
	back_to_hub.text = tr("dive.sandbox.back")
	back_to_hub.pressed.connect(func(): SceneRouter.go_to(AppStateDefinition.AppMode.HUB))
	_update_status()

func _process(_delta: float) -> void:
	_update_status()

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index != MOUSE_BUTTON_LEFT and event.button_index != MOUSE_BUTTON_RIGHT:
		return
	var local_point: Vector2 = terrain_world.to_local(event.position)
	var cell_size: int = terrain_world.cell_size
	var cell := Vector2i(floori(local_point.x / cell_size), floori(local_point.y / cell_size))
	if cell.x < 0 or cell.y < 0 or cell.x >= terrain_world.grid_size.x or cell.y >= terrain_world.grid_size.y:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		terrain_world.request_damage(cell)
	else:
		terrain_world.request_explosion(cell, 3)
	get_viewport().set_input_as_handled()
	_update_status()

func _update_status() -> void:
	var terrain: Variant = terrain_world.terrain
	var format := tr("dive.sandbox.status")
	if format == "dive.sandbox.status":
		format = "Queued: %d | Dirty chunks: %d | Collision rebuilds: %d"
	status.text = format % [terrain.pending_damage.size(), terrain.dirty_chunks.size(), terrain.total_rebuilds]
