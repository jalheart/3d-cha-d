class_name FbxSceneLoader
extends RefCounted

signal load_failed(message: String)


func load_scene(path: String) -> Node:
	var document := FBXDocument.new()
	var state := FBXState.new()
	var error := document.append_from_file(path, state)
	if error != OK:
		_report_failure("Could not parse FBX '%s': %s" % [path, error_string(error)])
		return null

	var scene := document.generate_scene(state)
	if scene == null:
		_report_failure("Could not generate a scene from FBX '%s'." % path)
		return null
	return scene


func _report_failure(message: String) -> void:
	push_error(message)
	load_failed.emit(message)
