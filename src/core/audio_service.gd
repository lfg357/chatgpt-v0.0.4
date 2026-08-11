extends Node
func apply_settings(settings: AppSettings) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(float(settings.audio.get("master", 80)) / 100.0))
