class_name LayerDef extends ContentDef

@export var first_seed: int
@export var entry_room_id: StringName
@export var normal_room_ids: Array[StringName] = []
@export var risk_room_ids: Array[StringName] = []
@export var supply_room_id: StringName
@export var relic_room_id: StringName
@export var core_room_id: StringName
@export var min_main_nodes: int = 6
@export var max_main_nodes: int = 10
@export var min_risk_branches: int = 0
@export var max_risk_branches: int = 3
@export var extra_relic_rooms: int = 0
