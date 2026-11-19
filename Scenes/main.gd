extends Node3D

@onready var camera: Camera3D = $Camera3D
@onready var character: Node3D = $Character

@export var orbit_sensitivity := 0.005
@export var pan_sensitivity := 0.005
@export var zoom_sensitivity := 0.25
@export var min_zoom := 0.8
@export var max_zoom := 12.0

var target: Vector3
var yaw := 0.0
var pitch := 0.0
var distance := 2.3
var fbx_file_dialog: FileDialog
var error_dialog: AcceptDialog
var ui_workspace: Control
var fbx_properties_panel: PanelContainer
var animation_editor_panel: PanelContainer
var dock_panel_contents: Dictionary = {}
var dock_panel_minimize_buttons: Dictionary = {}
var dock_panel_expanded_heights: Dictionary = {}
var dragged_dock_panel: Control
var dock_drag_offset := Vector2.ZERO
var fbx_properties_tree: Tree
var animation_selector: OptionButton
var animation_edit_button: Button
var animation_play_button: Button
var animation_stop_button: Button
var animation_list: ItemList
var animation_name_edit: LineEdit
var animation_loop_selector: OptionButton
var animation_speed_spin_box: SpinBox
var animation_details_label: Label
var animation_editor_error_dialog: AcceptDialog
var animation_clips: Array = []
var selected_animation_index := -1
var active_animation_player: AnimationPlayer
var loaded_fbx_model: Node
var loaded_fbx_path := ""


func _ready() -> void:
	_create_file_menu()

	target = character.global_position
	target.y += 0.1

	var offset := camera.global_position - target
	distance = clampf(offset.length(), min_zoom, max_zoom)
	yaw = atan2(offset.x, offset.z)
	pitch = asin(clampf(offset.normalized().y, -1.0, 1.0))
	_update_camera()


func _create_file_menu() -> void:
	var ui_layer := CanvasLayer.new()
	add_child(ui_layer)

	ui_workspace = Control.new()
	ui_workspace.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(ui_workspace)

	var menu_bar := MenuBar.new()
	ui_layer.add_child(menu_bar)

	var viewport_size := get_viewport().get_visible_rect().size
	var inspector_panel_data := _create_dock_panel(
		"FBX Inspector",
		Vector2(maxf(12.0, viewport_size.x - 332.0), 52.0),
		Vector2(320.0, maxf(240.0, viewport_size.y - 64.0))
	)
	fbx_properties_panel = inspector_panel_data["panel"]
	var inspector_layout: VBoxContainer = inspector_panel_data["content"]

	fbx_properties_tree = Tree.new()
	fbx_properties_tree.columns = 2
	fbx_properties_tree.column_titles_visible = false
	fbx_properties_tree.set_column_expand(0, false)
	fbx_properties_tree.set_column_custom_minimum_width(0, 100)
	fbx_properties_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fbx_properties_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector_layout.add_child(fbx_properties_tree)

	var animation_controls := HBoxContainer.new()
	inspector_layout.add_child(animation_controls)

	animation_selector = OptionButton.new()
	animation_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	animation_selector.item_selected.connect(_on_animation_selector_selected)
	animation_controls.add_child(animation_selector)

	animation_edit_button = Button.new()
	animation_edit_button.text = "Edit"
	animation_edit_button.pressed.connect(_edit_selected_animation)
	animation_controls.add_child(animation_edit_button)

	animation_play_button = Button.new()
	animation_play_button.text = "Play"
	animation_play_button.pressed.connect(_play_selected_animation)
	animation_controls.add_child(animation_play_button)

	animation_stop_button = Button.new()
	animation_stop_button.text = "Stop"
	animation_stop_button.disabled = true
	animation_stop_button.pressed.connect(_stop_current_animation)
	animation_controls.add_child(animation_stop_button)

	_create_animation_editor_panel(viewport_size)
	_show_empty_fbx_properties()

	var file_menu_button := MenuButton.new()
	file_menu_button.text = "File"
	menu_bar.add_child(file_menu_button)

	var file_menu := file_menu_button.get_popup()
	file_menu.add_item("Load .fbx", 0)
	file_menu.id_pressed.connect(_on_file_menu_item_pressed)
	menu_bar.position = Vector2(8.0, 8.0)
	menu_bar.size = menu_bar.get_combined_minimum_size()

	fbx_file_dialog = FileDialog.new()
	fbx_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fbx_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	fbx_file_dialog.add_filter("*.fbx,*.FBX ; FBX files")
	fbx_file_dialog.file_selected.connect(_load_fbx)
	add_child(fbx_file_dialog)

	error_dialog = AcceptDialog.new()
	add_child(error_dialog)


func _on_file_menu_item_pressed(id: int) -> void:
	if id == 0:
		fbx_file_dialog.popup_centered_ratio()


func _create_dock_panel(title: String, panel_position: Vector2, panel_size: Vector2) -> Dictionary:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.position = panel_position
	panel.size = panel_size
	panel.custom_minimum_size = Vector2(260.0, 40.0)
	ui_workspace.add_child(panel)

	var panel_layout := VBoxContainer.new()
	panel.add_child(panel_layout)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 28.0
	panel_layout.add_child(header)

	var title_label := Label.new()
	title_label.text = title
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.mouse_filter = Control.MOUSE_FILTER_STOP
	title_label.tooltip_text = "Drag to move or dock this panel"
	title_label.mouse_default_cursor_shape = Control.CURSOR_MOVE
	title_label.gui_input.connect(_on_dock_panel_header_input.bind(panel))
	header.add_child(title_label)

	var minimize_button := Button.new()
	minimize_button.text = "-"
	minimize_button.tooltip_text = "Minimize panel"
	minimize_button.pressed.connect(_toggle_dock_panel_minimized.bind(panel))
	header.add_child(minimize_button)

	var content := VBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_layout.add_child(content)

	dock_panel_contents[panel] = content
	dock_panel_minimize_buttons[panel] = minimize_button
	dock_panel_expanded_heights[panel] = panel_size.y
	return {"panel": panel, "content": content}


func _toggle_dock_panel_minimized(panel: Control) -> void:
	var content: Control = dock_panel_contents[panel]
	var minimize_button: Button = dock_panel_minimize_buttons[panel]
	if content.visible:
		dock_panel_expanded_heights[panel] = panel.size.y
		content.hide()
		panel.size.y = 40.0
		minimize_button.text = "+"
		minimize_button.tooltip_text = "Restore panel"
	else:
		content.show()
		panel.size.y = dock_panel_expanded_heights[panel]
		minimize_button.text = "-"
		minimize_button.tooltip_text = "Minimize panel"


func _on_dock_panel_header_input(event: InputEvent, panel: Control) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			var mouse_position := (
				ui_workspace.get_global_transform_with_canvas().affine_inverse()
				* mouse_event.global_position
			)
			dragged_dock_panel = panel
			dock_drag_offset = mouse_position - panel.position
			panel.move_to_front()
			get_viewport().set_input_as_handled()


func _dock_panel_to_nearest_edge(panel: Control) -> void:
	var viewport_size := ui_workspace.size
	var snap_distance := 24.0
	var snapped_to_panel := false
	for other_panel in [fbx_properties_panel, animation_editor_panel]:
		if other_panel == null or other_panel == panel or not other_panel.visible:
			continue
		var vertical_overlap: bool = (
			panel.position.y < other_panel.position.y + other_panel.size.y
			and panel.position.y + panel.size.y > other_panel.position.y
		)
		var horizontal_overlap: bool = (
			panel.position.x < other_panel.position.x + other_panel.size.x
			and panel.position.x + panel.size.x > other_panel.position.x
		)
		if vertical_overlap and absf(panel.position.x + panel.size.x - other_panel.position.x) < snap_distance:
			panel.position.x = other_panel.position.x - panel.size.x
			snapped_to_panel = true
			break
		if vertical_overlap and absf(panel.position.x - other_panel.position.x - other_panel.size.x) < snap_distance:
			panel.position.x = other_panel.position.x + other_panel.size.x
			snapped_to_panel = true
			break
		if horizontal_overlap and absf(panel.position.y + panel.size.y - other_panel.position.y) < snap_distance:
			panel.position.y = other_panel.position.y - panel.size.y
			snapped_to_panel = true
			break
		if horizontal_overlap and absf(panel.position.y - other_panel.position.y - other_panel.size.y) < snap_distance:
			panel.position.y = other_panel.position.y + other_panel.size.y
			snapped_to_panel = true
			break

	if not snapped_to_panel:
		if absf(panel.position.x - 12.0) < snap_distance:
			panel.position.x = 12.0
		elif absf(panel.position.x + panel.size.x - viewport_size.x + 12.0) < snap_distance:
			panel.position.x = viewport_size.x - panel.size.x - 12.0
		if absf(panel.position.y - 12.0) < snap_distance:
			panel.position.y = 12.0
		elif absf(panel.position.y + panel.size.y - viewport_size.y + 12.0) < snap_distance:
			panel.position.y = viewport_size.y - panel.size.y - 12.0

	panel.position.x = clampf(panel.position.x, 0.0, maxf(0.0, viewport_size.x - panel.size.x))
	panel.position.y = clampf(panel.position.y, 0.0, maxf(0.0, viewport_size.y - panel.size.y))


func _create_animation_editor_panel(viewport_size: Vector2) -> void:
	var panel_data := _create_dock_panel(
		"Animation Editor",
		Vector2(maxf(12.0, viewport_size.x - 704.0), 68.0),
		Vector2(360.0, 420.0)
	)
	animation_editor_panel = panel_data["panel"]
	var layout: VBoxContainer = panel_data["content"]

	var note := Label.new()
	note.text = "Changes apply to the currently loaded model."
	layout.add_child(note)

	animation_list = ItemList.new()
	animation_list.custom_minimum_size.y = 140.0
	animation_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	animation_list.item_selected.connect(_on_animation_list_item_selected)
	layout.add_child(animation_list)

	var name_row := HBoxContainer.new()
	layout.add_child(name_row)
	var name_label := Label.new()
	name_label.text = "Name"
	name_label.custom_minimum_size.x = 80.0
	name_row.add_child(name_label)
	animation_name_edit = LineEdit.new()
	animation_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(animation_name_edit)

	var loop_row := HBoxContainer.new()
	layout.add_child(loop_row)
	var loop_label := Label.new()
	loop_label.text = "Loop mode"
	loop_label.custom_minimum_size.x = 80.0
	loop_row.add_child(loop_label)
	animation_loop_selector = OptionButton.new()
	animation_loop_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	animation_loop_selector.add_item("None")
	animation_loop_selector.add_item("Linear")
	animation_loop_selector.add_item("Ping-pong")
	loop_row.add_child(animation_loop_selector)

	var speed_row := HBoxContainer.new()
	layout.add_child(speed_row)
	var speed_label := Label.new()
	speed_label.text = "Play speed"
	speed_label.custom_minimum_size.x = 80.0
	speed_row.add_child(speed_label)
	animation_speed_spin_box = SpinBox.new()
	animation_speed_spin_box.min_value = 0.1
	animation_speed_spin_box.max_value = 4.0
	animation_speed_spin_box.step = 0.1
	animation_speed_spin_box.value = 1.0
	animation_speed_spin_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	animation_speed_spin_box.value_changed.connect(_on_animation_speed_changed)
	speed_row.add_child(animation_speed_spin_box)

	animation_details_label = Label.new()
	layout.add_child(animation_details_label)

	var buttons := HBoxContainer.new()
	layout.add_child(buttons)
	var apply_button := Button.new()
	apply_button.text = "Apply"
	apply_button.pressed.connect(_apply_animation_settings)
	buttons.add_child(apply_button)
	var play_button := Button.new()
	play_button.text = "Play"
	play_button.pressed.connect(_play_selected_animation)
	buttons.add_child(play_button)
	var stop_button := Button.new()
	stop_button.text = "Stop"
	stop_button.pressed.connect(_stop_current_animation)
	buttons.add_child(stop_button)

	animation_editor_panel.hide()

	animation_editor_error_dialog = AcceptDialog.new()
	add_child(animation_editor_error_dialog)


func _load_fbx(path: String) -> void:
	var document := FBXDocument.new()
	var state := FBXState.new()
	var error := document.append_from_file(path, state)
	if error != OK:
		var message := "Could not parse FBX '%s': %s" % [path, error_string(error)]
		push_error(message)
		error_dialog.dialog_text = message
		error_dialog.popup_centered()
		return

	var model := document.generate_scene(state)
	if model == null:
		var message := "Could not generate a scene from FBX '%s'." % path
		push_error(message)
		error_dialog.dialog_text = message
		error_dialog.popup_centered()
		return

	_stop_current_animation()
	for child in character.get_children():
		character.remove_child(child)
		child.queue_free()
	character.add_child(model)
	loaded_fbx_model = model
	loaded_fbx_path = path
	_update_fbx_properties(model, path)
	target = character.global_position + Vector3(0.0, 0.1, 0.0)
	_update_camera()


func _show_empty_fbx_properties() -> void:
	animation_clips.clear()
	animation_list.clear()
	selected_animation_index = -1
	_update_animation_controls()
	fbx_properties_tree.clear()
	fbx_properties_tree.hide_root = true
	fbx_properties_tree.create_item()
	var section := _add_fbx_section("FBX")
	_add_fbx_property_item(section, "Status", "Load a file to inspect it")


func _update_fbx_properties(model: Node, path: String) -> void:
	var properties := {
		"node_count": 0,
		"mesh_count": 0,
		"scales": [],
		"materials": {},
		"textures": {},
		"animations": []
	}
	_collect_fbx_properties(model, properties)
	animation_clips = properties["animations"]
	_update_animation_controls()

	fbx_properties_tree.clear()
	fbx_properties_tree.hide_root = true
	fbx_properties_tree.create_item()

	var file_section := _add_fbx_section("File")
	_add_fbx_property_item(file_section, "Name", path.get_file())
	_add_fbx_property_item(file_section, "Path", path)

	var scene_section := _add_fbx_section("Scene")
	if model is Node3D:
		_add_fbx_property_item(scene_section, "Root scale", _format_vector3((model as Node3D).scale))
	else:
		_add_fbx_property_item(scene_section, "Root scale", "Unavailable")
	_add_fbx_property_item(scene_section, "Nodes", str(properties["node_count"]))
	_add_fbx_property_item(scene_section, "Meshes", str(properties["mesh_count"]))

	var scale_section := _add_fbx_section("Node Scales")
	for scale_info in properties["scales"]:
		_add_fbx_property_item(scale_section, scale_info["name"], scale_info["value"])
	if properties["scales"].is_empty():
		_add_fbx_property_item(scale_section, "Scaled nodes", "None")

	var material_section := _add_fbx_section("Materials")
	_add_fbx_property_item(material_section, "Count", str(properties["materials"].size()))
	for material_name in properties["materials"].values():
		_add_fbx_property_item(material_section, "Material", material_name)

	var texture_section := _add_fbx_section("Textures")
	_add_fbx_property_item(texture_section, "Count", str(properties["textures"].size()))
	for texture_name in properties["textures"].values():
		_add_fbx_property_item(texture_section, "Texture", texture_name)

	var animation_section := _add_fbx_section("Animations")
	_add_fbx_property_item(animation_section, "Count", str(properties["animations"].size()))
	if properties["animations"].is_empty():
		_add_fbx_property_item(animation_section, "Clips", "None found")
	else:
		for animation_info in properties["animations"]:
			var animation_summary := "%.2f sec, %d tracks" % [
				animation_info["length"],
				animation_info["tracks"]
			]
			_add_fbx_property_item(
				animation_section,
				animation_info["global_name"],
				animation_summary
			)


func _collect_fbx_properties(node: Node, properties: Dictionary) -> void:
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
				_add_fbx_resource(properties["materials"], material)
				for property in material.get_property_list():
					var value: Variant = material.get(property["name"])
					if value is Texture2D:
						_add_fbx_resource(properties["textures"], value)

	if node is AnimationPlayer:
		var animation_player := node as AnimationPlayer
		for animation_name in animation_player.get_animation_list():
			var animation := animation_player.get_animation(animation_name)
			if animation != null:
				var library_name := animation_player.find_animation_library(animation)
				var library := animation_player.get_animation_library(library_name)
				var global_name := String(animation_name)
				var local_name := global_name
				if not String(library_name).is_empty():
					local_name = global_name.trim_prefix("%s/" % library_name)
				properties["animations"].append(
					{
						"name": local_name,
						"global_name": global_name,
						"library_name": library_name,
						"library": library,
						"animation": animation,
						"length": animation.length,
						"tracks": animation.get_track_count(),
						"player": animation_player,
						"speed": 1.0
					}
				)

	for child in node.get_children():
		_collect_fbx_properties(child, properties)


func _add_fbx_resource(resources: Dictionary, resource: Resource) -> void:
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


func _add_fbx_section(title: String) -> TreeItem:
	var section := fbx_properties_tree.create_item(fbx_properties_tree.get_root())
	section.set_text(0, title)
	section.set_selectable(0, false)
	section.set_selectable(1, false)
	return section


func _add_fbx_property_item(parent: TreeItem, property_name: String, value: String) -> TreeItem:
	var item := fbx_properties_tree.create_item(parent)
	item.set_text(0, property_name)
	item.set_text(1, value)
	item.set_tooltip_text(0, property_name)
	item.set_tooltip_text(1, value)
	return item


func _update_animation_controls() -> void:
	animation_selector.clear()
	animation_list.clear()
	if animation_clips.is_empty():
		animation_selector.add_item("No animations")
		animation_selector.disabled = true
		animation_edit_button.disabled = true
		animation_play_button.disabled = true
		animation_stop_button.disabled = true
		animation_editor_panel.hide()
		return

	for clip_index in range(animation_clips.size()):
		var clip: Dictionary = animation_clips[clip_index]
		var player := clip["player"] as AnimationPlayer
		var animation_name := String(clip["global_name"])
		var item_name := animation_name
		if animation_clips.size() > 1:
			item_name = "%s / %s" % [player.name, animation_name]
		animation_selector.add_item(item_name)
		animation_list.add_item(item_name)

	animation_selector.select(0)
	animation_selector.disabled = false
	animation_edit_button.disabled = false
	animation_play_button.disabled = false
	animation_stop_button.disabled = true
	animation_list.select(0)
	_load_animation_editor_settings(0)


func _on_animation_selector_selected(index: int) -> void:
	_show_animation_editor(index)


func _edit_selected_animation() -> void:
	_show_animation_editor(animation_selector.selected)


func _on_animation_list_item_selected(index: int) -> void:
	animation_selector.select(index)
	_load_animation_editor_settings(index)


func _show_animation_editor(index: int) -> void:
	if index < 0 or index >= animation_clips.size():
		return
	if not dock_panel_contents[animation_editor_panel].visible:
		_toggle_dock_panel_minimized(animation_editor_panel)
	animation_editor_panel.show()
	animation_editor_panel.move_to_front()
	animation_list.select(index)
	_load_animation_editor_settings(index)


func _load_animation_editor_settings(index: int) -> void:
	if index < 0 or index >= animation_clips.size():
		return
	selected_animation_index = index
	var clip: Dictionary = animation_clips[index]
	animation_name_edit.text = clip["name"]
	var animation := clip["animation"] as Animation
	animation_loop_selector.select(animation.loop_mode)
	animation_speed_spin_box.set_value_no_signal(clip["speed"])
	animation_details_label.text = "%.2f sec, %d tracks" % [
		animation.length,
		animation.get_track_count()
	]


func _apply_animation_settings() -> void:
	if selected_animation_index < 0 or selected_animation_index >= animation_clips.size():
		return

	var clip: Dictionary = animation_clips[selected_animation_index]
	var library := clip["library"] as AnimationLibrary
	if library == null:
		_show_animation_editor_error("The animation library is no longer available.")
		return
	var old_name := StringName(clip["name"])
	var new_name := StringName(animation_name_edit.text.strip_edges())
	if new_name != old_name:
		if not _is_valid_animation_name(String(new_name)):
			_show_animation_editor_error(
				"Animation names cannot be empty or contain '/', ':', ',' or '['."
			)
			return
		if library.has_animation(new_name):
			_show_animation_editor_error("An animation with that name already exists.")
			return
		library.rename_animation(old_name, new_name)
		if not library.has_animation(new_name):
			_show_animation_editor_error("Could not rename the animation.")
			return

	var animation := clip["animation"] as Animation
	animation.loop_mode = animation_loop_selector.selected
	clip["name"] = String(new_name)
	clip["global_name"] = String(new_name)
	if not String(clip["library_name"]).is_empty():
		clip["global_name"] = "%s/%s" % [clip["library_name"], new_name]
	clip["speed"] = animation_speed_spin_box.value

	var edited_player := clip["player"] as AnimationPlayer
	var edited_global_name: String = clip["global_name"]
	var edited_speed: float = clip["speed"]
	_update_fbx_properties(loaded_fbx_model, loaded_fbx_path)
	var renamed_index := _find_animation_clip_index(edited_player, edited_global_name)
	if renamed_index >= 0:
		animation_clips[renamed_index]["speed"] = edited_speed
		_show_animation_editor(renamed_index)


func _is_valid_animation_name(animation_name: String) -> bool:
	return (
		not animation_name.is_empty()
		and not animation_name.contains("/")
		and not animation_name.contains(":")
		and not animation_name.contains(",")
		and not animation_name.contains("[")
	)


func _show_animation_editor_error(message: String) -> void:
	animation_editor_error_dialog.dialog_text = message
	animation_editor_error_dialog.popup_centered()


func _find_animation_clip_index(player: AnimationPlayer, global_name: String) -> int:
	for index in range(animation_clips.size()):
		var clip: Dictionary = animation_clips[index]
		if clip["player"] == player and clip["global_name"] == global_name:
			return index
	return -1


func _on_animation_speed_changed(value: float) -> void:
	if selected_animation_index >= 0 and selected_animation_index < animation_clips.size():
		animation_clips[selected_animation_index]["speed"] = value


func _play_selected_animation() -> void:
	var selected_index := animation_selector.selected
	if selected_index < 0 or selected_index >= animation_clips.size():
		return

	var clip: Dictionary = animation_clips[selected_index]
	var player := clip["player"] as AnimationPlayer
	if not is_instance_valid(player):
		return

	_stop_current_animation()
	active_animation_player = player
	player.play(StringName(clip["global_name"]), -1.0, clip["speed"])
	animation_stop_button.disabled = false


func _stop_current_animation() -> void:
	if is_instance_valid(active_animation_player):
		active_animation_player.stop()
	active_animation_player = null
	if is_instance_valid(animation_stop_button):
		animation_stop_button.disabled = true


func _format_vector3(value: Vector3) -> String:
	return "(%.3f, %.3f, %.3f)" % [value.x, value.y, value.z]


func _input(event: InputEvent) -> void:
	if dragged_dock_panel == null:
		return

	if event is InputEventMouseMotion:
		var mouse_position := (
			ui_workspace.get_global_transform_with_canvas().affine_inverse()
			* get_viewport().get_mouse_position()
		)
		dragged_dock_panel.position = mouse_position - dock_drag_offset
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			_dock_panel_to_nearest_edge(dragged_dock_panel)
			dragged_dock_panel = null
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed:
			match mouse_event.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					distance = clampf(distance - zoom_sensitivity, min_zoom, max_zoom)
					_update_camera()
				MOUSE_BUTTON_WHEEL_DOWN:
					distance = clampf(distance + zoom_sensitivity, min_zoom, max_zoom)
					_update_camera()

	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
			yaw -= motion.relative.x * orbit_sensitivity
			pitch -= motion.relative.y * orbit_sensitivity
			pitch = clampf(pitch, deg_to_rad(-75.0), deg_to_rad(75.0))
			_update_camera()
		elif motion.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE):
			_pan(motion.relative)


func _pan(relative: Vector2) -> void:
	var pan_scale := distance * pan_sensitivity
	var right := camera.global_transform.basis.x
	var up := camera.global_transform.basis.y
	target -= right * relative.x * pan_scale
	target += up * relative.y * pan_scale
	_update_camera()


func _update_camera() -> void:
	var offset := Vector3(
		distance * cos(pitch) * sin(yaw),
		distance * sin(pitch),
		distance * cos(pitch) * cos(yaw)
	)
	camera.global_position = target + offset
	camera.look_at(target, Vector3.UP)
