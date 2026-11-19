class_name AnimationLibraryExportDialog
extends Window

var _workspace: Control
var _source_library: AnimationLibrary
var _pending_export_library: AnimationLibrary
var _library_name_edit: LineEdit
var _root_prefix_edit: LineEdit
var _animation_names_tree: Tree
var _track_paths_tree: Tree
var _bulk_find_edit: LineEdit
var _bulk_replace_edit: LineEdit
var _bulk_replace_button: Button
var _bulk_status_label: Label
var _file_dialog: FileDialog
var _error_dialog: AcceptDialog
var _success_dialog: AcceptDialog


func setup(workspace: Control) -> void:
	_workspace = workspace
	title = "Export Animation Library"
	size = Vector2i(560, 460)
	min_size = Vector2i(420, 340)
	workspace.add_child(self)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)

	var layout := VBoxContainer.new()
	margin.add_child(layout)

	var name_row := HBoxContainer.new()
	layout.add_child(name_row)
	var name_label := Label.new()
	name_label.text = "Library name"
	name_label.custom_minimum_size.x = 130.0
	name_row.add_child(name_label)
	_library_name_edit = LineEdit.new()
	_library_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_library_name_edit)

	var root_row := HBoxContainer.new()
	layout.add_child(root_row)
	var root_label := Label.new()
	root_label.text = "Track root prefix"
	root_label.custom_minimum_size.x = 130.0
	root_row.add_child(root_label)
	_root_prefix_edit = LineEdit.new()
	_root_prefix_edit.placeholder_text = "Leave empty to keep original paths"
	_root_prefix_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_row.add_child(_root_prefix_edit)

	var root_note := Label.new()
	root_note.text = "Prefix is added to each target path; set AnimationPlayer.root_node in the destination scene."
	root_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(root_note)

	var mapping_tabs := TabContainer.new()
	mapping_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(mapping_tabs)

	var animation_names_page := VBoxContainer.new()
	animation_names_page.name = "Animation Names"
	mapping_tabs.add_child(animation_names_page)
	_animation_names_tree = _create_mapping_tree("Source name", "Export name")
	_animation_names_tree.custom_minimum_size.y = 120.0
	_animation_names_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	animation_names_page.add_child(_animation_names_tree)

	var track_paths_page := VBoxContainer.new()
	track_paths_page.name = "Track Paths"
	mapping_tabs.add_child(track_paths_page)
	var bulk_rename_row := HBoxContainer.new()
	track_paths_page.add_child(bulk_rename_row)
	_bulk_find_edit = LineEdit.new()
	_bulk_find_edit.placeholder_text = "Find in export paths"
	_bulk_find_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bulk_find_edit.text_changed.connect(_on_bulk_find_changed)
	bulk_rename_row.add_child(_bulk_find_edit)
	_bulk_replace_edit = LineEdit.new()
	_bulk_replace_edit.placeholder_text = "Replace with"
	_bulk_replace_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bulk_rename_row.add_child(_bulk_replace_edit)
	_bulk_replace_button = Button.new()
	_bulk_replace_button.text = "Replace All"
	_bulk_replace_button.disabled = true
	_bulk_replace_button.pressed.connect(_apply_bulk_track_path_rename)
	bulk_rename_row.add_child(_bulk_replace_button)
	_bulk_status_label = Label.new()
	_bulk_status_label.text = "Case-sensitive; replaces every match in export paths."
	track_paths_page.add_child(_bulk_status_label)
	_track_paths_tree = _create_mapping_tree("Source path", "Export path")
	_track_paths_tree.custom_minimum_size.y = 120.0
	_track_paths_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	track_paths_page.add_child(_track_paths_tree)

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
	_file_dialog.add_filter("*.tres ; Text Resource")
	_file_dialog.add_filter("*.res ; Binary Resource")
	_file_dialog.file_selected.connect(_save_export)
	workspace.add_child(_file_dialog)

	_error_dialog = AcceptDialog.new()
	workspace.add_child(_error_dialog)

	_success_dialog = AcceptDialog.new()
	_success_dialog.title = "Animation Library Exported"
	workspace.add_child(_success_dialog)
	hide()


func open_for_library(library: AnimationLibrary) -> void:
	_source_library = library
	_pending_export_library = null
	_library_name_edit.text = library.resource_name
	if _library_name_edit.text.is_empty():
		_library_name_edit.text = "Animations"
	_root_prefix_edit.clear()
	_populate_animation_names()
	_populate_track_paths()
	popup_centered()


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


func _populate_animation_names() -> void:
	_animation_names_tree.clear()
	_animation_names_tree.create_item()
	for animation_name in _source_library.get_animation_list():
		var source_name := String(animation_name)
		var item := _animation_names_tree.create_item(_animation_names_tree.get_root())
		item.set_text(0, source_name)
		item.set_text(1, source_name)
		item.set_editable(1, true)
		item.set_tooltip_text(0, source_name)
		item.set_tooltip_text(1, source_name)


func _populate_track_paths() -> void:
	_track_paths_tree.clear()
	_track_paths_tree.create_item()
	_bulk_status_label.text = "Case-sensitive; replaces every match in export paths."
	var seen_paths: Dictionary = {}
	for animation_name in _source_library.get_animation_list():
		var animation := _source_library.get_animation(animation_name)
		if animation == null:
			continue
		for track_index in range(animation.get_track_count()):
			var source_path := String(animation.track_get_path(track_index))
			if seen_paths.has(source_path):
				continue
			seen_paths[source_path] = true
			var item := _track_paths_tree.create_item(_track_paths_tree.get_root())
			item.set_text(0, source_path)
			item.set_text(1, source_path)
			item.set_editable(1, true)
			item.set_tooltip_text(0, source_path)
			item.set_tooltip_text(1, source_path)


func _on_bulk_find_changed(search_text: String) -> void:
	_bulk_replace_button.disabled = search_text.is_empty()
	_bulk_status_label.text = "Case-sensitive; replaces every match in export paths."


func _apply_bulk_track_path_rename() -> void:
	var search_text := _bulk_find_edit.text
	if search_text.is_empty():
		_bulk_status_label.text = "Enter text to find."
		return

	var updated_count := 0
	var item := _track_paths_tree.get_root().get_first_child()
	while item != null:
		var current_path := item.get_text(1)
		var updated_path := current_path.replace(search_text, _bulk_replace_edit.text)
		if updated_path != current_path:
			item.set_text(1, updated_path)
			item.set_tooltip_text(1, updated_path)
			updated_count += 1
		item = item.get_next()

	if updated_count == 0:
		_bulk_status_label.text = "No matching track paths."
	else:
		_bulk_status_label.text = "Updated %d track path(s)." % updated_count


func _open_file_dialog() -> void:
	_pending_export_library = _build_export_library()
	if _pending_export_library == null:
		return
	var filename := _library_name_edit.text.strip_edges().validate_filename()
	if filename.is_empty():
		filename = "Animations"
	_file_dialog.current_file = "%s.tres" % filename
	_file_dialog.popup_centered_ratio()


func _build_export_library() -> AnimationLibrary:
	var export_name := _library_name_edit.text.strip_edges()
	if export_name.is_empty():
		_show_error("Library name cannot be empty.")
		return null

	var animation_names := _read_mapping(_animation_names_tree)
	var track_paths := _read_mapping(_track_paths_tree)
	var used_names: Dictionary = {}
	var exported_library := AnimationLibrary.new()
	exported_library.resource_name = export_name
	var root_prefix := _root_prefix_edit.text.strip_edges()
	if root_prefix.contains(":"):
		_show_error("Track root prefix cannot contain a subname separator ':'.")
		return null

	for source_name in _source_library.get_animation_list():
		var source_name_string := String(source_name)
		var export_name_for_animation: String = animation_names.get(
			source_name_string,
			source_name_string
		).strip_edges()
		if not _is_valid_animation_name(export_name_for_animation):
			_show_error("Invalid animation name: '%s'." % export_name_for_animation)
			return null
		if used_names.has(export_name_for_animation):
			_show_error("Duplicate export animation name: '%s'." % export_name_for_animation)
			return null
		used_names[export_name_for_animation] = true

		var source_animation := _source_library.get_animation(source_name)
		if source_animation == null:
			_show_error("Could not read animation '%s'." % source_name_string)
			return null
		var exported_animation := source_animation.duplicate(true) as Animation
		if exported_animation == null:
			_show_error("Could not duplicate animation '%s'." % source_name_string)
			return null

		for track_index in range(exported_animation.get_track_count()):
			var source_path := String(source_animation.track_get_path(track_index))
			var export_path: String = track_paths.get(source_path, source_path).strip_edges()
			if export_path.is_empty():
				_show_error("Track path for '%s' cannot be empty." % source_path)
				return null
			if not root_prefix.is_empty():
				export_path = _prepend_root_prefix(export_path, root_prefix)
			exported_animation.track_set_path(track_index, NodePath(export_path))

		var add_error := exported_library.add_animation(
			StringName(export_name_for_animation),
			exported_animation
		)
		if add_error != OK:
			_show_error(
				"Could not add animation '%s' to the export library: %s"
				% [export_name_for_animation, error_string(add_error)]
			)
			return null

	return exported_library


func _read_mapping(tree: Tree) -> Dictionary:
	var mapping: Dictionary = {}
	var root := tree.get_root()
	if root == null:
		return mapping
	var item := root.get_first_child()
	while item != null:
		mapping[item.get_text(0)] = item.get_text(1)
		item = item.get_next()
	return mapping


func _prepend_root_prefix(track_path: String, root_prefix: String) -> String:
	var separator_index := track_path.find(":")
	var node_path := track_path
	var subnames := ""
	if separator_index >= 0:
		node_path = track_path.substr(0, separator_index)
		subnames = track_path.substr(separator_index)

	if node_path.is_empty() or node_path == ".":
		node_path = root_prefix
	elif root_prefix.ends_with("/"):
		node_path = root_prefix + node_path
	else:
		node_path = root_prefix + "/" + node_path
	return node_path + subnames


func _save_export(path: String) -> void:
	if _pending_export_library == null:
		_show_error("Build the animation library export before saving.")
		return
	var extension := path.get_extension().to_lower()
	if extension.is_empty():
		path += ".tres"
		extension = "tres"
	if extension != "res" and extension != "tres":
		_show_error("Choose a .res or .tres file extension.")
		return
	if path.get_extension() != extension:
		path = "%s.%s" % [path.get_basename(), extension]

	var error := ResourceSaver.save(_pending_export_library, path)
	if error != OK:
		_show_error("Could not export the animation library to '%s': %s" % [
			path,
			error_string(error)
		])
		return

	_success_dialog.dialog_text = "Exported %d animations to:\n%s" % [
		_pending_export_library.get_animation_list().size(),
		path
	]
	_success_dialog.popup_centered()


func _is_valid_animation_name(animation_name: String) -> bool:
	return (
		not animation_name.is_empty()
		and not animation_name.contains("/")
		and not animation_name.contains(":")
		and not animation_name.contains(",")
		and not animation_name.contains("[")
	)


func _show_error(message: String) -> void:
	push_error(message)
	_error_dialog.dialog_text = message
	_error_dialog.popup_centered()
