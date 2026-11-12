@tool
extends SceneTree

func _initialize() -> void:
	var editor := EditorInterface.get_editor_settings()
	var sdk := OS.get_environment("ANDROID_HOME")
	var java := OS.get_environment("JAVA_HOME")
	print("Configuring Android SDK: ", sdk)
	editor.set_setting("export/android/android_sdk_path", sdk)
	editor.set_setting("export/android/java_sdk_path", java)
	# EditorSettings persists changes automatically; no public save() method.
	quit()
