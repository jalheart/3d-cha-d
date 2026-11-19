extends Node3D

@onready var camera: OrbitCameraController = $Camera3D
@onready var character: Node3D = $Character

var _fbx_loader: FbxSceneLoader
var _inspector_panel: FbxInspectorPanel
var _animation_panel: FbxAnimationEditorPanel
var _file_dialog: FileDialog
var _error_dialog: AcceptDialog


func _ready() -> void:
	_fbx_loader = FbxSceneLoader.new()
	_fbx_loader.load_failed.connect(_show_load_error)
	_create_runtime_ui()
	camera.initialize_target(character.global_position + Vector3(0.0, 0.1, 0.0))


func _create_runtime_ui() -> void:
	var ui_layer := CanvasLayer.new()
	add_child(ui_layer)

	var workspace := Control.new()
	workspace.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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

	var menu_bar := MenuBar.new()
	ui_layer.add_child(menu_bar)
	var file_menu_button := MenuButton.new()
	file_menu_button.text = "File"
	menu_bar.add_child(file_menu_button)

	var file_menu := file_menu_button.get_popup()
	file_menu.add_item("Load .fbx", 0)
	file_menu.id_pressed.connect(_on_file_menu_item_pressed)
	menu_bar.position = Vector2(8.0, 8.0)
	menu_bar.size = menu_bar.get_combined_minimum_size()

	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.add_filter("*.fbx,*.FBX ; FBX files")
	_file_dialog.file_selected.connect(_load_fbx)
	add_child(_file_dialog)

	_error_dialog = AcceptDialog.new()
	add_child(_error_dialog)


func _on_file_menu_item_pressed(id: int) -> void:
	if id == 0:
		_file_dialog.popup_centered_ratio()


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


func _show_load_error(message: String) -> void:
	_error_dialog.dialog_text = message
	_error_dialog.popup_centered()
