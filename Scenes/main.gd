extends Node3D

const RECENT_FILES_CONFIG_PATH := "user://recent_files.cfg"
const UI_SETTINGS_CONFIG_PATH := "user://ui_settings.cfg"
const MAX_RECENT_FILES := 10
const RECENT_FILE_ITEM_ID_BASE := 100
const FONT_SIZE_EXTRA_SMALL := 12
const FONT_SIZE_SMALL := 14
const FONT_SIZE_DEFAULT := 16
const FONT_SIZE_LARGE := 18

@onready var camera: OrbitCameraController = $Camera3D
@onready var character: Node3D = $Character

var _fbx_loader: FbxSceneLoader
var _fbx_exporter: FbxSceneExporter
var _inspector_panel: FbxInspectorPanel
var _animation_panel: FbxAnimationEditorPanel
var _sidebar: DockablePanel
var _sidebar_tabs: TabContainer
var _file_dialog: FileDialog
var _scene_export_dialog: FileDialog
var _object_export_dialog: FbxObjectExportDialog
var _export_success_dialog: AcceptDialog
var _text_size_menu: PopupMenu
var _ui_root: Control
var _loaded_model: Node
var _recent_files_menu: PopupMenu
var _recent_files: Array[String] = []
var _recent_file_paths_by_id: Dictionary = {}
var _error_dialog: AcceptDialog
var _ui_font_size := FONT_SIZE_DEFAULT


func _ready() -> void:
	_fbx_loader = FbxSceneLoader.new()
	_fbx_loader.load_failed.connect(_show_error)
	_fbx_exporter = FbxSceneExporter.new()
	_fbx_exporter.export_failed.connect(_show_error)
	_create_runtime_ui()
	_load_recent_files()
	_load_ui_settings()
	_apply_ui_theme()
	camera.initialize_target(character.global_position + Vector3(0.0, 0.1, 0.0))



func _create_runtime_ui() -> void:
	var ui_layer := CanvasLayer.new()
	add_child(ui_layer)

	_ui_root = Control.new()
	_ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(_ui_root)

	var workspace := Control.new()
	workspace.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	workspace.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.add_child(workspace)

	var viewport_size := get_viewport().get_visible_rect().size
	_sidebar = DockablePanel.new()
	_sidebar.configure(
		"FBX Explorer",
		workspace,
		Vector2(12.0, 52.0),
		Vector2(360.0, maxf(240.0, viewport_size.y - 64.0))
	)
	_sidebar_tabs = TabContainer.new()
	_sidebar_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sidebar_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sidebar.content_container.add_child(_sidebar_tabs)

	_inspector_panel = FbxInspectorPanel.new()
	_inspector_panel.setup(_sidebar_tabs)

	_animation_panel = FbxAnimationEditorPanel.new()
	_animation_panel.setup(_sidebar_tabs, workspace)
	_sidebar_tabs.set_tab_disabled(1, true)
	_object_export_dialog = FbxObjectExportDialog.new()
	_object_export_dialog.setup(workspace, _fbx_exporter)

	var menu_surface := PanelContainer.new()
	menu_surface.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	menu_surface.offset_left = 0.0
	menu_surface.offset_top = 0.0
	menu_surface.offset_right = 0.0
	menu_surface.offset_bottom = 36.0
	_ui_root.add_child(menu_surface)

	var menu_bar := MenuBar.new()
	menu_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu_surface.add_child(menu_bar)
	var file_menu := PopupMenu.new()
	file_menu.name = "FileMenu"
	menu_bar.add_child(file_menu)
	menu_bar.set_menu_title(0, "File")
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

	var view_menu := PopupMenu.new()
	view_menu.name = "ViewMenu"
	menu_bar.add_child(view_menu)
	menu_bar.set_menu_title(1, "View")
	_text_size_menu = PopupMenu.new()
	_text_size_menu.name = "TextSizeMenu"
	view_menu.add_child(_text_size_menu)
	view_menu.add_submenu_item("Text Size", "TextSizeMenu", 0)
	_text_size_menu.add_radio_check_item("Extra Small (12 px)", FONT_SIZE_EXTRA_SMALL)
	_text_size_menu.add_radio_check_item("Small (14 px)", FONT_SIZE_SMALL)
	_text_size_menu.add_radio_check_item("Default (16 px)", FONT_SIZE_DEFAULT)
	_text_size_menu.add_radio_check_item("Large (18 px)", FONT_SIZE_LARGE)
	_text_size_menu.id_pressed.connect(_on_text_size_selected)
	_update_text_size_menu()

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


func _on_text_size_selected(font_size: int) -> void:
	if not [FONT_SIZE_EXTRA_SMALL, FONT_SIZE_SMALL, FONT_SIZE_DEFAULT, FONT_SIZE_LARGE].has(font_size):
		_show_error("Choose a supported text size.")
		return
	_ui_font_size = font_size
	_apply_ui_theme()
	_update_text_size_menu()
	_save_ui_settings()


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
	_sidebar_tabs.set_tab_disabled(1, animation_count == 0)
	_sidebar_tabs.current_tab = 1 if animation_count > 0 else 0
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


func _load_ui_settings() -> void:
	var config := ConfigFile.new()
	var error := config.load(UI_SETTINGS_CONFIG_PATH)
	if error == ERR_FILE_NOT_FOUND:
		return
	if error != OK:
		_show_error("Could not load UI settings: %s" % error_string(error))
		return

	var stored_font_size: Variant = config.get_value("ui", "font_size", FONT_SIZE_DEFAULT)
	if not stored_font_size is int:
		_show_error("The saved text size is invalid.")
		return
	if not [FONT_SIZE_EXTRA_SMALL, FONT_SIZE_SMALL, FONT_SIZE_DEFAULT, FONT_SIZE_LARGE].has(stored_font_size):
		_show_error("The saved text size is not supported.")
		return
	_ui_font_size = stored_font_size
	_update_text_size_menu()


func _save_ui_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("ui", "font_size", _ui_font_size)
	var error := config.save(UI_SETTINGS_CONFIG_PATH)
	if error != OK:
		_show_error("Could not save UI settings: %s" % error_string(error))


func _apply_ui_theme() -> void:
	var theme := ThemeDB.get_default_theme().duplicate() as Theme
	var base_font_size := theme.default_font_size
	if base_font_size <= 0:
		base_font_size = FONT_SIZE_DEFAULT
	var font_scale := float(_ui_font_size) / float(base_font_size)
	for theme_type in theme.get_font_size_type_list():
		for font_size_name in theme.get_font_size_list(theme_type):
			var original_size := theme.get_font_size(font_size_name, theme_type)
			theme.set_font_size(
				font_size_name,
				theme_type,
				maxi(1, roundi(float(original_size) * font_scale))
			)
	theme.default_font_size = _ui_font_size
	_ui_root.theme = theme
	get_tree().root.theme = theme
	_file_dialog.theme = theme
	_scene_export_dialog.theme = theme
	_error_dialog.theme = theme
	_export_success_dialog.theme = theme
	_object_export_dialog.apply_ui_theme(theme)
	_animation_panel.apply_ui_theme(theme)


func _update_text_size_menu() -> void:
	if _text_size_menu == null:
		return
	for index in range(_text_size_menu.item_count):
		_text_size_menu.set_item_checked(
			index,
			_text_size_menu.get_item_id(index) == _ui_font_size
		)


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
