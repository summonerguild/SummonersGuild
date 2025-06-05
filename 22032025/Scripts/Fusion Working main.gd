extends Node


#signal creature_clicked
var card_factory  # Reference to the card factory
var hand_manager  # We'll assign the hand manager in _ready()
#var data_collector  # Reference to the data collector
var initial_hand_size = 5  # Number of cards to start with
var discard_pile = []  # Array to track cards that have been played (discard pile)
# A flag to track if a card is being processed (draw, play, or refill)
var is_processing_card = false
var game_started = false  # Prevents gameplay before deck selection




@onready var hand_manager_class = preload("res://Scripts/handmanager.gd")
#@onready var data_collector_class = preload("res://Scripts/data_collector.gd")
@onready var card_factory_class = preload("res://Scripts/cardfactory.gd")
@onready var board_panel = $BoardPanel  # Reference to the board panel (where cards are played)
@onready var fusion_menu = $FusionMenu  # Corrected path since FusionMenu is a direct child of Control (root node)
@onready var hand_container = $Hand  # The Control node where cards will be displayed
@onready var draw_card_timer = $DrawCardTimer  # Reference to the Timer node
@onready var descriptive_box = $DescriptiveBox # Ensure this path matches your actual scene setup


func _ready():
	# 1) Connect global signals if needed.
	GlobalSignals.connect("card_clicked", Callable(self, "_on_card_clicked"))

	# 2) Create the CardFactory BEFORE the deck selection menu.
	card_factory = card_factory_class.new()
	add_child(card_factory)
	card_factory.setup_deck()

	# 3) Now instantiate DeckSelectionMenu, pass the non-null card_factory
	var deck_selection_scene = preload("res://Scenes/DeckSelectionMenu.tscn").instantiate()
	deck_selection_scene.card_factory = card_factory
	add_child(deck_selection_scene)

	deck_selection_scene.connect("deck_selected", Callable(self, "_on_deck_selected"))

	# 4) (The rest of your code)    
	descriptive_box = get_node_or_null("DescriptiveBox")
	if descriptive_box == null:
		print("DescriptiveBox not found in expected location.")
	else:
		print("DescriptiveBox successfully assigned.")

	print(fusion_menu)
	if fusion_menu == null:
		print("FusionMenu not assigned correctly.")
	else:
		fusion_menu.visible = false
		#fusion_menu.position = Vector2(get_viewport().size.x - fusion_menu.size.x - 340, 750)

	# Initialize the HandManager
	hand_manager = hand_manager_class.new()
	add_child(hand_manager)
	hand_manager.main_node = self
	hand_manager.fusion_menu = fusion_menu

	# Avoid double-connecting if it’s already connected:
	if fusion_menu and hand_manager:
		# Create a single Callable for reuse
		var fusion_callable = Callable(self, "_on_fusion_selected")
		if not fusion_menu.is_connected("fusion_selected", fusion_callable):
			fusion_menu.connect("fusion_selected", fusion_callable)
	else:
		print("Error: hand_manager or fusion_menu is not assigned")


	# Start the timer
	draw_card_timer.start()
	print("Timer started")


	# Ensure the HandManager and FusionMenu are assigned correctly
	if fusion_menu and hand_manager:
		fusion_menu.hand_manager = hand_manager
		fusion_menu.connect("fusion_selected", Callable(self, "_on_fusion_selected"))
	else:
		print("Error: hand_manager or fusion_menu is not assigned")

	# Ensure the Fusion Menu has access to the CardFactory
	if fusion_menu and card_factory:
		fusion_menu.card_factory = card_factory
	else:
		print("Error: fusion_menu or card_factory not assigned")

	# Initialize the DataCollector
#	data_collector = data_collector_class.new()
#	add_child(data_collector)

	# Log initialization data
#	data_collector.write_log("Card draw system initialized.")
#	data_collector.write_log("Starting hand size: %d" % hand_manager.get_hand_size())

	# Connect the board panel to handle clicks for playing cards
	board_panel.connect("gui_input", Callable(self, "_on_board_panel_click"))

	# Draw the initial hand of cards
	draw_initial_hand()
	
	
func _on_deck_selected(selected_deck):
	# Set the player's deck from the selection
	card_factory.deck = selected_deck
	print("Deck selection complete. Starting game with:", selected_deck)

	# Now allow the game to start
	game_started = true  
	start_game()

	# Remove the selection menu
	get_node("DeckSelectionMenu").queue_free()


func _process(_delta):
	if not game_started:
		return  # Do nothing if the game hasn't started

	if Input.is_action_just_pressed("ui_accept"):  # Spacebar
		print("Spacebar pressed. Drawing a card...")
		draw_card()

	if Input.is_action_just_pressed("ui_select"):  # Enter key
		print("Enter pressed. Refilling the deck...")
		refill_deck_from_discard()

func get_collision_shape_rect(collision_shape: CollisionShape2D) -> Rect2:
	if collision_shape.shape is RectangleShape2D:
		var rect_shape = collision_shape.shape as RectangleShape2D
		var extents = rect_shape.extents
		
		# Just use the global_position as the origin
		var top_left = collision_shape.global_position - extents
		
		print("Global position:", collision_shape.global_position)
		print("Top left corner of lane:", top_left)
		print("Extents:", extents)

		return Rect2(top_left, extents * 2)  # Create a Rect2 with the full size
	else:
		print("Warning: Lane is not using a RectangleShape2D.")
		return Rect2()  # Default if it's not a rectangular shape



# Function to check if the click is inside any wall area
func is_in_wall_area(click_position: Vector2) -> bool:
	# Convert UI position to world position relative to BoardPanel
	var world_click_position = $BoardPanel.get_global_mouse_position()

	# Get the physics state from the BoardPanel (which is in the 2D world)
	var space_state = $BoardPanel.get_world_2d().direct_space_state

	# Prepare the point query parameters
	var point_query = PhysicsPointQueryParameters2D.new()
	point_query.position = world_click_position
	point_query.collide_with_bodies = true  # Only collide with bodies, not areas
	point_query.collision_mask = 1  # Assuming wall is on layer 1, adjust as needed

	# Perform the point query to check for collisions with StaticBody2D (walls)
	var results = space_state.intersect_point(point_query)

	# Check if any of the collisions are with Wall1 or Wall2
	for result in results:
		var collider = result.collider
		if collider == $BoardPanel/Wall1 or collider == $BoardPanel/Wall2:
			print("Cannot summon on Wall", collider.name)
			return true

	return false





# Function to check if the click is inside any shield area
func is_in_shield_area(click_position: Vector2) -> bool:
	# Convert UI position to world position relative to BoardPanel
	var world_click_position = $BoardPanel.get_global_mouse_position()

	# List of shields to check (both ally and opponent)
	var shields = [
		$BoardPanel/AllySummonerShield,
		$BoardPanel/OpponentSummonerShield
	]

	# Iterate through each shield and check for collision
	for shield in shields:
		if shield:
			var collision_shape = shield.get_node("CollisionShape2D").shape
			if collision_shape is CircleShape2D:
				var radius = (collision_shape as CircleShape2D).radius
				var center = shield.global_position  # Use the shield's global position for Area2D nodes

				# Check if the world click is inside the shield's radius
				if world_click_position.distance_to(center) <= radius:
					return true
		else:
			print("Error: Shield node not found")

	return false




# Handle clicks on the board panel to play cards

## Handle clicks on the board panel to either play cards or summon creatures
#func _on_board_panel_click(event):
	#if event is InputEventMouseButton and event.pressed:
		#var click_position_local = $BoardPanel.get_local_mouse_position()
#
		## Check if a card is selected, and proceed with summoning logic
		#if hand_manager.get_highlighted_card_count() > 0 and not is_processing_card:
			## If a card is selected, handle card playing or summoning
			#if event.button_index == MOUSE_BUTTON_LEFT:
				#call_deferred("play_card", click_position_local, false)  # False for opponent targeting
			#elif event.button_index == MOUSE_BUTTON_RIGHT:
				#call_deferred("play_card", click_position_local, true)  # True for ally targeting
		#else:
			## No card is selected, so we’re likely just clicking to select a creature
			## The `_on_creature_input_event` function will handle showing creature info if clicked
			#print("No card selected; ready to display creature info if a creature is clicked.")
			## We do not need to do anything further here for creature selection


func _on_board_panel_click(event):
	if event is InputEventMouseButton and event.pressed:
		# Get the click position in BoardPanel's local coordinate space.
		var click_position_local = board_panel.get_local_mouse_position()
		print("Click position (BoardPanel local):", click_position_local)
		
		if hand_manager.get_highlighted_card_count() == 1 and not is_processing_card:
			if event.button_index == MOUSE_BUTTON_LEFT:
				call_deferred("play_card", click_position_local, false)  # False for opponent targeting
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				call_deferred("play_card", click_position_local, true)   # True for ally targeting
		else:
			print("Invalid selection: ensure only one card is highlighted to summon.")










# Modified play_card function to accept an argument indicating if it's targeting ally
func play_card(click_position: Vector2, reverse_path: bool):
	if is_processing_card:
		return  # Skip if another operation is in progress

	is_processing_card = true
	var played_card = hand_manager.get_highlighted_card()

	if played_card:
		print("Playing card: %s" % played_card.card_data)

		# Summon the creature and only remove the card if summoning is successful
		var summon_successful = summon_creature(played_card.card_data, click_position, reverse_path)
		
		if summon_successful:
			hand_manager.remove_card(played_card)
			hand_manager.remove_from_selected(played_card)
			discard_pile.append(played_card.card_data)
			played_card.queue_free()  # Only free the card if summon was successful
		else:
			print("Summoning failed, card will not be removed.")
	else:
		print("No card selected to play.")

	is_processing_card = false


func summon_creature(card_data: carddata, click_position: Vector2, reverse_path: bool) -> bool:
	var creature_scene = preload("res://Scenes/Creature.tscn").instantiate()
	print("Instantiated creature type:", creature_scene.get_class())  # Should print "Area2D"
# Connect the creature_clicked signal to the handler in Main
	creature_scene.connect("creature_clicked", Callable(self, "_on_creature_clicked"))
	print("Connected input_event for creature:", creature_scene.name)

	# Initialize the creature with the card data
	creature_scene.initialize_with_card_data(card_data)

	print("Click position:", click_position)

	creature_scene.target_ally = reverse_path

	var summon_allowed = false

	if reverse_path:
		creature_scene.opponent_summoner = $BoardPanel/AllySummonerShield
		creature_scene.add_to_group("enemy_creatures")
		summon_allowed = is_in_valid_summon_zone(click_position, "/root/Control/BoardPanel/OpponentSummonerShield/OpponentInitialSummonZone2D", "enemy_creatures")
	else:
		creature_scene.opponent_summoner = $BoardPanel/OpponentSummonerShield
		creature_scene.add_to_group("ally_creatures")
		summon_allowed = is_in_valid_summon_zone(click_position, "/root/Control/BoardPanel/AllySummonerShield/AllyInitialSummonZone2D", "ally_creatures")

	if summon_allowed:
		creature_scene.global_position = click_position
		$BoardPanel.add_child(creature_scene)
		
		# Connect directly from the creature_scene (as it's already an Area2D)
		creature_scene.connect("input_event", Callable(self, "_on_creature_input_event"))
		print("Connected input_event for creature:", creature_scene.name)

		print("Summon successful.")
		return true
	else:
		print("Summoning not allowed. Invalid summoning zone.")
		return false



func is_in_valid_summon_zone(click_position: Vector2, initial_zone_name: String, creature_group: String) -> bool:
	# Get the initial summon zone node from BoardPanel.
	var zone: Area2D = board_panel.get_node(initial_zone_name) as Area2D
	var zone_pos_local: Vector2 = Vector2.ZERO  # Declare variable
	if zone:
		# Convert zone's global position to BoardPanel local space by subtracting board_panel's global position.
		zone_pos_local = zone.global_position - board_panel.global_position
		print("Found initial summon zone:", initial_zone_name, "at BoardPanel local position", zone_pos_local)
	else:
		print("Error: Initial summon zone not found:", initial_zone_name)
		return false

	# Check the collision shape for the initial zone.
	if zone.has_node("CollisionShape2D"):
		var collision_shape = zone.get_node("CollisionShape2D").shape
		if collision_shape:
			print("Checking collision shape for initial zone:", collision_shape)
			if collision_shape is RectangleShape2D:
				var rect = Rect2(zone_pos_local - collision_shape.extents, collision_shape.extents * 2)
				if rect.has_point(click_position):
					print("Inside initial summon zone (rectangle).")
					return true
			elif collision_shape is CircleShape2D:
				if zone_pos_local.distance_to(click_position) <= collision_shape.radius:
					print("Inside initial summon zone (circle).")
					return true
		else:
			print("Error: No valid collision shape in initial zone.")
	else:
		print("Error: No CollisionShape2D found in initial zone.")

	# Next, check nearby creature summon zones.
	print("Checking nearby creature summon zones...")
	var creatures = get_tree().get_nodes_in_group(creature_group)
	for creature in creatures:
		if creature.has_node("SummonZone"):
			var summon_zone = creature.get_node("SummonZone") as Area2D
			if summon_zone.has_node("CollisionShape2D"):
				var summon_shape = summon_zone.get_node("CollisionShape2D").shape
				# Convert the summon zone's global position into BoardPanel local coordinates.
				var sz_local: Vector2 = summon_zone.global_position - board_panel.global_position
				if summon_shape:
					if summon_shape is RectangleShape2D:
						var rect = Rect2(sz_local - summon_shape.extents, summon_shape.extents * 2)
						if rect.has_point(click_position):
							print("Inside creature summon zone (rectangle) of", creature.name)
							return true
					elif summon_shape is CircleShape2D:
						if sz_local.distance_to(click_position) <= summon_shape.radius:
							print("Inside creature summon zone (circle) of", creature.name)
							return true
			else:
				print("Creature", creature.name, "has no CollisionShape2D on its SummonZone.")
	print("Summoning not allowed. Click is outside valid zones.")
	return false




# Helper function to check if a point is inside a creature's summon zone
func is_in_summon_area(summon_zone: Area2D, click_position: Vector2) -> bool:
	var collision_shape = summon_zone.get_node("CollisionShape2D").shape

	if collision_shape is RectangleShape2D:
		# Calculate the bounding box of the summon zone
		var rect_shape = collision_shape as RectangleShape2D
		var zone_extents = rect_shape.extents
		var zone_position = summon_zone.global_position - zone_extents

		var summon_rect = Rect2(zone_position, zone_extents * 2)

		if summon_rect.has_point(click_position):
			return true
	elif collision_shape is CircleShape2D:
		# Check for a circle-based summon zone
		var circle_shape = collision_shape as CircleShape2D
		var zone_radius = circle_shape.radius
		if click_position.distance_to(summon_zone.global_position) <= zone_radius:
			return true

	return false



# Helper function to check if a point is inside a shield's summon zone
func is_in_shield_zone(click_position: Vector2, shield: Node) -> bool:
	if shield and shield.has_node("CollisionShape2D"):
		var collision_shape = shield.get_node("CollisionShape2D").shape
		if collision_shape is CircleShape2D:
			var radius = (collision_shape as CircleShape2D).radius
			var center = shield.global_position
			# Check if click is within shield's radius
			if click_position.distance_to(center) <= radius:
				return true
	return false



# Draw the initial hand of cards at the start of the game
func draw_initial_hand():
	for i in range(initial_hand_size):
		draw_card()
#	data_collector.write_log("Initial hand of %d cards drawn" % initial_hand_size)

# Handle the selection of a fusion card from the fusion menu
func _on_fusion_selected(fusion_card_data: carddata):
	print("Creating fusion card from factory")
	
	# Create the fusion card using the CardData
	var fusion_card = card_factory.create_card(fusion_card_data)
	
	if fusion_card != null:
		fusion_card.hand_manager = hand_manager
		hand_manager.add_card(fusion_card)
		hand_container.add_child(fusion_card)  # Add the fusion card to the scene
		position_cards_centered()
		print("Fusion card added to hand: ", fusion_card.card_data)
		hand_manager.handle_fusion_selection(fusion_card)
	else:
		print("Error: Fusion card creation failed.")

func _on_draw_card_timer_timeout() -> void:
		draw_card()

# Draw a card from the deck without interacting with the refill
func draw_card():
	if not game_started:
		print("Game has not started yet! Select your deck first.")
		return  # Stop execution if the game hasn't started

	if is_processing_card:
		return  # Skip if another operation is in progress

	# Automatically refill the deck if it's empty before drawing, but don't draw any bonus cards
	if card_factory.deck.size() == 0:
		print("Deck is empty, automatically refilling from discard pile.")
		refill_deck_from_discard()

	print("Starting card draw...")
	is_processing_card = true

	# Check if hand is full before drawing
	if hand_manager.get_hand_size() < hand_manager_class.MAX_CARDS:
		print("Hand size is below max. Drawing card...")
		var new_card = card_factory.draw_card()

		if new_card != null:
			new_card.hand_manager = hand_manager
			print("Adding card to hand: ", new_card.card_data.name)
			hand_manager.add_card(new_card)
			hand_container.add_child(new_card)
			position_cards_centered()
		else:
			print("Deck is empty! No card drawn.")
	else:
		print("Hand is full! Cannot draw more cards.")

	# Reset the processing flag
	is_processing_card = false
	print("Finished card draw process.")


# Refill the deck using the discard pile without drawing cards
func refill_deck_from_discard():
	if discard_pile.size() > 0:
		print("Refilling deck with discard pile.")

		for card_data in discard_pile:
			card_factory.deck.append(card_data)
			print("Added back to deck: %s" % card_data)

		card_factory.deck.shuffle()

		# Clear the discard pile after refilling
		discard_pile.clear()
		print("Discard pile cleared after refill.")

		# Log the action
#		data_collector.write_log("Deck refilled from discard pile.")
#	else:
#		print("Discard pile is empty, nothing to refill.")
#		data_collector.write_log("Discard pile is empty, no refill done.")


# Function to position cards symmetrically in the hand
func position_cards_centered():
	var hand_size = hand_manager.get_hand_size()
	var card_width = 100
	var spacing = 10
	var total_width = hand_size * card_width + (hand_size - 1) * spacing

	var hand_rect_size = hand_container.size
	var start_x = (hand_rect_size.x - total_width) / 2

	for i in range(hand_size):
		var card = hand_manager.card_list[i]
		card.apply_position(Vector2(start_x + i * (card_width + spacing), 0))


func _on_lane_1_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		print("Click detected inside Lane 1")

func _on_lane_2_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		print("Click detected inside Lane 2")


func _on_lane_3_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		print("Click detected inside Lane 3")

func _on_card_clicked(card_data):
	if descriptive_box:
		descriptive_box.show_creature_info(card_data)
		print("Card info sent to DescriptiveBox.")
	else:
		print("Error: DescriptiveBox not found.")



# main.gd
func _on_creature_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			print("Creature clicked!")

			# Print the node type and name to debug
			print("Clicked node type:", viewport.get_class())
			print("Clicked node name:", viewport.name)

			# Check if the clicked node is the Creature node (Area2D) with exported properties
			if viewport is Area2D and viewport.has_variable("attack"):
				# Pass the creature instance to DescriptiveBox
				if descriptive_box:
					descriptive_box.show_creature_info(viewport)
					print("Creature info sent to DescriptiveBox.")
				else:
					print("Error: Descriptive box not found.")
			else:
				print("Error: Clicked node is not a creature.")


# main.gd
func _on_creature_clicked(creature: Area2D) -> void:
	if descriptive_box:
		descriptive_box.show_creature_info(creature)
		print("Creature info sent to DescriptiveBox.")
	else:
		print("Error: Descriptive box not found.")
		
func start_game():
	if game_started:
		print("Game has started!")
		draw_initial_hand()  # Now safe to draw cards
