extends Node


#signal creature_clicked
var card_factory  # Reference to the card factory
var hand_manager  # We'll assign the hand manager in _ready()
#var data_collector  # Reference to the data collector
var initial_hand_size = 4  # Number of cards to start with
var discard_pile = []  # Array to track cards that have been played (discard pile)
# A flag to track if a card is being processed (draw, play, or refill)
var is_processing_card = false
var game_started = false  # Prevents gameplay before deck selection

const MAX_DECK_SIZE = 10
var summon_cooldown: float = 3.0  # seconds between summons
var summon_timer: float = 0.0     # current cooldown timer
# AI control
var enemy_ai_enabled: bool = true  # Set to true to enable AI, false for manual control
var enemy_ai = null                # Reference to the EnemyAI instanc
var spell_manager
var hero = null
var hero_scene = preload("res://Scenes/Hero.tscn")

@onready var cooldown_indicator = $SummonCooldownIndicator

@onready var hand_manager_class = preload("res://Scripts/handmanager.gd")
#@onready var data_collector_class = preload("res://Scripts/data_collector.gd")

@onready var board_panel = $BoardPanel  # Reference to the board panel (where cards are played)
@onready var fusion_menu = $FusionMenu  # Corrected path since FusionMenu is a direct child of Control (root node)
@onready var hand_container = $Hand  # The Control node where cards will be displayed
#@onready var draw_card_timer = $DrawCardTimer  # Reference to the Timer node
@onready var descriptive_box = $DescriptiveBox # Ensure this path matches your actual scene setup
@onready var enemy_hand = preload("res://Scripts/EnemyHand.gd").new()

var debug_mode = false  # Set to false by default, change to true only when needed

func debug_print(message):
	if debug_mode:
		print(message)
		

func _ready():
	

	
	# 1. Connect global signals.
	GlobalSignals.connect("card_clicked", Callable(self, "_on_card_clicked"))
	
	# 2. Get reference to global card factory FIRST - this is critical
	card_factory = get_node("/root/cardfactory")
	if not card_factory:
		print("ERROR: cardfactory not found!")
		return  # Exit early if we can't find the card factory
		
	print("GlobalCardFactory found and assigned")
	
	# 3. Retrieve DescriptiveBox and FusionMenu
	descriptive_box = get_node_or_null("DescriptiveBox")
	if descriptive_box == null:
		print("DescriptiveBox not found in expected location.")
	else:
		print("DescriptiveBox successfully assigned.")
	
	fusion_menu = get_node_or_null("FusionMenu")
	if fusion_menu == null:
		print("FusionMenu not assigned correctly.")
	else:
		fusion_menu.visible = false
		print("FusionMenu retrieved and hidden.")
	
	# 4. Instantiate the player hand manager
	hand_manager = hand_manager_class.new()
	hand_manager.main_node = self
	hand_manager.fusion_menu = fusion_menu
	add_child(hand_manager)
	print("Player hand manager added to Main.")
	
	# 5. Instantiate the enemy hand
	enemy_hand = preload("res://Scripts/EnemyHand.gd").new()
	enemy_hand.main_node = self
	var hand_opponent = get_node("HandOpponent")
	if hand_opponent:
		hand_opponent.add_child(enemy_hand)
		enemy_hand.position = Vector2(0, 0)
		print("Enemy hand added to HandOpponent container at position:", enemy_hand.position)
	else:
		print("HandOpponent container not found!")
	
	# 6. Load the deck from GlobalDeck
	var global_deck = get_node("/root/GlobalDeck")
	if global_deck and global_deck.player_deck.size() > 0:
		# Set up deck in card_factory from GlobalDeck
		card_factory.deck = global_deck.player_deck.duplicate()
		
		# Set up hand_manager with the same deck
		hand_manager.deck = global_deck.player_deck.duplicate()
		enemy_hand.deck = global_deck.player_deck.duplicate()
		
		print("Deck loaded from GlobalDeck: ", global_deck.player_deck.size(), " cards")
		game_started = true
	else:
		print("ERROR: No deck found in GlobalDeck!")
		return
	
	print("Hand container visible: ", hand_container.visible)
	hand_container.visible = true  # Force visibility
	
	# 7. Set up FusionMenu references
	if fusion_menu:
		fusion_menu.hand_manager = hand_manager
		fusion_menu.card_factory = card_factory
		var fusion_callable = Callable(self, "_on_fusion_selected")
		if not fusion_menu.is_connected("fusion_selected", fusion_callable):
			fusion_menu.connect("fusion_selected", fusion_callable)
			print("FusionMenu signal connected.")
	
	# 8. Initialize enemy AI if enabled
	if enemy_ai_enabled:
		var enemy_ai_script = preload("res://Scripts/EnemyAI.gd")
		enemy_ai = enemy_ai_script.new(enemy_hand, self)
		add_child(enemy_ai)
		print("Enemy AI initialized and enabled")
	
	spell_manager = load("res://Scripts/SpellManager.gd").new(self)
	add_child(spell_manager)
	
	# 9. Connect BoardPanel and start game
	board_panel = get_node("BoardPanel")
	if board_panel:
		board_panel.connect("gui_input", Callable(self, "_on_board_panel_click"))
		print("BoardPanel input connected.")
	else:
		print("BoardPanel not found!")
	
	# 10. Connect to GameStateManager
	GameStateManager.connect("phase_changed", Callable(self, "_on_phase_changed"))
	
	# 11. Start the game and draw initial hands
	start_game()
	
	# 12. Add ScriptDumper
	var script_dumper_scene = preload("C:/Users/Jacob/Desktop/summoners-guild-0.001/Scripts/script_dumper.gd")
	var script_dumper = script_dumper_scene.new()
	add_child(script_dumper)
	
	# 13. Start in Phase 1
	call_deferred("start_in_phase_one")

	# Add this at the end
	call_deferred("diagnose_game_startup")

	## In _ready() or where appropriate
	#test_draw_player_card()

## Or add a debug key in _process
	#if Input.is_action_just_pressed("ui_home"):  # Home key
		#test_draw_player_card()

func start_in_phase_one():
	print("Starting game in Phase 1: Preparation")
	# Explicitly trigger phase 1 behavior
	_on_phase_changed(GameStateManager.GameState.PHASE1_PREPARATION)

func _on_phase_changed(new_phase):
	if new_phase == GameStateManager.GameState.PHASE1_PREPARATION:
		print("PHASE 1: PREPARATION - Draw cards, fusion, and summoning")
		
		# Draw player cards up to 6 - ONLY IN PHASE 1
		var cards_drawn = 0
		while hand_manager.get_hand_size() < 6:
			var card = draw_card()
			if card:
				cards_drawn += 1
		
		print("Drew " + str(cards_drawn) + " cards for player...")
		
		# Allow enemy to draw cards too - ONLY IN PHASE 1
		var enemy_cards_drawn = 0
		while enemy_hand.get_hand_size() < 6:
			enemy_hand.draw_card()
			enemy_cards_drawn += 1
	else:
		print("PHASE 2: COMBAT - No card drawing in this phase")
	

# Add a function to toggle the AI on/off during gameplay
func toggle_enemy_ai():
	enemy_ai_enabled = !enemy_ai_enabled
	
	if enemy_ai_enabled:
		if enemy_ai == null:
			var enemy_ai_script = preload("res://Scripts/EnemyAI.gd")
			enemy_ai = enemy_ai_script.new(enemy_hand, self)
			add_child(enemy_ai)
		else:
			enemy_ai.set_process(true)
		print("Enemy AI enabled")
	else:
		if enemy_ai != null:
			enemy_ai.set_process(false)
		print("Enemy AI disabled")
	
	return enemy_ai_enabled


func _on_deck_selected(selected_deck):
	card_factory.deck = selected_deck
	hand_manager.deck = selected_deck
	enemy_hand.deck = selected_deck.duplicate()
	print("Deck selection complete. Starting game with:", selected_deck)
	game_started = true
	start_game()
	get_node("DeckSelectionMenu").queue_free()
	
	var deck_selection = get_node("DeckSelectionMenu")
	if deck_selection:
		deck_selection.queue_free()





func _process(_delta):
	if not game_started:
		return  # Do nothing if the game hasn't started

	if Input.is_action_just_pressed("ui_accept"):  # Spacebar
		print("Spacebar pressed. Drawing a card...")
		draw_card()

#region New Code Region
	if Input.is_action_just_pressed("ui_select"):  # Enter key
		print("Enter pressed. Refilling the deck...")
		refill_deck_from_discard()
 
	if summon_timer > 0.0:
		summon_timer -= _delta
		
		
		# Update the cooldown indicator if one card is highlighted.

	if hand_manager.get_highlighted_card_count() == 1:
		cooldown_indicator.visible = true
		# Assuming summon_timer and summon_cooldown are updated elsewhere,
		# compute progress as a fraction (1 means cooldown finished)
		var new_progress = 1.0 - (summon_timer / summon_cooldown)
		cooldown_indicator.update_progress(new_progress)
	else:
		cooldown_indicator.visible = false


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
#endregion
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


# In Main.gd - Update the _on_board_panel_click with additional debugging
func _on_board_panel_click(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		var click_position_local = board_panel.get_local_mouse_position()
		
		if hero and hero.is_selected and event.button_index == MOUSE_BUTTON_RIGHT:
			if not GameStateManager.is_preparation_phase():
				var clicked_enemy = get_creature_at_click_position(click_position_local)
				
				print("Clicked position: " + str(click_position_local))
				print("Found clicked creature: " + (clicked_enemy.name if clicked_enemy else "None"))
				
				if clicked_enemy and clicked_enemy.is_in_group("enemy_creatures"):
					# Attack command - directly set the attack target
					print("Setting hero attack target to: " + clicked_enemy.name)
					hero.attack_target = clicked_enemy
					
					# Force update attack timer to enable immediate attack
					hero.attack_timer = 0
					
					# Check if already in range
					var distance = hero.global_position.distance_to(clicked_enemy.global_position)
					print("Distance to enemy: " + str(distance) + ", hero attack range: " + str(hero.attack_range))
					
					if distance <= hero.attack_range:
						# Already in range, clear movement target
						hero.move_target = Vector2.ZERO
						print("Enemy in range, attacking")
					else:
						# Not in range, move towards target
						print("Enemy out of range, moving to attack")
						hero.move_target = clicked_enemy.global_position
				else:
					# Move command
					hero.attack_target = null  # Clear attack target
					var target_global_position = board_panel.global_position + click_position_local
					hero.move_target = target_global_position
					print("Setting move target to: " + str(target_global_position))
			else:
				print("Cannot control hero during preparation phase")
		else:
			if event.button_index == MOUSE_BUTTON_LEFT:
			# Check if a player card is highlighted
				if hand_manager.get_highlighted_card_count() == 1 and not is_processing_card:
					var highlighted_card = hand_manager.get_highlighted_card()
				
				# Check the card type to determine behavior
					if highlighted_card.card_data.card_type == "spell":
					# Handle spell casting
						call_deferred("cast_player_spell", click_position_local)
					else:
					# Handle creature summoning (original behavior)
						call_deferred("play_card", click_position_local, false)
				else:
					print("No player card selected for action.")
				
			elif event.button_index == MOUSE_BUTTON_RIGHT:
			# Right click for enemy action
				if enemy_hand.selected_cards.size() == 1 and not is_processing_card:
					var selected_card = enemy_hand.selected_cards[0]
				
				# Check if it's a spell or creature
					if selected_card.card_data.card_type == "spell":
						call_deferred("cast_enemy_spell", click_position_local)
					else:
						call_deferred("enemy_play_card", click_position_local)
			else:
				print("No enemy card selected for action.")


# Add this property to Main.gd if it doesn't exist
var enemy_discard_pile = []

# Update get_creature_at_click_position in Main.gd
func get_creature_at_click_position(click_position: Vector2) -> Node:
	var space_state = board_panel.get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	
	# Convert to global position for the query
	var global_click_position = board_panel.global_position + click_position
	query.position = global_click_position
	query.collide_with_areas = true
	
	print("Checking for creature at global position: " + str(global_click_position))
	
	var results = space_state.intersect_point(query)
	print("Found " + str(results.size()) + " results at click position")
	
	for result in results:
		var collider = result.collider
		print("Checking collider: " + collider.name + ", groups: " + str(collider.get_groups()))
		
		if collider and (collider.is_in_group("ally_creatures") or collider.is_in_group("enemy_creatures")):
			print("Found creature: " + collider.name)
			return collider
			
	return null
	
	
	
func cast_player_spell(click_position: Vector2):
	if is_processing_card:
		return
	
	is_processing_card = true
	var played_card = hand_manager.get_highlighted_card()

	if played_card:
		print("Casting player spell: %s" % played_card.card_data.name)

		# Instance the spell scene
		var spell_scene = preload("res://Scenes/Spell.tscn").instantiate()
		
		# Make sure to initialize with proper groups (update Spell.gd's initialize method)
		spell_scene.initialize(played_card.card_data, click_position, false)
		board_panel.add_child(spell_scene)
		
		# Remove the card from hand
		hand_manager.remove_card(played_card)
		hand_manager.remove_from_selected(played_card)
		
		# Add to discard pile
		discard_pile.append(played_card.card_data)
		played_card.queue_free()
	else:
		print("No spell card selected to cast.")

	is_processing_card = false

# Add this function to cast enemy spells
func cast_enemy_spell(click_position: Vector2):
	# Important debugging
	print("cast_enemy_spell called with position:", click_position)
	
	if is_processing_card:
		return
	
	is_processing_card = true
	
	if enemy_hand.selected_cards.size() > 0:
		var selected_card = enemy_hand.selected_cards[0]

		if selected_card:
			print("Casting enemy spell:", selected_card.card_data.name)

			# Instance the spell scene
			var spell_scene = preload("res://Scenes/Spell.tscn").instantiate()
			
			# Initialize with enemy flag set to true
			spell_scene.initialize(selected_card.card_data, click_position, true)
			board_panel.add_child(spell_scene)
			
			# Remove the card from enemy hand
			enemy_hand.remove_card(selected_card)
			enemy_hand.selected_cards.clear()
			
			# Add the card to enemy discard pile
			enemy_discard_pile.append(selected_card.card_data)
			
			# Free the card instance
			selected_card.queue_free()
		else:
			print("No enemy spell card selected to cast.")
	else:
		print("No card selected in enemy hand.")

	is_processing_card = false

func enemy_play_card(click_position: Vector2):
	if not GameStateManager.is_preparation_phase():
		print("Cannot summon enemy creatures during combat phase")
		return

	print("AI: enemy_play_card called with position:", click_position)
	is_processing_card = true
	
	# Get the card from the enemy hand
	if enemy_hand.selected_cards.size() > 0:
		var card_instance = enemy_hand.selected_cards[0]
		var card_data = card_instance.card_data
		
		print("AI: Processing card:", card_data.name, "Type:", card_data.card_type)
		
		# CRITICAL CHECK: Prevent spell cards from being summoned as creatures
		if card_data.card_type == "spell":
			print("AI: Detected spell card, redirecting to cast_enemy_spell")
			# Handle as a spell instead
			cast_enemy_spell(click_position)
			is_processing_card = false
			return
		elif card_data.card_type != "creature":
			print("AI: WARNING - Card type is neither 'spell' nor 'creature', treating as creature:", card_data.card_type)
		
		print("AI: Processing as creature card for summoning")
		# If it's a creature card, proceed with normal summoning
		# Try to summon the creature
		if summon_creature(card_data, click_position, true):  # true means it's an enemy summon
			# Remove the card from the enemy hand
			enemy_hand.remove_card(card_instance)
			enemy_hand.selected_cards.clear()
			
			# Add the card to enemy discard pile
			enemy_discard_pile.append(card_data)
			
			# Remove the card instance from scene
			card_instance.queue_free()
			
			print("AI: Enemy creature summoned successfully at position", click_position)
		else:
			print("AI: Enemy summoning failed for card:", card_data.name)
			
			# IMPORTANT: Clear the selection if summoning fails
			enemy_hand.selected_cards.clear()
	else:
		print("AI: No card selected in enemy hand")
	
	is_processing_card = false
	
	
func refill_enemy_deck_from_discard():
	if enemy_discard_pile.size() > 0:
		print("Refilling enemy deck with enemy discard pile.")

		for card_data in enemy_discard_pile:
			enemy_hand.deck.append(card_data)
			print("Added back to enemy deck:", card_data.name)

		enemy_hand.deck.shuffle()
		enemy_discard_pile.clear()
		print("Enemy discard pile cleared after refill.")
	else:
		print("Enemy discard pile is empty, nothing to refill.")

# Modified play_card function to accept an argument indicating if it's targeting ally
func play_card(click_position: Vector2, reverse_path: bool):


		# Only allow summoning during Phase 1
	if not GameStateManager.is_preparation_phase():
		print("Cannot summon during combat phase")
		return
	
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
			# Set the player's summon cooldown here
			summon_timer = summon_cooldown
		else:
			print("Summoning failed, card will not be removed.")
	else:
		print("No card selected to play.")

	is_processing_card = false



# This function is shared between both hands.
# reverse_path = true means “enemy” summoning; false means “player” summoning.
func summon_creature(card_data: carddata, click_position: Vector2, reverse_path: bool) -> bool:
	# For player summoning (reverse_path false), check and set the global cooldown.
	if not GameStateManager.is_preparation_phase():
		print("Cannot summon creatures during combat phase")
		return false

	if not reverse_path:
		if summon_timer > 0.0:
			print("Summon is on cooldown. Please wait", summon_timer, "seconds.")
			return false
		summon_timer = summon_cooldown
	# For enemy summoning, we bypass the global cooldown check.
	var creature_scene = preload("res://Scenes/Creature.tscn").instantiate()
	print("Instantiated creature type:", creature_scene.get_class())
	creature_scene.connect("creature_clicked", Callable(self, "_on_creature_clicked"))
	print("Connected creature_clicked for creature:", creature_scene.name)
	
	# Initialize the creature with the card data.
	creature_scene.initialize_with_card_data(card_data)
	print("Click position:", click_position)
	
	creature_scene.target_ally = reverse_path  # reverse_path true means enemy summon.
	
	var summon_allowed = false
	if reverse_path:
		# Enemy summoning: use the AllySummonerShield node so that the creature becomes an enemy.
		creature_scene.opponent_summoner = $BoardPanel/AllySummonerShield
		creature_scene.add_to_group("enemy_creatures")
		summon_allowed = is_in_valid_summon_zone(click_position, "/root/Control/BoardPanel/OpponentSummonerShield/OpponentInitialSummonZone2D", "enemy_creatures")
	else:
		# Player summoning: use the OpponentSummonerShield node.
		creature_scene.opponent_summoner = $BoardPanel/OpponentSummonerShield
		creature_scene.add_to_group("ally_creatures")
		summon_allowed = is_in_valid_summon_zone(click_position, "/root/Control/BoardPanel/AllySummonerShield/AllyInitialSummonZone2D", "ally_creatures")
	
	if summon_allowed:
		creature_scene.global_position = click_position
		$BoardPanel.add_child(creature_scene)
		creature_scene.connect("input_event", Callable(self, "_on_creature_input_event"))
		
		# Set initial frozen state based on current game phase
		creature_scene.is_frozen = GameStateManager.is_preparation_phase()
		if creature_scene.is_frozen:
			print("Creature summoned in preparation phase - starting in frozen state")
		
		print("Summon successful.")
		return true
	else:
		print("Summoning not allowed. Invalid summoning zone.")
		return false

# This function is meant for the enemy hand.
# It computes a random valid summon position within the enemy's allowed zone, then
# calls summon_creature() with reverse_path = true.
func summon_enemy_card(card_data: carddata) -> void:
	var enemy_zone = get_node_or_null("/root/Control/BoardPanel/OpponentSummonerShield/OpponentInitialSummonZone2D") as Area2D
	if enemy_zone:
		# Assume enemy_zone has a CollisionShape2D child with a CircleShape2D.
		var shield_collision = enemy_zone.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shield_collision and shield_collision.shape is CircleShape2D:
			var radius = shield_collision.shape.radius
			var center = enemy_zone.global_position
			# Pick a random point within the circle:
			var angle = randf() * TAU
			var dist = randf() * radius
			var random_offset = Vector2(cos(angle), sin(angle)) * dist
			var click_position = center + random_offset
			print("EnemyHand: Chosen random enemy summon position: ", click_position)
			
			# Use reverse_path = true so that summon_creature treats this as an enemy summon.
			if summon_creature(card_data, click_position, true):
				print("EnemyHand: Summon successful for ", card_data.name)
				# (Here you would remove the card from the enemy hand, add it to discard, etc.)
			else:
				print("EnemyHand: Summon failed for ", card_data.name)
		else:
			print("EnemyHand: No valid CollisionShape2D with a CircleShape2D found in enemy summon zone.")
	else:
		print("EnemyHand: OpponentInitialSummonZone2D not found!")



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
		enemy_hand.draw_card()  # This draws for the enemy hand.


func draw_card():
	# Use card_factory's draw_card method which has proper empty checks
	var card_instance = card_factory.draw_card()
	
	if card_instance:
		# Configure the card
		card_instance.hand_manager = hand_manager
		
		# Add to the hand manager's list
		hand_manager.add_card(card_instance)
		
		# Add directly to Main
		add_child(card_instance)
		
		# Position cards after adding this new one
		position_cards_centered()
		
		print("Player card added to Main node at position:", card_instance.position)
		return card_instance
	else:
		print("Failed to create card instance - deck may be empty")
		
		# Try to refill the deck if possible
		if card_factory.deck.size() == 0 && discard_pile.size() > 0:
			print("Attempting to refill deck from discard pile...")
			refill_deck_from_discard()
			
			# Try drawing again if refill was successful
			if card_factory.deck.size() > 0:
				return draw_card()  # Recursive call to try again after refill
		
		return null


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

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_P:  # Use any key you want
			toggle_enemy_ai()
			print("Enemy AI: " + ("Enabled" if enemy_ai_enabled else "Disabled"))


# Function to position cards symmetrically in the hand
func position_cards_centered():
	var hand_size = hand_manager.get_hand_size()
	if hand_size == 0:
		return
		
	var card_width = 100
	var spacing = 10
	var total_width = hand_size * card_width + (hand_size - 1) * spacing

	# Important: Use hand_container's position as the reference point
	var hand_pos = hand_container.global_position
	print("Hand container position:", hand_pos)
	
	var hand_width = hand_container.size.x
	var start_x = hand_pos.x + (hand_width - total_width) / 2
	
	print("Positioning cards at Y=", hand_pos.y, " starting X=", start_x)
	
	for i in range(hand_size):
		var card = hand_manager.card_list[i]
		card.global_position = Vector2(start_x + i * (card_width + spacing), hand_pos.y)
		print("Card", i, "positioned at", card.global_position)

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
		
# When the game starts
# Add to your existing start_game function
func start_game():
	if game_started:
		print("Game has started!")
		
		# Start in preparation phase (Phase 1)
		GameStateManager.transition_to_phase1()
		spawn_hero()
		print("Drawing initial cards - PLAYER")
		# Draw player cards to 6
		for i in range(6):
			if hand_manager.get_hand_size() < 6:
				var card = draw_card()
				if card:
					print("Drew player card successfully: " + card.card_data.name)
				else:
					print("Failed to draw player card at index " + str(i))
		
		print("Drawing initial cards - ENEMY")
		# Draw enemy cards to 6
		for i in range(6):
			if enemy_hand.get_hand_size() < 6:
				var enemy_card = enemy_hand.draw_card()
				if enemy_card:
					print("Drew enemy card successfully")
				else:
					print("Failed to draw enemy card at index " + str(i))
		
		print("Initial hands drawn - Player: " + str(hand_manager.get_hand_size()) + ", Enemy: " + str(enemy_hand.get_hand_size()))
	else:
		print("Game not started.")
		
		
		
func spawn_hero():
	# First check if hero already exists
	if hero != null and is_instance_valid(hero):
		print("Hero already exists")
		return
		
	# Create the hero instance
	hero = hero_scene.instantiate()
	
	# Get the player's hero card data
	var hero_card_data = load("res://CardData/lvl3 Devilspawn leader (Green.tres")  # Choose appropriate card
	
	# Initialize the hero with card data
	hero.initialize_with_card_data(hero_card_data)
	# Position the hero near the ally summoner shield
	var ally_shield = $BoardPanel/AllySummonerShield
	hero.global_position = ally_shield.global_position + Vector2(100, 0)
	
	# Add the hero to the board
	$BoardPanel.add_child(hero)
	
	print("Hero spawned at position:", hero.global_position)

	# Connect hero signals
	hero.connect("creature_clicked", Callable(self, "_on_creature_clicked"))
	
	
	
