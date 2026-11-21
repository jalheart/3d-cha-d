class_name WebFilePicker
extends RefCounted

signal file_picked(file_name: String, bytes: PackedByteArray)
signal picker_failed(message: String)

const FILE_INPUT_ID := "dchad-file-input"
const PICKED_NAME_PROPERTY := "dchadPickedName"
const PICKED_BUFFER_PROPERTY := "dchadPickedBuffer"
const NOTIFY_PROPERTY := "dchadFileNotify"

var _window: JavaScriptObject
var _notify_callback: JavaScriptObject


func open(accept: String) -> void:
	if not OS.has_feature("web"):
		picker_failed.emit("Picking files from the file system is only available in Web builds.")
		return
	_window = JavaScriptBridge.get_interface("window")
	_notify_callback = JavaScriptBridge.create_callback(_on_file_ready)
	_window[NOTIFY_PROPERTY] = _notify_callback
	JavaScriptBridge.eval(_build_open_script(accept))


func _build_open_script(accept: String) -> String:
	var safe_accept := accept.replace("\\", "\\\\").replace("\"", "\\\"")
	return """
(function () {
	var existing = document.getElementById("%s");
	if (existing) { existing.remove(); }
	var input = document.createElement("input");
	input.type = "file";
	input.id = "%s";
	input.accept = "%s";
	input.style.display = "none";
	input.onchange = function () {
		var file = input.files && input.files[0];
		input.remove();
		if (!file) { return; }
		file.arrayBuffer().then(function (buffer) {
			window.%s = file.name;
			window.%s = buffer;
			if (window.%s) { window.%s(); }
		}, function () {
			window.%s = "";
			window.%s = undefined;
			if (window.%s) { window.%s(); }
		});
	};
	input.oncancel = function () { input.remove(); };
	document.body.appendChild(input);
	input.click();
})()
""" % [
		FILE_INPUT_ID,
		FILE_INPUT_ID,
		safe_accept,
		PICKED_NAME_PROPERTY,
		PICKED_BUFFER_PROPERTY,
		NOTIFY_PROPERTY,
		NOTIFY_PROPERTY,
		PICKED_NAME_PROPERTY,
		PICKED_BUFFER_PROPERTY,
		NOTIFY_PROPERTY,
		NOTIFY_PROPERTY,
	]


func _on_file_ready(_args: Array) -> void:
	var file_name: Variant = JavaScriptBridge.eval("window.%s || ''" % PICKED_NAME_PROPERTY)
	var bytes: Variant = JavaScriptBridge.eval("window.%s" % PICKED_BUFFER_PROPERTY)
	JavaScriptBridge.eval(
		"window.%s = undefined; window.%s = undefined;"
		% [PICKED_NAME_PROPERTY, PICKED_BUFFER_PROPERTY]
	)
	if not file_name is String or String(file_name).is_empty():
		picker_failed.emit("The selected file could not be read.")
		return
	if not bytes is PackedByteArray:
		picker_failed.emit("The selected file '%s' could not be read." % String(file_name))
		return
	file_picked.emit(String(file_name), bytes)
