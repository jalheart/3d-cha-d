class_name FbxObjectExportDialog
extends Window

var _exporter: FbxSceneExporter
var _model_root: Node
var _selected_root: Node
var _source_tree: Tree
var _source_tree_items: Dictionary = {}
var _object_names_tree: Tree
var _bone_names_tree: Tree
var _bone_find_edit: LineEdit
var _bone_replace_edit: LineEdit
var _bone_replace_button: Button
var _bone_bulk_status: Label
var _file_dialog: FileDialog
var _error_dialog: AcceptDialog
var _success_dialog: AcceptDialog


func setup(workspace: Control, exporter: FbxSceneExporter) -> void:
	_exporter = exporter
	title = "Export Object"
	size = Vector2i(760, 560)
	min_size = Vector2i(620, 420)
	close_requested.connect(hide)
	workspace.add_child(self)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)

	var layout := VBoxContainer.new()
	margin.add_child(layout)

	var note := Label.new()
	note.text = "Choose an object and rename nodes/bones for the export copy. Animation paths are not renamed; use Export Library for those."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(note)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(split)

	_source_tree = Tree.new()
	_source_tree.columns = 1
	_source_tree.hide_root = true
	_source_tree.select_mode = Tree.SELECT_SINGLE
	_source_tree.custom_minimum_size.x = 210.0
	_source_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_source_tree.item_selected.connect(_on_source_node_selected)
	split.add_child(_source_tree)

	var mapping_tabs := TabContainer.new()
	mapping_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mapping_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(mapping_tabs)

	var object_page := VBoxContainer.new()
	object_page.name = "Objects"
	mapping_tabs.add_child(object_page)
	_object_names_tree = _create_mapping_tree("Source object path", "Export name")
	_object_names_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	object_page.add_child(_object_names_tree)

	var bone_page := VBoxContainer.new()
	bone_page.name = "Bones"
	mapping_tabs.add_child(bone_page)
	var bulk_rename_row := HBoxContainer.new()
	bone_page.add_child(bulk_rename_row)
	_bone_find_edit = LineEdit.new()
	_bone_find_edit.placeholder_text = "Find in export bone names"
	_bone_find_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bone_find_edit.text_changed.connect(_on_bone_find_changed)
	bulk_rename_row.add_child(_bone_find_edit)
	_bone_replace_edit = LineEdit.new()
	_bone_replace_edit.placeholder_text = "Replace with"
	_bone_replace_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bulk_rename_row.add_child(_bone_replace_edit)
	_bone_replace_button = Button.new()
	_bone_replace_button.text = "Replace All"
	_bone_replace_button.disabled = true
	_bone_replace_button.pressed.connect(_apply_bulk_bone_rename)
	bulk_rename_row.add_child(_bone_replace_button)
	_bone_bulk_status = Label.new()
	_bone_bulk_status.text = "Case-sensitive; replaces every match in export bone names."
	bone_page.add_child(_bone_bulk_status)
	_bone_names_tree = _create_mapping_tree("Skeleton / source bone", "Export bone name")
	_bone_names_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bone_page.add_child(_bone_names_tree)

	var buttons := HBoxContainer.new()
	layout.add_child(buttons)
	var export_button := Button.new()
	export_button.text = "Choose Export File..."
	export_button.pressed.connect(_open_file_dialog)
	buttons.add_child(export_button)
	var cancel_button := Button.new()
	cancel_button.text = "Cancel"
	cancel_button.pressed.connect(hide)
	buttons.add_child(cancel_button)

	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.add_filter("*.tscn ; Text Scene")
	_file_dialog.add_filter("*.scn ; Binary Scene")
	_file_dialog.file_selected.connect(_save_export)
	workspace.add_child(_file_dialog)

	_error_dialog = AcceptDialog.new()
	_error_dialog.title = "Object Export Error"
	workspace.add_child(_error_dialog)
	_success_dialog = AcceptDialog.new()
	_success_dialog.title = "Object Exported"
	workspace.add_child(_success_dialog)
	hide()


func apply_ui_theme(theme: Theme) -> void:
	self.theme = theme
	_file_dialog.theme = theme
	_error_dialog.theme = theme
	_success_dialog.theme = theme


func open_for_model(model: Node) -> void:
	if not is_instance_valid(model):
		_show_error("The loaded model is no longer available.")
		return
	_model_root = model
	_selected_root = null
	_populate_source_tree()

	var default_root := _find_skeleton_parent(_model_root)
	if default_root == null:
		default_root = _model_root
	var selected_item: TreeItem = _source_tree_items.get(default_root)
	if selected_item != null:
		var ancestor := selected_item
		while ancestor != null:
			ancestor.set_collapsed(false)
			ancestor = ancestor.get_parent()
		selected_item.select(0)
		_on_source_node_selected()
	else:
		_show_error("Could not select an object from the loaded model.")
		return
	popup_centered()


func _populate_source_tree() -> void:
	_source_tree.clear()
	_source_tree_items.clear()
	var hidden_root := _source_tree.create_item()
	_add_source_tree_item(hidden_root, _model_root, ".", String(_model_root.name))


func _add_source_tree_item(
	parent_item: TreeItem,
	node: Node,
	index_path: String,
	display_path: String
) -> void:
	var item := _source_tree.create_item(parent_item)
	item.set_text(0, String(node.name))
	item.set_tooltip_text(0, display_path)
	item.set_metadata(0, node)
	_source_tree_items[node] = item

	for child_index in range(node.get_child_count()):
		var child := node.get_child(child_index)
		var child_index_path := str(child_index) if index_path == "." else "%s/%d" % [
			index_path,
			child_index
		]
		_add_source_tree_item(
			item,
			child,
			child_index_path,
			"%s/%s" % [display_path, child.name]
		)


func _find_skeleton_parent(node: Node) -> Node:
	if node is Skeleton3D:
		var parent := node.get_parent()
		return parent if parent != null else node
	for child in node.get_children():
		var result := _find_skeleton_parent(child)
		if result != null:
			return result
	return null


func _on_source_node_selected() -> void:
	var item := _source_tree.get_selected()
	if item == null:
		return
	_selected_root = item.get_metadata(0) as Node
	if is_instance_valid(_selected_root):
		_populate_name_mappings()


func _populate_name_mappings() -> void:
	_object_names_tree.clear()
	_bone_names_tree.clear()
	_bone_bulk_status.text = "Case-sensitive; replaces every match in export bone names."
	var object_root := _object_names_tree.create_item()
	var bone_root := _bone_names_tree.create_item()
	_add_object_name_item(object_root, _selected_root, ".", String(_selected_root.name))
	_add_bone_name_items(bone_root, _selected_root, ".", String(_selected_root.name))


func _add_object_name_item(
	parent_item: TreeItem,
	node: Node,
	index_path: String,
	display_path: String
) -> void:
	var item := _object_names_tree.create_item(parent_item)
	item.set_text(0, display_path)
	item.set_text(1, String(node.name))
	item.set_editable(1, true)
	item.set_metadata(0, index_path)

	for child_index in range(node.get_child_count()):
		var child := node.get_child(child_index)
		var child_index_path := str(child_index) if index_path == "." else "%s/%d" % [
			index_path,
			child_index
		]
		_add_object_name_item(
			parent_item,
			child,
			child_index_path,
			"%s/%s" % [display_path, child.name]
		)


func _add_bone_name_items(
	parent_item: TreeItem,
	node: Node,
	index_path: String,
	display_path: String
) -> void:
	if node is Skeleton3D:
		var skeleton := node as Skeleton3D
		for bone_index in range(skeleton.get_bone_count()):
			var bone_name := skeleton.get_bone_name(bone_index)
			var item := _bone_names_tree.create_item(parent_item)
			item.set_text(0, "%s : %s" % [display_path, bone_name])
			item.set_text(1, bone_name)
			item.set_editable(1, true)
			item.set_metadata(
				0,
				{"skeleton_path": index_path, "bone_index": bone_index}
			)

	for child_index in range(node.get_child_count()):
		var child := node.get_child(child_index)
		var child_index_path := str(child_index) if index_path == "." else "%s/%d" % [
			index_path,
			child_index
		]
		_add_bone_name_items(
			parent_item,
			child,
			child_index_path,
			"%s/%s" % [display_path, child.name]
		)


func _create_mapping_tree(source_title: String, export_title: String) -> Tree:
	var tree := Tree.new()
	tree.columns = 2
	tree.column_titles_visible = true
	tree.set_column_title(0, source_title)
	tree.set_column_title(1, export_title)
	tree.set_column_expand(0, true)
	tree.set_column_expand(1, true)
	tree.hide_root = true
	return tree


func _read_object_name_mapping() -> Dictionary:
	var mapping: Dictionary = {}
	var root := _object_names_tree.get_root()
	if root == null:
		return mapping
	var item := root.get_first_child()
	while item != null:
		mapping[String(item.get_metadata(0))] = item.get_text(1).strip_edges()
		item = item.get_next()
	return mapping


func _read_bone_name_mapping() -> Dictionary:
	var mapping: Dictionary = {}
	var root := _bone_names_tree.get_root()
	if root == null:
		return mapping
	var item := root.get_first_child()
	while item != null:
		var metadata: Dictionary = item.get_metadata(0)
		var skeleton_path: String = metadata["skeleton_path"]
		var bone_index: int = metadata["bone_index"]
		var names: Dictionary = mapping.get(skeleton_path, {})
		names[bone_index] = item.get_text(1).strip_edges()
		mapping[skeleton_path] = names
		item = item.get_next()
	return mapping


func _on_bone_find_changed(search_text: String) -> void:
	_bone_replace_button.disabled = search_text.is_empty()
	_bone_bulk_status.text = "Case-sensitive; replaces every match in export bone names."


func _apply_bulk_bone_rename() -> void:
	var search_text := _bone_find_edit.text
	if search_text.is_empty():
		_bone_bulk_status.text = "Enter text to find."
		return

	var updated_count := 0
	var root := _bone_names_tree.get_root()
	if root != null:
		var item := root.get_first_child()
		while item != null:
			var current_name := item.get_text(1)
			var updated_name := current_name.replace(search_text, _bone_replace_edit.text)
			if updated_name != current_name:
				item.set_text(1, updated_name)
				item.set_tooltip_text(1, updated_name)
				updated_count += 1
			item = item.get_next()

	if updated_count == 0:
		_bone_bulk_status.text = "No matching bone names."
	else:
		_bone_bulk_status.text = "Updated %d bone name(s)." % updated_count


func _open_file_dialog() -> void:
	if not is_instance_valid(_selected_root):
		_show_error("Select an object to export.")
		return
	var filename := String(_selected_root.name).validate_filename()
	if filename.is_empty():
		filename = "object"
	if OS.has_feature("web"):
		_save_export("%s.tscn" % filename)
		return
	_file_dialog.current_file = "%s.tscn" % filename
	_file_dialog.popup_centered_ratio()


func _save_export(path: String) -> void:
	if not is_instance_valid(_selected_root) or not is_instance_valid(_model_root):
		_show_error("The selected object is no longer available.")
		return
	if _selected_root != _model_root and not _model_root.is_ancestor_of(_selected_root):
		_show_error("The selected object is no longer part of the loaded model.")
		return

	var extension := path.get_extension().to_lower()
	if extension.is_empty():
		path += ".tscn"
		extension = "tscn"
	if extension != "tscn" and extension != "scn":
		_show_error("Choose a .tscn or .scn file extension.")
		return
	if path.get_extension() != extension:
		path = "%s.%s" % [path.get_basename(), extension]

	if _exporter.save_subtree_scene(
		_selected_root,
		path,
		_read_object_name_mapping(),
		_read_bone_name_mapping()
	):
		_success_dialog.dialog_text = "Exported object '%s' to:\n%s" % [
			_selected_root.name,
			ResourceFileSaver.describe_saved_path(path)
		]
		_success_dialog.popup_centered()


func _show_error(message: String) -> void:
	push_error(message)
	_error_dialog.dialog_text = message
	_error_dialog.popup_centered()
