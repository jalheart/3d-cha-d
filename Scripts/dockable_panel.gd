class_name DockablePanel
extends PanelContainer

var content_container: VBoxContainer

var _workspace: Control
var _minimize_button: Button
var _expanded_height := 0.0
var _dragging := false
var _drag_offset := Vector2.ZERO


func configure(
	title: String,
	workspace: Control,
	initial_position: Vector2,
	initial_size: Vector2
) -> void:
	_workspace = workspace
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	position = initial_position
	size = initial_size
	custom_minimum_size = Vector2(260.0, 40.0)
	_expanded_height = initial_size.y
	workspace.add_child(self)

	var panel_layout := VBoxContainer.new()
	add_child(panel_layout)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 28.0
	panel_layout.add_child(header)

	var title_label := Label.new()
	title_label.text = title
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.mouse_filter = Control.MOUSE_FILTER_STOP
	title_label.tooltip_text = "Drag to move or dock this panel"
	title_label.mouse_default_cursor_shape = Control.CURSOR_MOVE
	title_label.gui_input.connect(_on_title_gui_input)
	header.add_child(title_label)

	_minimize_button = Button.new()
	_minimize_button.text = "-"
	_minimize_button.tooltip_text = "Minimize panel"
	_minimize_button.pressed.connect(_toggle_minimized)
	header.add_child(_minimize_button)

	content_container = VBoxContainer.new()
	content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_layout.add_child(content_container)


func show_panel() -> void:
	if not content_container.visible:
		_restore()
	show()
	move_to_front()


func _on_title_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			var mouse_position := (
				_workspace.get_global_transform_with_canvas().affine_inverse()
				* mouse_event.global_position
			)
			_dragging = true
			_drag_offset = mouse_position - position
			move_to_front()
			get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not _dragging:
		return

	if event is InputEventMouseMotion:
		var mouse_position := (
			_workspace.get_global_transform_with_canvas().affine_inverse()
			* get_viewport().get_mouse_position()
		)
		position = mouse_position - _drag_offset
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			_snap_to_dock()
			_dragging = false
			get_viewport().set_input_as_handled()


func _toggle_minimized() -> void:
	if content_container.visible:
		_expanded_height = size.y
		content_container.hide()
		size.y = 40.0
		_minimize_button.text = "+"
		_minimize_button.tooltip_text = "Restore panel"
	else:
		_restore()


func _restore() -> void:
	content_container.show()
	size.y = _expanded_height
	_minimize_button.text = "-"
	_minimize_button.tooltip_text = "Minimize panel"


func _snap_to_dock() -> void:
	var viewport_size := _workspace.size
	var snap_distance := 24.0
	var snapped_to_panel := false

	for child in _workspace.get_children():
		if child == self or not child is DockablePanel or not child.visible:
			continue
		var other_panel := child as DockablePanel
		var vertical_overlap: bool = (
			position.y < other_panel.position.y + other_panel.size.y
			and position.y + size.y > other_panel.position.y
		)
		var horizontal_overlap: bool = (
			position.x < other_panel.position.x + other_panel.size.x
			and position.x + size.x > other_panel.position.x
		)
		if vertical_overlap and absf(position.x + size.x - other_panel.position.x) < snap_distance:
			position.x = other_panel.position.x - size.x
			snapped_to_panel = true
			break
		if vertical_overlap and absf(position.x - other_panel.position.x - other_panel.size.x) < snap_distance:
			position.x = other_panel.position.x + other_panel.size.x
			snapped_to_panel = true
			break
		if horizontal_overlap and absf(position.y + size.y - other_panel.position.y) < snap_distance:
			position.y = other_panel.position.y - size.y
			snapped_to_panel = true
			break
		if horizontal_overlap and absf(position.y - other_panel.position.y - other_panel.size.y) < snap_distance:
			position.y = other_panel.position.y + other_panel.size.y
			snapped_to_panel = true
			break

	if not snapped_to_panel:
		if absf(position.x - 12.0) < snap_distance:
			position.x = 12.0
		elif absf(position.x + size.x - viewport_size.x + 12.0) < snap_distance:
			position.x = viewport_size.x - size.x - 12.0
		if absf(position.y - 12.0) < snap_distance:
			position.y = 12.0
		elif absf(position.y + size.y - viewport_size.y + 12.0) < snap_distance:
			position.y = viewport_size.y - size.y - 12.0

	position.x = clampf(position.x, 0.0, maxf(0.0, viewport_size.x - size.x))
	position.y = clampf(position.y, 0.0, maxf(0.0, viewport_size.y - size.y))
