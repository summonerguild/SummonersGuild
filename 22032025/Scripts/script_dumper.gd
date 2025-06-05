extends Node

# Change these paths as needed.
var scripts_folder_path := "res://Scripts"
var output_file_path := "user://DumpedScripts.txt"

func _ready():
	var output_file = FileAccess.open(output_file_path, FileAccess.WRITE)
	if output_file == null:
		push_error("Cannot open file for writing: " + output_file_path)
		return

	_dump_scripts(scripts_folder_path, output_file)
	output_file.close()
	print("Scripts dumped to ", output_file_path)

func _dump_scripts(dir_path: String, output_file: FileAccess) -> void:
	var dir_access = DirAccess.open(dir_path)
	if dir_access == null:
		push_error("Cannot open directory: " + dir_path)
		return

	dir_access.list_dir_begin()
	while true:
		var entry = dir_access.get_next()
		if entry == "":
			break
		if entry.begins_with("."):
			continue

		# Use string concatenation to build the full path.
		var full_path = dir_path + "/" + entry

		if dir_access.current_is_dir():
			_dump_scripts(full_path, output_file)
		else:
			# Adjust the file extension if needed.
			if entry.ends_with(".gd"):
				output_file.store_line("----- " + entry + " -----")
				var script_file = FileAccess.open(full_path, FileAccess.READ)
				if script_file:
					var content = script_file.get_as_text()
					output_file.store_string(content)
					output_file.store_line("\n")
					script_file.close()
				else:
					output_file.store_line("Error reading file: " + full_path)
	dir_access.list_dir_end()
