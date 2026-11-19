class_name OrbitCameraController
extends Camera3D

@export var orbit_sensitivity := 0.005
@export var pan_sensitivity := 0.005
@export var zoom_sensitivity := 0.25
@export var min_zoom := 0.8
@export var max_zoom := 12.0

var _target := Vector3.ZERO
var _yaw := 0.0
var _pitch := 0.0
var _distance := 2.3


func initialize_target(target_position: Vector3) -> void:
	_target = target_position
	var offset := global_position - _target
	_distance = clampf(offset.length(), min_zoom, max_zoom)
	if _distance > 0.0:
		_yaw = atan2(offset.x, offset.z)
		_pitch = asin(clampf(offset.normalized().y, -1.0, 1.0))
	_update_camera()


func set_target(target_position: Vector3) -> void:
	_target = target_position
	_update_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed:
			match mouse_event.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					_distance = clampf(_distance - zoom_sensitivity, min_zoom, max_zoom)
					_update_camera()
				MOUSE_BUTTON_WHEEL_DOWN:
					_distance = clampf(_distance + zoom_sensitivity, min_zoom, max_zoom)
					_update_camera()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_yaw -= motion.relative.x * orbit_sensitivity
			_pitch -= motion.relative.y * orbit_sensitivity
			_pitch = clampf(_pitch, deg_to_rad(-75.0), deg_to_rad(75.0))
			_update_camera()
		elif motion.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE):
			_pan(motion.relative)


func _pan(relative: Vector2) -> void:
	var pan_scale := _distance * pan_sensitivity
	var right := global_transform.basis.x
	var up := global_transform.basis.y
	_target -= right * relative.x * pan_scale
	_target += up * relative.y * pan_scale
	_update_camera()


func _update_camera() -> void:
	var offset := Vector3(
		_distance * cos(_pitch) * sin(_yaw),
		_distance * sin(_pitch),
		_distance * cos(_pitch) * cos(_yaw)
	)
	global_position = _target + offset
	look_at(_target, Vector3.UP)
