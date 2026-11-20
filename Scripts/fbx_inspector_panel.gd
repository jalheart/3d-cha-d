class_name FbxInspectorPanel
extends Control

var _tree: Tree


func setup(parent: TabContainer) -> void:
	name = "FBX Inspector"
	parent.add_child(self)
	_tree = Tree.new()
	_tree.columns = 2
	_tree.column_titles_visible = false
	_tree.set_column_expand(0, false)
	_tree.set_column_custom_minimum_width(0, 100)
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_tree)
	show_empty()


func show_empty() -> void:
	_tree.clear()
	_tree.hide_root = true
	_tree.create_item()
	var section := _add_section("FBX")
	_add_property(section, "Status", "Load a file to inspect it")


func inspect_model(model: Node, path: String, animation_count: int) -> void:
	var properties := {
		"node_count": 0,
		"mesh_count": 0,
		"scales": [],
		"materials": {},
		"textures": {}
	}
	_collect_properties(model, properties)

	_tree.clear()
	_tree.hide_root = true
	_tree.create_item()

	var file_section := _add_section("File")
	_add_property(file_section, "Name", path.get_file())
	_add_property(file_section, "Path", path)

	var scene_section := _add_section("Scene")
	if model is Node3D:
		_add_property(scene_section, "Root scale", _format_vector3((model as Node3D).scale))
	else:
		_add_property(scene_section, "Root scale", "Unavailable")
	_add_property(scene_section, "Nodes", str(properties["node_count"]))
	_add_property(scene_section, "Meshes", str(properties["mesh_count"]))
	_add_property(scene_section, "Animations", str(animation_count))

	var scale_section := _add_section("Node Scales")
	for scale_info in properties["scales"]:
		_add_property(scale_section, scale_info["name"], scale_info["value"])
	if properties["scales"].is_empty():
		_add_property(scale_section, "Scaled nodes", "None")

	var material_section := _add_section("Materials")
	_add_property(material_section, "Count", str(properties["materials"].size()))
	for material_name in properties["materials"].values():
		_add_property(material_section, "Material", material_name)

	var texture_section := _add_section("Textures")
	_add_property(texture_section, "Count", str(properties["textures"].size()))
	for texture_name in properties["textures"].values():
		_add_property(texture_section, "Texture", texture_name)


func _collect_properties(node: Node, properties: Dictionary) -> void:
	properties["node_count"] += 1
	if node is Node3D:
		var node_3d := node as Node3D
		if node_3d.scale.distance_to(Vector3.ONE) > 0.001:
			properties["scales"].append(
				{
					"name": node_3d.name,
					"value": _format_vector3(node_3d.scale)
				}
			)

	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			properties["mesh_count"] += 1
			for surface_index in range(mesh_instance.mesh.get_surface_count()):
				var material := mesh_instance.get_active_material(surface_index)
				if material == null:
					continue
				_add_resource(properties["materials"], material)
				for property in material.get_property_list():
					var value: Variant = material.get(property["name"])
					if value is Texture2D:
						_add_resource(properties["textures"], value)

	for child in node.get_children():
		_collect_properties(child, properties)


func _add_resource(resources: Dictionary, resource: Resource) -> void:
	var resource_id := resource.get_instance_id()
	if resources.has(resource_id):
		return

	var resource_name := resource.resource_name
	if resource_name.is_empty():
		resource_name = resource.resource_path.get_file()
	if resource_name.is_empty():
		resource_name = resource.get_class()
	if resource is Texture2D:
		resource_name += " (%d x %d)" % [resource.get_width(), resource.get_height()]
	resources[resource_id] = resource_name


func _add_section(title: String) -> TreeItem:
	var section := _tree.create_item(_tree.get_root())
	section.set_text(0, title)
	section.set_selectable(0, false)
	section.set_selectable(1, false)
	return section


func _add_property(parent: TreeItem, property_name: String, value: String) -> void:
	var item := _tree.create_item(parent)
	item.set_text(0, property_name)
	item.set_text(1, value)
	item.set_tooltip_text(0, property_name)
	item.set_tooltip_text(1, value)


func _format_vector3(value: Vector3) -> String:
	return "(%.3f, %.3f, %.3f)" % [value.x, value.y, value.z]
