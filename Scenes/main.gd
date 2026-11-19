extends Node3D

const RECENT_FILES_CONFIG_PATH := "user://recent_files.cfg"
const MAX_RECENT_FILES := 10
const RECENT_FILE_ITEM_ID_BASE := 100

@onready var camera: OrbitCameraController = $Camera3D
@onready var character: Node3D = $Character

var _fbx_loader: FbxSceneLoader
var _fbx_exporter: FbxSceneExporter
var _inspector_panel: FbxInspectorPanel
var _animation_panel: FbxAnimationEditorPanel
var _file_dialog: FileDialog
var _scene_export_dialog: FileDialog
var _object_export_dialog: FbxObjectExportDialog
var _export_success_dialog: AcceptDialog
var _loaded_model: Node
var _recent_files_menu: PopupMenu
var _recent_files: Array[String] = []
var _recent_file_paths_by_id: Dictionary = {}
var _error_dialog: AcceptDialog


func _ready() -> void:
	_fbx_loader = FbxSceneLoader.new()
	_fbx_loader.load_failed.connect(_show_error)
	_fbx_exporter = FbxSceneExporter.new()
	_fbx_exporter.export_failed.connect(_show_error)
	_create_runtime_ui()
	_load_recent_files()
	camera.initialize_target(character.global_position + Vector3(0.0, 0.1, 0.0))



func _create_runtime_ui() -> void:
	var ui_layer := CanvasLayer.new()
	add_child(ui_layer)

	var workspace := Control.new()
	workspace.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	workspace.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(workspace)

	var viewport_size := get_viewport().get_visible_rect().size
	_inspector_panel = FbxInspectorPanel.new()
	_inspector_panel.setup(
		workspace,
		Vector2(maxf(12.0, viewport_size.x - 332.0), 52.0),
		Vector2(320.0, maxf(240.0, viewport_size.y - 64.0))
	)

	_animation_panel = FbxAnimationEditorPanel.new()
	_animation_panel.setup(
		workspace,
		Vector2(maxf(12.0, viewport_size.x - 704.0), 68.0),
		Vector2(360.0, 420.0)
	)
	_object_export_dialog = FbxObjectExportDialog.new()
	_object_export_dialog.setup(workspace, _fbx_exporter)

	var menu_bar := MenuBar.new()
	ui_layer.add_child(menu_bar)
	var file_menu_button := MenuButton.new()
	file_menu_button.text = "File"
	menu_bar.add_child(file_menu_button)

	var file_menu := file_menu_button.get_popup()
	file_menu.add_item("Load .fbx", 0)
	file_menu.add_separator()
	file_menu.add_item("Export Loaded Scene...", 2)
	file_menu.add_item("Export Object...", 3)
	file_menu.id_pressed.connect(_on_file_menu_item_pressed)
	_recent_files_menu = PopupMenu.new()
	_recent_files_menu.name = "RecentFilesMenu"
	file_menu.add_child(_recent_files_menu)
	file_menu.add_submenu_item("Recent Files", "RecentFilesMenu", 1)
	_recent_files_menu.id_pressed.connect(_on_recent_file_menu_item_pressed)
	menu_bar.position = Vector2(8.0, 8.0)
	menu_bar.size = menu_bar.get_combined_minimum_size()

	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.add_filter("*.fbx,*.FBX ; FBX files")
	_file_dialog.file_selected.connect(_load_fbx)
	add_child(_file_dialog)

	_scene_export_dialog = FileDialog.new()
	_scene_export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_scene_export_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_scene_export_dialog.add_filter("*.tscn ; Text Scene")
	_scene_export_dialog.add_filter("*.scn ; Binary Scene")
	_scene_export_dialog.file_selected.connect(_export_loaded_scene)
	add_child(_scene_export_dialog)

	_error_dialog = AcceptDialog.new()
	add_child(_error_dialog)
	_export_success_dialog = AcceptDialog.new()
	_export_success_dialog.title = "Scene Exported"
	add_child(_export_success_dialog)


func _on_file_menu_item_pressed(id: int) -> void:
	if id == 0:
		_file_dialog.popup_centered_ratio()
	elif id == 2:
		_open_scene_export_dialog()
	elif id == 3:
		_open_object_export_dialog()


func _on_recent_file_menu_item_pressed(id: int) -> void:
	var path: String = _recent_file_paths_by_id.get(id, "")
	if not path.is_empty():
		_load_fbx(path)


func _load_fbx(path: String) -> void:
	var model := _fbx_loader.load_scene(path)
	if model == null:
		return

	_animation_panel.stop_playback()
	for child in character.get_children():
		character.remove_child(child)
		child.queue_free()
	character.add_child(model)

	var animation_count := _animation_panel.set_model(model)
	_inspector_panel.inspect_model(model, path, animation_count)
	camera.set_target(character.global_position + Vector3(0.0, 0.1, 0.0))
	_loaded_model = model
	_remember_recent_file(path)


func _open_scene_export_dialog() -> void:
	if not is_instance_valid(_loaded_model):
		_show_error("Load an FBX file before exporting its scene.")
		return
	var filename := String(_loaded_model.name).validate_filename()
	if filename.is_empty():
		filename = "model"
	_scene_export_dialog.current_file = "%s.tscn" % filename
	_scene_export_dialog.popup_centered_ratio()


func _open_object_export_dialog() -> void:
	if not is_instance_valid(_loaded_model):
		_show_error("Load an FBX file before exporting an object.")
		return
	_object_export_dialog.open_for_model(_loaded_model)


func _export_loaded_scene(path: String) -> void:
	if not is_instance_valid(_loaded_model):
		_show_error("Load an FBX file before exporting its scene.")
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

	if _fbx_exporter.save_scene(_loaded_model, path):
		_export_success_dialog.dialog_text = "Exported the loaded model scene to:\n%s" % path
		_export_success_dialog.popup_centered()


func _load_recent_files() -> void:
	var config := ConfigFile.new()
	var error := config.load(RECENT_FILES_CONFIG_PATH)
	if error == ERR_FILE_NOT_FOUND:
		_refresh_recent_files_menu()
		return
	if error != OK:
		_show_error("Could not load recent files: %s" % error_string(error))
		return

	var stored_paths: Variant = config.get_value("recent_files", "paths", [])
	if not stored_paths is Array:
		_show_error("The saved recent files list is invalid.")
		return

	for stored_path in stored_paths:
		if stored_path is String and not stored_path.is_empty():
			if not _recent_files.has(stored_path):
				_recent_files.append(stored_path)
		else:
			push_error("Ignoring an invalid path in the saved recent files list.")
		if _recent_files.size() >= MAX_RECENT_FILES:
			break
	_refresh_recent_files_menu()


func _remember_recent_file(path: String) -> void:
	_recent_files.erase(path)
	_recent_files.push_front(path)
	if _recent_files.size() > MAX_RECENT_FILES:
		_recent_files.resize(MAX_RECENT_FILES)
	_refresh_recent_files_menu()

	var config := ConfigFile.new()
	config.set_value("recent_files", "paths", _recent_files)
	var error := config.save(RECENT_FILES_CONFIG_PATH)
	if error != OK:
		_show_error("Could not save recent files: %s" % error_string(error))


func _refresh_recent_files_menu() -> void:
	_recent_files_menu.clear()
	_recent_file_paths_by_id.clear()
	if _recent_files.is_empty():
		_recent_files_menu.add_item("No recent files", 0)
		_recent_files_menu.set_item_disabled(0, true)
		return

	for index in range(_recent_files.size()):
		var path := _recent_files[index]
		var item_id := RECENT_FILE_ITEM_ID_BASE + index
		_recent_files_menu.add_item("%s — %s" % [path.get_file(), path.get_base_dir()], item_id)
		_recent_files_menu.set_item_tooltip(index, path)
		_recent_file_paths_by_id[item_id] = path


func _show_error(message: String) -> void:
	_error_dialog.dialog_text = message
	_error_dialog.popup_centered()
