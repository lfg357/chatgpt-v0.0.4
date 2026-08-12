class_name M2Hud extends Control

@export var rig_path: NodePath
var rig: Node
@onready var hull: Label = $Hull
@onready var energy: Label = $Energy
@onready var heat: Label = $Heat
@onready var objective: Label = $Objective
@onready var tool: Label = $Tool
@onready var utility: Label = $Utility
@onready var extraction: Label = $Extraction
@onready var pause_panel: Panel = $PausePanel
@onready var resume: Button = $PausePanel/Resume
@onready var return_to_hub: Button = $PausePanel/ReturnToHub

func _ready() -> void:
	rig = get_node_or_null(rig_path)
	resume.pressed.connect(func(): if rig != null: rig.set_paused(false))
	return_to_hub.pressed.connect(func(): SceneRouter.go_to(3))

func _process(_delta: float) -> void:
	if rig == null: return
	var state = rig.state
	hull.text = "HULL  %03d" % state.durability
	energy.text = "ENERGY %03d" % state.energy
	heat.text = "HEAT %03d%s" % [state.heat, "  SHUTDOWN" if state.shutdown_seconds > 0.0 else ""]
	objective.text = "M2 GREYBOX\nDEPTH %03d" % int(rig.global_position.y)
	tool.text = "BLAST PIN  %d" % rig.tools.ammo
	utility.text = "SONAR %.1f  BEACON %d" % [rig.tools.sonar_cooldown, rig.tools.beacons.size()]
	extraction.text = "HOLD F: EXTRACT %.0f%%" % minf(100.0, rig.tools.recall_seconds / rig.tools.RECALL_SECONDS * 100.0)
	pause_panel.visible = rig.paused
