class_name FbxSceneExporter
extends RefCounted

signal export_failed(message: String)


func save_scene(model: Node, path: String) -> bool:
	if not is_instance_valid(model):
		_report_failure("There is no loaded model to export.")
		return false

	var packed_scene := _pack_node(model, "loaded model")
	if packed_scene == null:
		return false
	return _save_packed_scene(packed_scene, path)


func save_subtree_scene(
	model: Node,
	path: String,
	object_name_mapping: Dictionary,
	bone_name_mapping: Dictionary
) -> bool:
	if not is_instance_valid(model):
		_report_failure("There is no selected object to export.")
		return false
	if not _validate_skeleton_references(model, model):
		return false

	var source_scene := _pack_node(model, "selected object")
	if source_scene == null:
		return false
	var export_root := source_scene.instantiate()
	if export_root == null:
		_report_failure("Could not create an export copy of the selected object.")
		return false
	if not _apply_name_mappings(export_root, object_name_mapping, bone_name_mapping):
		export_root.free()
		return false

	var packed_scene := _pack_node(export_root, "renamed object")
	export_root.free()
	if packed_scene == null:
		return false
	return _save_packed_scene(packed_scene, path)


func _pack_node(root: Node, description: String) -> PackedScene:
	var packed_scene := PackedScene.new()
	var previous_owners: Dictionary = {}
	_set_export_owners(root, root, previous_owners)
	var pack_error := packed_scene.pack(root)
	_restore_owners(previous_owners)
	if pack_error != OK:
		_report_failure("Could not pack the %s scene: %s" % [
			description,
			error_string(pack_error)
		])
		return null
	return packed_scene


func _save_packed_scene(packed_scene: PackedScene, path: String) -> bool:
	var save_error := ResourceSaver.save(
		packed_scene,
		path,
		ResourceSaver.FLAG_BUNDLE_RESOURCES
	)
	if save_error != OK:
		_report_failure("Could not save the exported scene to '%s': %s" % [
			path,
			error_string(save_error)
		])
		return false
	return true


func _validate_skeleton_references(export_root: Node, node: Node) -> bool:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		if not mesh.skeleton.is_empty():
			var skeleton_target := mesh.get_node_or_null(mesh.skeleton)
			if (
				skeleton_target != null
				and skeleton_target != export_root
				and not export_root.is_ancestor_of(skeleton_target)
			):
				_report_failure(
					"A mesh references a skeleton outside the selected object. "
					+ "Select their common parent object."
				)
				return false

	for child in node.get_children():
		if not _validate_skeleton_references(export_root, child):
			return false
	return true


func _apply_name_mappings(
	root: Node,
	object_name_mapping: Dictionary,
	bone_name_mapping: Dictionary
) -> bool:
	var nodes_by_key: Dictionary = {}
	_collect_nodes_by_key(root, ".", nodes_by_key)
	if not _validate_object_names(nodes_by_key, object_name_mapping):
		return false
	if not _validate_bone_names(nodes_by_key, bone_name_mapping):
		return false

	var node_keys_by_instance: Dictionary = {}
	for key in nodes_by_key:
		node_keys_by_instance[nodes_by_key[key]] = key
	var skeleton_targets_by_mesh: Dictionary = {}
	if not _get_skeleton_targets(
		nodes_by_key,
		node_keys_by_instance,
		skeleton_targets_by_mesh
	):
		return false
	var renamed_bones_by_skeleton := _get_bone_renames(
		nodes_by_key,
		bone_name_mapping
	)

	for key in nodes_by_key:
		var node := nodes_by_key[key] as Node
		node.name = StringName(object_name_mapping.get(key, String(node.name)).strip_edges())

	for mesh in skeleton_targets_by_mesh:
		var skeleton_target := skeleton_targets_by_mesh[mesh] as Node
		(mesh as MeshInstance3D).skeleton = _get_relative_node_path(
			mesh,
			skeleton_target,
			nodes_by_key,
			node_keys_by_instance
		)

	for key in nodes_by_key:
		var skeleton := nodes_by_key[key] as Skeleton3D
		if skeleton == null:
			continue
		var requested_names: Dictionary = bone_name_mapping.get(key, {})
		for bone_index in range(skeleton.get_bone_count()):
			var bone_name := String(requested_names.get(
				bone_index,
				skeleton.get_bone_name(bone_index)
			)).strip_edges()
			skeleton.set_bone_name(bone_index, bone_name)

	if not _update_skin_bind_names(
		skeleton_targets_by_mesh,
		node_keys_by_instance,
		renamed_bones_by_skeleton
	):
		return false
	return true


func _get_skeleton_targets(
	nodes_by_key: Dictionary,
	node_keys_by_instance: Dictionary,
	targets: Dictionary
) -> bool:
	for node in node_keys_by_instance:
		if not node is MeshInstance3D:
			continue
		var mesh := node as MeshInstance3D
		if mesh.skeleton.is_empty():
			continue
		var skeleton_target := mesh.get_node_or_null(mesh.skeleton)
		if skeleton_target == null:
			continue
		if not nodes_by_key.values().has(skeleton_target):
			_report_failure(
				"An exported mesh references a skeleton outside the selected object. "
				+ "Select their common parent object."
			)
			return false
		targets[mesh] = skeleton_target
	return true


func _get_bone_renames(
	nodes_by_key: Dictionary,
	bone_name_mapping: Dictionary
) -> Dictionary:
	var renames: Dictionary = {}
	for key in nodes_by_key:
		var skeleton := nodes_by_key[key] as Skeleton3D
		if skeleton == null:
			continue
		var requested_names: Dictionary = bone_name_mapping.get(key, {})
		var names_by_source: Dictionary = {}
		for bone_index in range(skeleton.get_bone_count()):
			var source_name := skeleton.get_bone_name(bone_index)
			var export_name := String(requested_names.get(
				bone_index,
				source_name
			)).strip_edges()
			if source_name != export_name:
				names_by_source[source_name] = export_name
		if not names_by_source.is_empty():
			renames[key] = names_by_source
	return renames


func _get_relative_node_path(
	from_node: Node,
	target_node: Node,
	nodes_by_key: Dictionary,
	node_keys_by_instance: Dictionary
) -> NodePath:
	var from_segments := _get_index_path_segments(
		String(node_keys_by_instance[from_node])
	)
	var target_segments := _get_index_path_segments(
		String(node_keys_by_instance[target_node])
	)
	var common_segment_count := 0
	while (
		common_segment_count < from_segments.size()
		and common_segment_count < target_segments.size()
		and from_segments[common_segment_count] == target_segments[common_segment_count]
	):
		common_segment_count += 1

	var path_segments: Array[String] = []
	for _index in range(from_segments.size() - common_segment_count):
		path_segments.append("..")

	var target_key := "."
	for index in range(target_segments.size()):
		target_key = target_segments[index] if target_key == "." else (
			"%s/%s" % [target_key, target_segments[index]]
		)
		if index >= common_segment_count:
			var target_part := nodes_by_key[target_key] as Node
			path_segments.append(String(target_part.name))

	if path_segments.is_empty():
		return NodePath(".")
	return NodePath("/".join(path_segments))


func _get_index_path_segments(key: String) -> PackedStringArray:
	if key == ".":
		return PackedStringArray()
	return key.split("/", false)


func _update_skin_bind_names(
	skeleton_targets_by_mesh: Dictionary,
	node_keys_by_instance: Dictionary,
	renamed_bones_by_skeleton: Dictionary
) -> bool:
	for mesh_node in skeleton_targets_by_mesh:
		var skeleton := skeleton_targets_by_mesh[mesh_node] as Skeleton3D
		if skeleton == null:
			continue
		var skeleton_key: String = node_keys_by_instance[skeleton]
		var bone_renames: Dictionary = renamed_bones_by_skeleton.get(skeleton_key, {})
		var source_skin := (mesh_node as MeshInstance3D).skin
		if source_skin == null or bone_renames.is_empty():
			continue

		var export_skin := source_skin.duplicate(true) as Skin
		if export_skin == null:
			_report_failure("Could not duplicate a mesh skin for bone renaming.")
			return false
		for bind_index in range(export_skin.get_bind_count()):
			var bind_name := String(export_skin.get_bind_name(bind_index))
			if bone_renames.has(bind_name):
				export_skin.set_bind_name(
					bind_index,
					StringName(bone_renames[bind_name])
				)
		(mesh_node as MeshInstance3D).skin = export_skin
	return true


func _collect_nodes_by_key(node: Node, key: String, nodes_by_key: Dictionary) -> void:
	nodes_by_key[key] = node
	for child_index in range(node.get_child_count()):
		var child_key := str(child_index) if key == "." else "%s/%d" % [key, child_index]
		_collect_nodes_by_key(node.get_child(child_index), child_key, nodes_by_key)


func _validate_object_names(
	nodes_by_key: Dictionary,
	object_name_mapping: Dictionary
) -> bool:
	var names_by_parent: Dictionary = {}
	for key in nodes_by_key:
		var node := nodes_by_key[key] as Node
		var object_name := String(
			object_name_mapping.get(key, String(node.name))
		).strip_edges()
		if object_name.is_empty():
			_report_failure("Object names cannot be empty.")
			return false
		if (
			object_name != String(node.name)
			and object_name.validate_node_name() != object_name
		):
			_report_failure("Invalid object name: '%s'." % object_name)
			return false

		var parent_key := _get_parent_key(key)
		var sibling_names: Dictionary = names_by_parent.get(parent_key, {})
		if sibling_names.has(object_name):
			_report_failure("Duplicate object name '%s' under the same parent." % object_name)
			return false
		sibling_names[object_name] = true
		names_by_parent[parent_key] = sibling_names
	return true


func _validate_bone_names(
	nodes_by_key: Dictionary,
	bone_name_mapping: Dictionary
) -> bool:
	for key in nodes_by_key:
		var skeleton := nodes_by_key[key] as Skeleton3D
		if skeleton == null:
			continue
		var requested_names: Dictionary = bone_name_mapping.get(key, {})
		var used_names: Dictionary = {}
		for bone_index in range(skeleton.get_bone_count()):
			var bone_name := String(requested_names.get(
				bone_index,
				skeleton.get_bone_name(bone_index)
			)).strip_edges()
			if bone_name.is_empty():
				_report_failure("Bone names cannot be empty.")
				return false
			if used_names.has(bone_name):
				_report_failure("Duplicate bone name '%s' in skeleton '%s'." % [
					bone_name,
					skeleton.name
				])
				return false
			used_names[bone_name] = true
	return true


func _get_parent_key(key: String) -> String:
	if key == ".":
		return ""
	var separator_index := key.rfind("/")
	return "." if separator_index < 0 else key.substr(0, separator_index)


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
