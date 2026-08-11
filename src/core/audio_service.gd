extends Node
const AppSettingsValue = preload("res://src/core/app_settings.gd")

func apply_settings(settings: AppSettingsValue) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(float(settings.audio.get("master", 80)) / 100.0))
