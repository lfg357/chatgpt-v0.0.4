class_name RoomModuleDef extends ContentDef

@export var layer_id: StringName
@export var size_cells: Vector2i
@export var connectors: Array[StringName] = []
@export var tags: Array[StringName] = []
@export var risk: int = 0
@export var mineral_budget: int = 0
@export var hazard_budget: int = 0
@export var creature_budget: int = 0
@export var allow_mirror: bool = true
@export var allow_rotate: bool = false
