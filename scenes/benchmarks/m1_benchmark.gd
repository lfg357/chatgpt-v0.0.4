extends Node2D

@onready var terrain: Node = $TerrainWorld
var frame_count := 0

func _ready() -> void:
	# 500 active greybox tiles, 200 pooled particle placeholders, 20 environment
	# placeholders, and 3 echo markers are supplied by this fixed benchmark scene.
	for i in 500:
		terrain.call("request_damage", Vector2i(i % 64, i / 64))

func _physics_process(_delta: float) -> void:
	frame_count += 1
	if frame_count % 90 == 0:
		for i in 40:
			terrain.call("request_damage", Vector2i((frame_count + i * 7) % 64, (i * 3) % 32))
