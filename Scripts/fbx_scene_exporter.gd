class_name FbxSceneExporter
extends RefCounted

signal export_failed(message: String)


func save_scene(model: Node, path: String) -> bool:
	if not is_instance_valid(model):
		_report_failure("There is no loaded model to export.")
		return false

	var packed_scene := PackedScene.new()
	var previous_owners: Dictionary = {}
	_set_export_owners(model, model, previous_owners)
	var pack_error := packed_scene.pack(model)
	_restore_owners(previous_owners)
	if pack_error != OK:
		_report_failure("Could not pack the loaded model scene: %s" % error_string(pack_error))
		return false

	var save_error := ResourceSaver.save(
		packed_scene,
		path,
		ResourceSaver.FLAG_BUNDLE_RESOURCES
	)
	if save_error != OK:
		_report_failure("Could not export the loaded model to '%s': %s" % [
			path,
			error_string(save_error)
		])
		return false
	return true


func _set_export_owners(node: Node, root: Node, previous_owners: Dictionary) -> void:
	for child in node.get_children():
		previous_owners[child] = child.owner
		child.owner = root
		_set_export_owners(child, root, previous_owners)


func _restore_owners(previous_owners: Dictionary) -> void:
	for node in previous_owners:
		node.owner = previous_owners[node]


func _report_failure(message: String) -> void:
	push_error(message)
	export_failed.emit(message)
