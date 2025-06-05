extends Control

var hand_manager
var card_factory
var descriptive_box
signal fusion_selected(fusion_card_data)

var is_fusion_in_progress = false
var fusion_options: Array = []
var card_instances: Array = []

# Precompute fusion options when possible
var cached_fusion_results = {}

# Loading indicator
var loading_indicator: Control = null



#var debug_mode = false  # Set to false by default, change to true only when needed

#func debug_print(message):
	#if debug_mode:
		#print(message)

func _ready():
	z_index = 1000
	visible = false
	
	# Create a simple loading indicator
	loading_indicator = Control.new()
	loading_indicator.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading_indicator.add_child(bg)
	
	var label = Label.new()
	label.text = "Loading fusion options..."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading_indicator.add_child(label)
	
	add_child(loading_indicator)
	loading_indicator.visible = false

func populate_fusion_options(parent1_data: carddata, parent2_data: carddata):
	# Show loading indicator immediately
	visible = true
	loading_indicator.visible = true
	
	# Clear existing cards first
	clear_fusion_instances()
	
	if not hand_manager:
		print("Error: hand_manager not assigned")
		loading_indicator.visible = false
		return

	# Compute fusion options - check cache first
	var cache_key = str(parent1_data.get_instance_id()) + "_" + str(parent2_data.get_instance_id())
	
	if cached_fusion_results.has(cache_key):
		# Use cached results
		fusion_options = cached_fusion_results[cache_key]
		print("Using cached fusion options")
		call_deferred("create_fusion_cards")
	else:
		# Compute in a deferred call
		call_deferred("_compute_fusion_options", parent1_data, parent2_data, cache_key)
		
func _compute_fusion_options(parent1_data, parent2_data, cache_key):
	# Start computing fusion options
	fusion_options = card_factory.fuse_cards(parent1_data, parent2_data)
	print("Fusion options computed:", fusion_options.size())
	
	# Cache the results for future use
	cached_fusion_results[cache_key] = fusion_options
	
	if fusion_options.size() > 0:
		# Now that options are computed, create the cards
		call_deferred("create_fusion_cards")
	else:
		print("No fusion candidates found")
		loading_indicator.visible = false
		visible = false

func create_fusion_cards():
	# Create all fusion cards with proper functionality
	for i in range(fusion_options.size()):
		var candidate_data = fusion_options[i]
		
		# Use the regular create_card but optimize the process
		var fusion_card_instance = card_factory.create_card(candidate_data, true)
		fusion_card_instance.hand_manager = hand_manager
		fusion_card_instance.custom_minimum_size = Vector2(100, 150)
		fusion_card_instance.position = Vector2(i * 110, 0)
		
		# Ensure the correct connections
		if fusion_card_instance.is_connected("gui_input", Callable(fusion_card_instance, "_gui_input")):
			fusion_card_instance.disconnect("gui_input", Callable(fusion_card_instance, "_gui_input"))
		
		# Connect our custom handler
		fusion_card_instance.connect("gui_input", Callable(self, "_on_fusion_card_selected").bind(fusion_card_instance))
		
		add_child(fusion_card_instance)
		card_instances.append(fusion_card_instance)
	
	# Hide loading indicator and show the menu
	loading_indicator.visible = false
	visible = true

func clear_fusion_instances():
	# Clear existing cards
	for card in card_instances:
		if is_instance_valid(card):
			card.queue_free()
	card_instances.clear()
	
	# Also clear other children not in card_instances
	for child in get_children():
		if child != loading_indicator and not child in card_instances:
			child.queue_free()

func _on_fusion_card_selected(event: InputEvent, fusion_card_instance):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if descriptive_box:
				descriptive_box.show_creature_info(fusion_card_instance.card_data)
				print("Displayed stats for fusion card:", fusion_card_instance.card_data.name)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if is_fusion_in_progress:
				print("Fusion already in progress, skipping event.")
				accept_event()
				return
			is_fusion_in_progress = true
			if hand_manager:
				hand_manager.handle_fusion_selection(fusion_card_instance)
			if hand_manager.get_hand_size() < hand_manager.MAX_CARDS:
				emit_signal("fusion_selected", fusion_card_instance.card_data)
				print("Fusion card selected and signal emitted")
			else:
				print("Hand is full! Cannot add fusion card.")
			_clear_fusion_menu()
			accept_event()
			is_fusion_in_progress = false

func _clear_fusion_menu():
	print("Clearing and hiding fusion menu")
	visible = false
	clear_fusion_instances()
	print("Fusion menu cleared and hidden.")
