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

	for child in character.get_children():
		character.remove_child(child)
		child.queue_free()
	character.add_child(model)
	target = character.global_position + Vector3(0.0, 0.1, 0.0)
	_update_camera()


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
