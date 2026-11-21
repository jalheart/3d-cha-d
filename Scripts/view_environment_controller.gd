class_name ViewEnvironmentController
extends RefCounted

signal settings_failed(message: String)

const DEFAULT_FLOOR_VISIBLE := true
const DEFAULT_FLOOR_COLOR := Color(0.55, 0.55, 0.55)
const DEFAULT_FLOOR_SIZE := 2.0
const DEFAULT_BACKGROUND_COLOR := Color(0.15, 0.15, 0.17)
const DEFAULT_AMBIENT_COLOR := Color(1.0, 1.0, 1.0)
const DEFAULT_AMBIENT_ENERGY := 0.4
const MIN_FLOOR_SIZE := 1.0
const MAX_FLOOR_SIZE := 100.0
const MIN_AMBIENT_ENERGY := 0.0
const MAX_AMBIENT_ENERGY := 4.0

var _floor_mesh: MeshInstance3D
var _environment_node: WorldEnvironment
var _floor_material: StandardMaterial3D
var _settings: Dictionary = {}


func _init(floor_mesh: MeshInstance3D, environment_node: WorldEnvironment) -> void:
	_floor_mesh = floor_mesh
	_environment_node = environment_node
	_settings = {
		"floor_visible": DEFAULT_FLOOR_VISIBLE,
		"floor_color": DEFAULT_FLOOR_COLOR,
		"floor_size": DEFAULT_FLOOR_SIZE,
		"background_color": DEFAULT_BACKGROUND_COLOR,
		"ambient_color": DEFAULT_AMBIENT_COLOR,
		"ambient_energy": DEFAULT_AMBIENT_ENERGY
	}
	if _floor_mesh == null:
		push_error("ViewEnvironmentController requires a floor MeshInstance3D.")
	if _environment_node == null:
		push_error("ViewEnvironmentController requires a WorldEnvironment node.")
	_apply_floor()
	_apply_environment()


func get_settings() -> Dictionary:
	return _settings.duplicate()


func apply_settings(settings: Dictionary) -> bool:
	var next := _settings.duplicate()
	var valid := true
	for key in next.keys():
		if not settings.has(key):
			continue
		var value: Variant = settings[key]
		if not _is_valid_value(key, value):
			settings_failed.emit("The value for '%s' is invalid." % key)
			valid = false
			continue
		next[key] = value
	_settings = next
	_apply_floor()
	_apply_environment()
	return valid


func _is_valid_value(key: String, value: Variant) -> bool:
	match key:
		"floor_visible":
			return value is bool
		"floor_color", "background_color", "ambient_color":
			return value is Color
		"floor_size":
			return (
				_is_number(value)
				and float(value) >= MIN_FLOOR_SIZE
				and float(value) <= MAX_FLOOR_SIZE
			)
		"ambient_energy":
			return (
				_is_number(value)
				and float(value) >= MIN_AMBIENT_ENERGY
				and float(value) <= MAX_AMBIENT_ENERGY
			)
	return false


func _is_number(value: Variant) -> bool:
	return value is float or value is int


func _apply_floor() -> void:
	if _floor_mesh == null:
		return
	_floor_mesh.visible = _settings["floor_visible"]
	_floor_mesh.scale = Vector3.ONE * float(_settings["floor_size"])
	if _floor_material == null:
		_floor_material = StandardMaterial3D.new()
		_floor_material.roughness = 1.0
		_floor_mesh.material_override = _floor_material
	_floor_material.albedo_color = _settings["floor_color"]


func _apply_environment() -> void:
	if _environment_node == null:
		return
	var environment := _environment_node.environment
	if environment == null:
		environment = Environment.new()
		_environment_node.environment = environment
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = _settings["background_color"]
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = _settings["ambient_color"]
	environment.ambient_light_energy = float(_settings["ambient_energy"])
	environment.ambient_light_sky_contribution = 0.0
