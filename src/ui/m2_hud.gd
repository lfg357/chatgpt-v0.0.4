class_name M2Hud extends Control

@export var rig_path: NodePath
var rig: Node
var controller: Node
var abandon_armed := false
@onready var hull: Label = $BottomFrame/VitalsPanel/Hull
@onready var energy: Label = $BottomFrame/VitalsPanel/Energy
@onready var heat: Label = $BottomFrame/HeatPanel/Heat
@onready var heat_fill: ColorRect = $BottomFrame/HeatPanel/HeatFill
@onready var objective: Label = $BottomFrame/ObjectivePanel/Objective
@onready var tool: Label = $BottomFrame/ToolsPanel/Tool
@onready var utility: Label = $BottomFrame/UtilityPanel/Utility
@onready var extraction: Label = $BottomFrame/ExtractionPanel/Extraction
@onready var input_prompt: Control = $InputPrompt
@onready var pause_panel: Panel = $PausePanel
@onready var resume: Button = $PausePanel/Resume
@onready var return_to_hub: Button = $PausePanel/ReturnToHub
@onready var dive_status: Label = $DiveStatus
@onready var danger: Label = $Danger

func _ready() -> void:
	rig = get_node_or_null(rig_path)
	controller = rig.get_node_or_null("../M3DiveController") if rig != null else null
	$PausePanel/PauseLabel.text = tr("m2.pause.title")
	resume.text = tr("m2.pause.resume")
	return_to_hub.text = tr("m2.pause.return_hub")
	resume.pressed.connect(_on_resume_pressed)
	return_to_hub.pressed.connect(_on_abandon_pressed)
	# Keep the prompt in sync immediately; later swaps arrive through its signal.
	input_prompt.set_device_family(InputService.device_family)

func _process(_delta: float) -> void:
	if rig == null: return
	var state = rig.state
	hull.text = tr("m2.hud.hull") % state.durability
	energy.text = tr("m2.hud.energy") % state.energy
	heat.text = tr("m2.hud.heat") % [state.heat, tr("m2.hud.shutdown") if state.shutdown_seconds > 0.0 else ""]
	var heat_ratio := clampf(state.heat / 100.0, 0.0, 1.0)
	heat_fill.size.x = 116.0 * heat_ratio
	heat_fill.color = Color("dc5f58") if state.heat >= 85.0 else Color("e7ad52") if state.heat >= 70.0 else Color("49c3b1")
	if controller != null:
		var run = controller.run
		objective.text = (tr("m3.hud.objective") % [run.cargo_used, run.CARGO_CAPACITY, run.combo_multiplier(), run.combo_remaining]).replace("\\n", "\n")
		var valves_done: int = int(run.boiler.valves.count(true))
		dive_status.text = tr("m3.hud.status") % [controller.current_depth_cells(), String(controller.current_room_id()), run.boiler.remaining if run.boiler.active else 0.0, valves_done]
		var warning: StringName = controller.current_warning()
		danger.text = tr("m3.warning.%s" % String(warning)) if warning != &"" else ""
	else: objective.text = (tr("m2.hud.objective") % int(rig.global_position.y)).replace("\\n", "\n")
	tool.text = tr("m2.hud.tool") % rig.tools.ammo
	utility.text = tr("m2.hud.utility") % [rig.tools.sonar_cooldown, rig.tools.beacon_ammo]
	extraction.text = (tr("m3.hud.extract") % [controller.extraction_direction(), minf(100.0, rig.tools.recall_seconds / rig.tools.RECALL_SECONDS * 100.0)]) if controller != null else tr("m2.hud.extract") % minf(100.0, rig.tools.recall_seconds / rig.tools.RECALL_SECONDS * 100.0)
	pause_panel.visible = rig.paused

func _on_abandon_pressed() -> void:
	if controller == null: return
	if not abandon_armed:
		abandon_armed = true; return_to_hub.text = tr("m3.pause.confirm_abandon")
		return
	controller.request_abandon()

func _on_resume_pressed() -> void:
	abandon_armed = false; return_to_hub.text = tr("m2.pause.return_hub")
	if rig != null: rig.set_paused(false)
