class_name EnvironmentPanel
extends SidebarPanel

signal settings_changed(settings: Dictionary)
signal settings_committed(settings: Dictionary)

const MIN_FLOOR_SIZE := 1.0
const MAX_FLOOR_SIZE := 100.0
const MIN_AMBIENT_ENERGY := 0.0
const MAX_AMBIENT_ENERGY := 4.0

var _floor_visible_check: CheckBox
var _floor_color_picker: ColorPickerButton
var _floor_size_spin: SpinBox
var _background_color_picker: ColorPickerButton
var _ambient_color_picker: ColorPickerButton
var _ambient_energy_spin: SpinBox
var _updating := false


func setup() -> void:
	configure("Environment", "☀")

	var note := Label.new()
	note.text = "Floor and ambient settings are saved automatically."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_container.add_child(note)

	var floor_label := Label.new()
	floor_label.text = "Floor"
	content_container.add_child(floor_label)

	_floor_visible_check = CheckBox.new()
	_floor_visible_check.text = "Show floor"
	_floor_visible_check.toggled.connect(_on_check_box_toggled)
	content_container.add_child(_floor_visible_check)

	_floor_color_picker = _create_color_row("Color")
	_floor_color_picker.color_changed.connect(_on_color_changed)
	_floor_color_picker.popup_closed.connect(_on_color_committed)

	_floor_size_spin = _create_spin_row(
		"Size",
		MIN_FLOOR_SIZE,
		MAX_FLOOR_SIZE,
		0.5
	)
	_floor_size_spin.value_changed.connect(_on_spin_box_changed)

	var environment_label := Label.new()
	environment_label.text = "Environment"
	content_container.add_child(environment_label)

	_background_color_picker = _create_color_row("Background")
	_background_color_picker.color_changed.connect(_on_color_changed)
	_background_color_picker.popup_closed.connect(_on_color_committed)

	_ambient_color_picker = _create_color_row("Ambient light")
	_ambient_color_picker.color_changed.connect(_on_color_changed)
	_ambient_color_picker.popup_closed.connect(_on_color_committed)

	_ambient_energy_spin = _create_spin_row(
		"Ambient energy",
		MIN_AMBIENT_ENERGY,
		MAX_AMBIENT_ENERGY,
		0.05
	)
	_ambient_energy_spin.value_changed.connect(_on_spin_box_changed)


func get_settings() -> Dictionary:
	return {
		"floor_visible": _floor_visible_check.button_pressed,
		"floor_color": _floor_color_picker.color,
		"floor_size": _floor_size_spin.value,
		"background_color": _background_color_picker.color,
		"ambient_color": _ambient_color_picker.color,
		"ambient_energy": _ambient_energy_spin.value
	}


func apply_settings(settings: Dictionary) -> void:
	_updating = true
	_floor_visible_check.set_pressed_no_signal(
		bool(settings.get("floor_visible", true))
	)
	_floor_color_picker.color = settings.get("floor_color", Color.WHITE)
	_floor_size_spin.set_value_no_signal(
		float(settings.get("floor_size", MIN_FLOOR_SIZE))
	)
	_background_color_picker.color = settings.get(
		"background_color",
		Color.BLACK
	)
	_ambient_color_picker.color = settings.get("ambient_color", Color.WHITE)
	_ambient_energy_spin.set_value_no_signal(
		float(settings.get("ambient_energy", 0.0))
	)
	_updating = false


func apply_ui_theme(theme: Theme) -> void:
	_floor_color_picker.get_picker().theme = theme
	_background_color_picker.get_picker().theme = theme
	_ambient_color_picker.get_picker().theme = theme


func _create_color_row(label_text: String) -> ColorPickerButton:
	var row := HBoxContainer.new()
	content_container.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 100.0
	row.add_child(label)
	var picker := ColorPickerButton.new()
	picker.edit_alpha = false
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(picker)
	return picker


func _create_spin_row(
	label_text: String,
	minimum: float,
	maximum: float,
	step: float
) -> SpinBox:
	var row := HBoxContainer.new()
	content_container.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 100.0
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spin)
	return spin


func _on_check_box_toggled(_pressed: bool) -> void:
	_commit_settings()


func _on_spin_box_changed(_value: float) -> void:
	_commit_settings()


func _on_color_changed(_color: Color) -> void:
	if _updating:
		return
	settings_changed.emit(get_settings())


func _on_color_committed() -> void:
	_commit_settings()


func _commit_settings() -> void:
	if _updating:
		return
	settings_committed.emit(get_settings())
