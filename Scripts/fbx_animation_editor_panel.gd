class_name FbxAnimationEditorPanel
extends SidebarPanel

var _animation_list: ItemList
var _name_edit: LineEdit
var _loop_selector: OptionButton
var _speed_spin_box: SpinBox
var _details_label: Label
var _error_dialog: AcceptDialog
var _export_dialog: AnimationLibraryExportDialog
var _clips: Array[Dictionary] = []
var _selected_index := -1
var _active_player: AnimationPlayer


func setup(workspace: Control) -> void:
	configure("Animation Editor", "▶")

	var note := Label.new()
	note.text = "Changes apply to the currently loaded model."
	content_container.add_child(note)

	_animation_list = ItemList.new()
	_animation_list.custom_minimum_size.y = 140.0
	_animation_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_animation_list.item_selected.connect(_on_animation_selected)
	content_container.add_child(_animation_list)

	var name_row := HBoxContainer.new()
	content_container.add_child(name_row)
	var name_label := Label.new()
	name_label.text = "Name"
	name_label.custom_minimum_size.x = 80.0
	name_row.add_child(name_label)
	_name_edit = LineEdit.new()
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_name_edit)

	var loop_row := HBoxContainer.new()
	content_container.add_child(loop_row)
	var loop_label := Label.new()
	loop_label.text = "Loop mode"
	loop_label.custom_minimum_size.x = 80.0
	loop_row.add_child(loop_label)
	_loop_selector = OptionButton.new()
	_loop_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_loop_selector.add_item("None")
	_loop_selector.add_item("Linear")
	_loop_selector.add_item("Ping-pong")
	loop_row.add_child(_loop_selector)

	var speed_row := HBoxContainer.new()
	content_container.add_child(speed_row)
	var speed_label := Label.new()
	speed_label.text = "Play speed"
	speed_label.custom_minimum_size.x = 80.0
	speed_row.add_child(speed_label)
	_speed_spin_box = SpinBox.new()
	_speed_spin_box.min_value = 0.1
	_speed_spin_box.max_value = 4.0
	_speed_spin_box.step = 0.1
	_speed_spin_box.value = 1.0
	_speed_spin_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speed_row.add_child(_speed_spin_box)

	_details_label = Label.new()
	content_container.add_child(_details_label)

	var buttons := HBoxContainer.new()
	content_container.add_child(buttons)
	var export_button := Button.new()
	export_button.text = "Export Library"
	export_button.tooltip_text = "Export and remap the selected clip's AnimationLibrary"
	export_button.pressed.connect(_open_export_dialog)
	buttons.add_child(export_button)
	var apply_button := Button.new()
	apply_button.text = "Apply"
	apply_button.pressed.connect(_apply_settings)
	buttons.add_child(apply_button)
	var play_button := Button.new()
	play_button.text = "Play"
	play_button.pressed.connect(_play_selected)
	buttons.add_child(play_button)
	var stop_button := Button.new()
	stop_button.text = "Stop"
	stop_button.pressed.connect(stop_playback)
	buttons.add_child(stop_button)

	_error_dialog = AcceptDialog.new()
	workspace.add_child(_error_dialog)

	_export_dialog = AnimationLibraryExportDialog.new()
	_export_dialog.setup(workspace)
	hide()


func set_model(model: Node) -> int:
	stop_playback()
	_clips.clear()
	_animation_list.clear()
	_selected_index = -1
	_collect_animations(model)

	if _clips.is_empty():
		hide()
		return 0

	for clip in _clips:
		_animation_list.add_item(_get_clip_display_name(clip))
	_animation_list.select(0)
	_load_settings(0)
	show()
	return _clips.size()


func apply_ui_theme(theme: Theme) -> void:
	_error_dialog.theme = theme
	_export_dialog.apply_ui_theme(theme)


func stop_playback() -> void:
	if is_instance_valid(_active_player):
		_active_player.stop()
	_active_player = null


func _collect_animations(node: Node) -> void:
	if node is AnimationPlayer:
		var player := node as AnimationPlayer
		for animation_key in player.get_animation_list():
			var animation := player.get_animation(animation_key)
			if animation == null:
				continue

			var library_name := player.find_animation_library(animation)
			var library := player.get_animation_library(library_name)
			if library == null:
				var message := "Could not find the animation library for '%s'." % animation_key
				push_error(message)
				continue

			var global_name := String(animation_key)
			var local_name := global_name
			if not String(library_name).is_empty():
				local_name = global_name.trim_prefix("%s/" % library_name)
			_clips.append(
				{
					"name": local_name,
					"global_name": global_name,
					"library_name": library_name,
					"library": library,
					"animation": animation,
					"player": player,
					"speed": 1.0
				}
			)

	for child in node.get_children():
		_collect_animations(child)


func _on_animation_selected(index: int) -> void:
	_load_settings(index)


func _load_settings(index: int) -> void:
	if index < 0 or index >= _clips.size():
		return
	_selected_index = index
	var clip: Dictionary = _clips[index]
	var animation := clip["animation"] as Animation
	_name_edit.text = clip["name"]
	_loop_selector.select(animation.loop_mode)
	_speed_spin_box.set_value_no_signal(clip["speed"])
	_details_label.text = "%.2f sec, %d tracks" % [
		animation.length,
		animation.get_track_count()
	]


func _apply_settings() -> bool:
	if _selected_index < 0 or _selected_index >= _clips.size():
		return false

	var clip: Dictionary = _clips[_selected_index]
	var library := clip["library"] as AnimationLibrary
	if library == null:
		_show_error("The animation library is no longer available.")
		return false
	var old_name := StringName(clip["name"])
	var new_name := StringName(_name_edit.text.strip_edges())
	if new_name != old_name:
		if not _is_valid_animation_name(String(new_name)):
			_show_error("Animation names cannot be empty or contain '/', ':', ',' or '['.")
			return false
		if library.has_animation(new_name):
			_show_error("An animation with that name already exists.")
			return false
		library.rename_animation(old_name, new_name)
		if not library.has_animation(new_name):
			_show_error("Could not rename the animation.")
			return false

	var animation := clip["animation"] as Animation
	animation.loop_mode = _loop_selector.selected
	clip["name"] = String(new_name)
	clip["global_name"] = String(new_name)
	if not String(clip["library_name"]).is_empty():
		clip["global_name"] = "%s/%s" % [clip["library_name"], new_name]
	clip["speed"] = _speed_spin_box.value

	_animation_list.set_item_text(_selected_index, _get_clip_display_name(clip))
	_load_settings(_selected_index)
	return true


func _open_export_dialog() -> void:
	if _selected_index < 0 or _selected_index >= _clips.size():
		return
	if not _apply_settings():
		return
	var clip: Dictionary = _clips[_selected_index]
	var library := clip["library"] as AnimationLibrary
	if library == null:
		_show_error("The animation library is no longer available.")
		return
	_export_dialog.open_for_library(library)


func _play_selected() -> void:
	if _selected_index < 0 or _selected_index >= _clips.size():
		return
	var clip: Dictionary = _clips[_selected_index]
	var player := clip["player"] as AnimationPlayer
	if not is_instance_valid(player):
		_show_error("The animation player is no longer available.")
		return

	clip["speed"] = _speed_spin_box.value
	stop_playback()
	_active_player = player
	player.play(StringName(clip["global_name"]), -1.0, clip["speed"])


func _get_clip_display_name(clip: Dictionary) -> String:
	var player := clip["player"] as AnimationPlayer
	if _clips.size() > 1:
		return "%s / %s" % [player.name, clip["global_name"]]
	return String(clip["global_name"])


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
