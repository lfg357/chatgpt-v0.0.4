extends TestCase
const ContentDBScript = preload("res://src/core/content_db.gd")

func test_csv_localization_registers_runtime_translations() -> bool:
	var db := ContentDBScript.new()
	db.load_all()
	TranslationServer.set_locale("en")
	assert_equal(TranslationServer.translate("menu.title"), "Time Strata Drill Bureau")
	TranslationServer.set_locale("zh_CN")
	assert_equal(TranslationServer.translate("menu.title"), "时层钻探局")
	db.free()
	return true
