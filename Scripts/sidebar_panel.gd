class_name SidebarPanel
extends PanelContainer

enum Location { LEFT_SIDEBAR, RIGHT_SIDEBAR, BOTTOM_PANEL }

signal location_changed(location: int)

var content_container: VBoxContainer
var location: int = Location.LEFT_SIDEBAR

var _title_label: Label
var _collapsed_icon: Button
var _collapse_button: Button
var _location_button: MenuButton
var _collapsed := false


func configure(title: String, collapsed_icon: String) -> void:
	name = title
	custom_minimum_size.x = 280.0
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var layout := VBoxContainer.new()
	add_child(layout)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 30.0
	layout.add_child(header)

	_title_label = Label.new()
	_title_label.text = title
	_title_label.tooltip_text = title
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	_collapsed_icon = Button.new()
	_collapsed_icon.text = collapsed_icon
	_collapsed_icon.tooltip_text = "Expand %s" % title
	_collapsed_icon.custom_minimum_size.x = 28.0
	_collapsed_icon.flat = true
	_collapsed_icon.pressed.connect(_toggle_collapsed)
	_collapsed_icon.hide()
	header.add_child(_collapsed_icon)

	_collapse_button = Button.new()
	_collapse_button.text = "-"
	_collapse_button.tooltip_text = "Collapse panel"
	_collapse_button.pressed.connect(_toggle_collapsed)
	header.add_child(_collapse_button)

	_location_button = MenuButton.new()
	_location_button.text = "⋮"
	_location_button.tooltip_text = "Panel location"
	_location_button.custom_minimum_size.x = 28.0
	var location_menu := _location_button.get_popup()
	location_menu.add_radio_check_item("Left Sidebar", Location.LEFT_SIDEBAR)
	location_menu.add_radio_check_item("Right Sidebar", Location.RIGHT_SIDEBAR)
	location_menu.add_radio_check_item("Bottom Panel", Location.BOTTOM_PANEL)
	location_menu.id_pressed.connect(_on_location_selected)
	header.add_child(_location_button)

	content_container = VBoxContainer.new()
	content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(content_container)
	set_location(Location.LEFT_SIDEBAR)


func set_location(new_location: int) -> void:
	location = new_location
	if _location_button != null:
		var location_menu := _location_button.get_popup()
		for item_index in range(location_menu.item_count):
			location_menu.set_item_checked(
				item_index,
				location_menu.get_item_id(item_index) == location
			)
	_update_header()


func _on_location_selected(new_location: int) -> void:
	if not [
		Location.LEFT_SIDEBAR,
		Location.RIGHT_SIDEBAR,
		Location.BOTTOM_PANEL
	].has(new_location):
		push_error("Unsupported sidebar location: %d" % new_location)
		return
	if new_location == location:
		return
	set_location(new_location)
	location_changed.emit(location)


func _toggle_collapsed() -> void:
	_collapsed = not _collapsed
	content_container.visible = not _collapsed
	_collapse_button.text = "+" if _collapsed else "-"
	_collapse_button.tooltip_text = "Expand panel" if _collapsed else "Collapse panel"
	_update_header()
	size_flags_vertical = (
		Control.SIZE_SHRINK_BEGIN if _collapsed else Control.SIZE_EXPAND_FILL
	)


func _update_header() -> void:
	var icon_only := _collapsed and location != Location.BOTTOM_PANEL
	_title_label.visible = not icon_only
	_collapsed_icon.visible = icon_only
	_collapse_button.visible = not icon_only
	custom_minimum_size.x = 68.0 if icon_only else 280.0
	if icon_only:
		size_flags_horizontal = (
			Control.SIZE_SHRINK_END
			if location == Location.RIGHT_SIDEBAR
			else Control.SIZE_SHRINK_BEGIN
		)
	else:
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = (
		Control.SIZE_SHRINK_BEGIN if _collapsed else Control.SIZE_EXPAND_FILL
	)
