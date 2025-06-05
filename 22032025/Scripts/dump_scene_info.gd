extends Node

func _ready():
	var root = get_tree().root
	var dump_text = dump_node_info(root, 0)
	
	# Write to "user://scene_dump.txt"
	var file_path = "user://scene_dump.txt"
	var file = FileAccess.open(file_path, FileAccess.ModeFlags.WRITE)
	if file:
		file.store_string(dump_text)
		file.close()
		print("Scene dump saved to %s" % file_path)
	else:
		printerr("Failed to open file for writing: %s" % file_path)
	
	# Optional: quit after dumping
	# get_tree().quit()

func dump_node_info(node: Node, indent: int) -> String:
	var output := ""
	var indent_str = get_indent_str(indent)
	
	# Basic Node info: name, type
	output += "%sName: %s, Type: %s" % [indent_str, node.name, node.get_class()]
	
	# Check if there's a script attached
	var script_obj = node.get_script()
	if script_obj != null:
		var script_path = script_obj.resource_path
		if script_path != "":
			output += " [Script: %s]" % script_path
	output += "\n"
	
	# Print properties via the node's property list
	var prop_list = node.get_property_list()
	for prop in prop_list:
		var prop_name = prop.name
		
		# Only read properties meant for storage
		if (prop.usage & PROPERTY_USAGE_STORAGE) != 0:
			var got_value = false
			var value = null
			
			if node.has_method("get") and prop_name in node:
				value = node.get(prop_name)
				got_value = true
			
			if got_value:
				output += indent_str + "  " + prop_name + ": " + str(value) + "\n"
			else:
				output += indent_str + "  " + prop_name + ": <unreadable or unsupported>\n"
		else:
			output += indent_str + "  " + prop_name + ": <non-storage/filtered>\n"
	
	# Recurse through children
	for child in node.get_children():
		output += dump_node_info(child, indent + 1)
	
	return output

func get_indent_str(indent: int) -> String:
	var s = ""
	for i in range(indent):
		s += "  "
	return s
