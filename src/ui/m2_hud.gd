class_name M2Hud extends Control

@export var rig_path: NodePath
var rig: Node
@onready var hull: Label = $VitalsPanel/Hull
@onready var energy: Label = $VitalsPanel/Energy
@onready var heat: Label = $HeatPanel/Heat
@onready var heat_fill: ColorRect = $HeatPanel/HeatFill
@onready var objective: Label = $ObjectivePanel/Objective
@onready var tool: Label = $ToolsPanel/Tool
@onready var utility: Label = $UtilityPanel/Utility
@onready var extraction: Label = $ExtractionPanel/Extraction
@onready var pause_panel: Panel = $PausePanel
@onready var resume: Button = $PausePanel/Resume
@onready var return_to_hub: Button = $PausePanel/ReturnToHub

func _ready() -> void:
	rig = get_node_or_null(rig_path)
	$PausePanel/PauseLabel.text = tr("m2.pause.title")
	resume.text = tr("m2.pause.resume")
	return_to_hub.text = tr("m2.pause.return_hub")
	resume.pressed.connect(func(): if rig != null: rig.set_paused(false))
	return_to_hub.pressed.connect(func(): SceneRouter.go_to(3))

func _process(_delta: float) -> void:
	if rig == null: return
	var state = rig.state
	hull.text = tr("m2.hud.hull") % state.durability
	energy.text = tr("m2.hud.energy") % state.energy
	heat.text = tr("m2.hud.heat") % [state.heat, tr("m2.hud.shutdown") if state.shutdown_seconds > 0.0 else ""]
	var heat_ratio := clampf(state.heat / 100.0, 0.0, 1.0)
	heat_fill.size.x = 160.0 * heat_ratio
	heat_fill.color = Color("dc5f58") if state.heat >= 85.0 else Color("e7ad52") if state.heat >= 70.0 else Color("49c3b1")
	objective.text = tr("m2.hud.objective") % int(rig.global_position.y)
	tool.text = tr("m2.hud.tool") % rig.tools.ammo
	utility.text = tr("m2.hud.utility") % [rig.tools.sonar_cooldown, rig.tools.beacons.size()]
	extraction.text = tr("m2.hud.extract") % minf(100.0, rig.tools.recall_seconds / rig.tools.RECALL_SECONDS * 100.0)
	pause_panel.visible = rig.paused
