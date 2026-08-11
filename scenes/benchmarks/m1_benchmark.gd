extends Node2D

const EffectPools = preload("res://src/gameplay/effect_pools.gd")
@onready var terrain: Node = $TerrainWorld
var frame_count := 0
var effects := EffectPools.new()

func _ready() -> void:
	# Fixed M1 load: 500 active greybox tiles, 200 pooled effect placeholders,
	# 20 environment markers, and 3 echo animation markers.
	for i in 500:
		terrain.call("restore_solid", Vector2i(i % 64, i / 64))
	effects.warm_all(50)
	for i in 20:
		var entity := Node2D.new()
		entity.name = "EnvironmentPlaceholder_%02d" % i
		add_child(entity)
	for i in 3:
		var echo := Node2D.new()
		echo.name = "EchoPlaceholder_%02d" % i
		add_child(echo)

func _physics_process(_delta: float) -> void:
	frame_count += 1
	if frame_count % 90 == 0:
		for i in 40:
			terrain.call("request_damage", Vector2i((frame_count + i * 7) % 64, (i * 3) % 32))
