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
	return _generate_scene(document, state, path)


func load_scene_from_bytes(bytes: PackedByteArray, source_name: String) -> Node:
	if bytes.is_empty():
		_report_failure("The selected FBX '%s' is empty." % source_name)
		return null
	var document := FBXDocument.new()
	var state := FBXState.new()
	var error := document.append_from_buffer(bytes, "", state)
	if error != OK:
		_report_failure("Could not parse FBX '%s': %s" % [source_name, error_string(error)])
		return null
	return _generate_scene(document, state, source_name)


func _generate_scene(document: FBXDocument, state: FBXState, source_name: String) -> Node:
	var scene := document.generate_scene(state)
	if scene == null:
		_report_failure("Could not generate a scene from FBX '%s'." % source_name)
		return null
	return scene


func _report_failure(message: String) -> void:
	push_error(message)
	load_failed.emit(message)
