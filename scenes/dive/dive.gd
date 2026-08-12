extends Control

@onready var terrain_world = $TerrainWorld
@onready var drill_rig = $DrillRig
@onready var instruction: Label = $HudLayer/Instruction

func _ready() -> void:
	instruction.text = tr("dive.sandbox.instruction")
