extends Control

@onready var terrain_world = $TerrainWorld
@onready var drill_rig = $DrillRig
@onready var title: Label = $Title
@onready var instruction: Label = $Instruction

func _ready() -> void:
	title.text = tr("dive.title")
	instruction.text = tr("dive.sandbox.instruction")
