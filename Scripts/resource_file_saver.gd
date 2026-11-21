class_name ResourceFileSaver
extends RefCounted

const WEB_TEMP_PATH := "user://_web_export_download"


static func save(resource: Resource, path: String, flags: int = 0) -> Error:
	if not OS.has_feature("web"):
		return ResourceSaver.save(resource, path, flags)
	return _download(resource, path.get_file(), flags)


static func describe_saved_path(path: String) -> String:
	if not OS.has_feature("web"):
		return path
	return "Downloads/%s" % path.get_file()


static func _download(resource: Resource, file_name: String, flags: int) -> Error:
	var extension := file_name.get_extension().to_lower()
	if extension.is_empty():
		return ERR_INVALID_PARAMETER
	var temp_path := "%s.%s" % [WEB_TEMP_PATH, extension]
	var error := ResourceSaver.save(resource, temp_path, flags)
	if error != OK:
		return error
	var bytes := FileAccess.get_file_as_bytes(temp_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
	if bytes.is_empty():
		return ERR_FILE_CANT_READ
	JavaScriptBridge.download_buffer(bytes, file_name, _mime_type_for(extension))
	return OK


static func _mime_type_for(extension: String) -> String:
	match extension:
		"tscn", "tres":
			return "text/plain"
		_:
			return "application/octet-stream"
