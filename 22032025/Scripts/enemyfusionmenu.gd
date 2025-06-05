extends Control

var hand_manager
var card_factory
var descriptive_box  # Reference to the DescriptiveBox

signal fusion_selected(fusion_card_data)

var is_fusion_in_progress = false
var fusion_options: Array = []

func _ready():
	# Print our own size, global position, and parent's info.
	print("enemy fusion: _ready() called. Global position:", global_position, " size:", size)
	if get_parent():
		print("enemy fusion: My parent is:", get_parent().name)
		if get_parent().has_method("clip_children"):
			print("enemy fusion: Parent clip_children:", get_parent().clip_children)
		else:
			print("enemy fusion: Parent has no clip_children property")
	else:
		print("enemy fusion: No parent found!")
		
		push_error("enemy fusion: CardContainer not found!")


func clear_container(container: HBoxContainer) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

func populate_fusion_options(parent1_data, parent2_data):
	# Clear any previous fusion children.
	for child in get_children():
		child.queue_free()
	fusion_options.clear()
	
	# Compute fusion candidates.
	fusion_options = card_factory.fuse_cards(parent1_data, parent2_data)
	print("enemy fusion: Fusion options computed:", fusion_options.size())
	if fusion_options.size() == 0:
		print("enemy fusion: No candidates found at fusion_level:", 
			  card_factory.get_fusion_level(parent1_data.fusion_level, parent2_data.fusion_level))
		return
	
	# Create and add fusion card instances.
	for i in range(fusion_options.size()):
		var candidate_data = fusion_options[i]
		var fusion_card_instance = card_factory.create_card(candidate_data, true)
		fusion_card_instance.position = Vector2(i * 110, 0)
		print("enemy fusion: Created fusion card for '%s' with local position: %s" % 
			  [candidate_data.name, fusion_card_instance.position])
		
		# We need to handle this card uniquely for the enemy fusion menu
		# First, set hand_manager to null to prevent default behavior
		fusion_card_instance.hand_manager = null
		
		# Completely replace the input handling by first disconnecting any existing connections
		# Check if there are any existing connections to gui_input
		var connections = fusion_card_instance.get_signal_connection_list("gui_input")
		for connection in connections:
			fusion_card_instance.disconnect("gui_input", connection.callable)
		
		# Now connect our custom handler
		fusion_card_instance.connect("gui_input", Callable(self, "_on_fusion_card_selected").bind(fusion_card_instance))
		
		add_child(fusion_card_instance)
		print("enemy fusion: Added fusion card for '%s'; global position now: %s" % 
			  [candidate_data.name, fusion_card_instance.global_position])
		
		# Additional debug: check the TextureRect node details.
		if fusion_card_instance.has_node("TextureRect"):
			var tex_node = fusion_card_instance.get_node("TextureRect")
			print("enemy fusion: Fusion card '%s' TextureRect -> texture: %s, size: %s, modulate: %s, visible: %s" %
				  [candidate_data.name, tex_node.texture, tex_node.size, tex_node.modulate, tex_node.visible])
		else:
			print("enemy fusion: Fusion card '%s' has no TextureRect node." % candidate_data.name)

func _on_fusion_card_selected(event, fusion_card_instance):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if descriptive_box:
				descriptive_box.show_creature_info(fusion_card_instance.card_data)
				print("enemy fusion: Displayed stats for fusion card:", fusion_card_instance.card_data.name)
			accept_event()  # Consume the event to prevent further processing
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if is_fusion_in_progress:
				print("enemy fusion: Fusion already in progress, skipping event.")
				accept_event()
				return
			is_fusion_in_progress = true
			if hand_manager:
				# We need hand_manager for this specific function, but we didn't set it on the card
				# to prevent default highlighting behavior
				hand_manager.handle_fusion_selection(fusion_card_instance)
			if hand_manager.get_hand_size() < hand_manager.MAX_CARDS:
				emit_signal("fusion_selected", fusion_card_instance.card_data)
				print("enemy fusion: Fusion card selected and signal emitted for:", fusion_card_instance.card_data.name)
			else:
				print("enemy fusion: Hand is full! Cannot add fusion card.")
			_clear_fusion_menu()
			accept_event()
			is_fusion_in_progress = false



func _clear_fusion_menu():
	print("enemy fusion: Clearing and hiding fusion menu")
	visible = false
	fusion_options.clear()
	for child in get_children():
		child.queue_free()
	print("enemy fusion: Fusion menu cleared and hidden.")
