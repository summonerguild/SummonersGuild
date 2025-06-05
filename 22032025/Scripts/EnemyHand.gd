extends Control

var main_node   # Reference to Main (used for card creation)
const MAX_CARDS = 8
var card_list: Array = []
var selected_cards: Array = []
var deck: Array = []

# Enemy fusion menu variables:
var enemy_fusion_menu = null
var enemy_fusion_menu_scene = preload("res://Scenes/EnemyFusionMenu.tscn")

# Enemy summoning cooldown (separate from player)
var enemy_summon_cooldown: float = 3.0  # seconds between enemy summons
var enemy_summon_timer: float = 0.0

func add_card(card):
	if card_list.size() < MAX_CARDS:
		card_list.append(card)
		print("EnemyHand: Card added! Current hand size: %d" % card_list.size())
		position_cards_centered()
	else:
		print("EnemyHand: Hand is full! Cannot add more cards.")
	queue_redraw()

func remove_card(card):
	if card in card_list:
		card_list.erase(card)
		print("EnemyHand: Card removed! Current hand size: %d" % card_list.size())
		position_cards_centered()
	else:
		print("EnemyHand: Card not found in hand.")
	queue_redraw()

func draw_initial_hand():
	print("EnemyHand: Starting to draw initial hand. Deck size =", deck.size())
	var num_to_draw = min(4, deck.size())
	for i in range(num_to_draw):
		var card_data = deck.pop_back()
		var card_instance = main_node.card_factory.create_card(card_data, true)
		if card_instance:
			card_instance.set_card_data(card_data)
			# Disconnect default input handling so our enemy-hand handler takes over.
			var default_callable = Callable(card_instance, "_gui_input")
			if card_instance.is_connected("gui_input", default_callable):
				card_instance.disconnect("gui_input", default_callable)
			# Connect our enemy-hand-specific input handler.
			card_instance.connect("gui_input", Callable(self, "_on_enemy_card_clicked").bind(card_instance))
			
			add_card(card_instance)
			add_child(card_instance)
			print("EnemyHand: Drew enemy card:", card_data.name)
		else:
			print("EnemyHand: Failed to instance enemy card for", card_data.name)
	print("EnemyHand: Finished drawing initial hand. Remaining deck size =", deck.size())

func position_cards_centered():
	var hand_size = card_list.size()
	if hand_size == 0:
		return
	# Replicate the player hand layout: fixed card width and spacing.
	var card_width = 100
	var spacing = 10
	var total_width = hand_size * card_width + (hand_size - 1) * spacing

	# Use this enemy hand node's size.
	var hand_width = get_size().x
	var start_x = (hand_width - total_width) / 2.0

	for i in range(hand_size):
		var card = card_list[i]
		card.apply_position(Vector2(start_x + i * (card_width + spacing), 0))


# Update the draw_card function in EnemyHand.gd

func draw_card():
	# First check if deck is empty and needs refilling
	if deck.size() == 0 and main_node.enemy_discard_pile.size() > 0:
		print("Enemy deck is empty, refilling from discard pile.")
		main_node.refill_enemy_deck_from_discard()
		# Add extra logging to verify the refill worked
		print("After refill: Enemy deck size:", deck.size())
	
	# Now try to draw a card if possible
	if deck.size() > 0 and card_list.size() < MAX_CARDS:
		var card_data = deck.pop_back()
		var card_instance = main_node.card_factory.create_card(card_data, true)
		if card_instance:
			card_instance.set_card_data(card_data)
			if card_instance.is_connected("gui_input", Callable(card_instance, "_gui_input")):
				card_instance.disconnect("gui_input", Callable(card_instance, "_gui_input"))
			card_instance.connect("gui_input", Callable(self, "_on_enemy_card_clicked").bind(card_instance))
			
			add_card(card_instance)
			add_child(card_instance)
			print("EnemyHand: Drew enemy card:", card_data.name, "| Deck remaining:", deck.size())
		else:
			print("EnemyHand: Failed to instance enemy card for", card_data.name)
	else:
		if deck.size() == 0:
			print("EnemyHand: Cannot draw card: deck is empty.")
		else:
			print("EnemyHand: Cannot draw card: hand is full.")

func _on_enemy_card_clicked(event: InputEvent, card_instance):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			print("Left mouse button pressed. Processing input.")
			GlobalSignals.emit_signal("card_clicked", card_instance.card_data)

			# Only allow highlighting with left click, never unhighlighting
			if not card_instance.is_highlighted:
				if selected_cards.size() < 2:
					card_instance.toggle_highlight()
					selected_cards.append(card_instance)
					print("EnemyHand: Card highlighted. Total selected:", selected_cards.size())
					
					# If exactly two enemy cards are highlighted, open the fusion menu.
					if selected_cards.size() == 2:
						open_enemy_fusion_menu()
				else:
					print("EnemyHand: Only two cards can be selected for fusion.")
			
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			print("Right mouse button pressed. Unhighlighting card.")

			if card_instance.is_highlighted:
				card_instance.toggle_highlight()
				selected_cards.erase(card_instance)
				print("EnemyHand: Card unhighlighted. Total selected:", selected_cards.size())
				
				# Close fusion menu if open and fewer than 2 cards selected
				if selected_cards.size() < 2:
					close_enemy_fusion_menu()
			
			accept_event()

func handle_fusion_selection(fusion_card_instance):
	handle_enemy_fusion_selection(fusion_card_instance)



func open_enemy_fusion_menu():
	if enemy_fusion_menu:
		return  # Already open.
	if selected_cards.size() == 2:
		enemy_fusion_menu = enemy_fusion_menu_scene.instantiate()
		# Do not force the size or position here—let the scene’s anchors/margins control it.
		enemy_fusion_menu.visible = true
		enemy_fusion_menu.hand_manager = self
		enemy_fusion_menu.card_factory = main_node.card_factory
		enemy_fusion_menu.descriptive_box = main_node.descriptive_box
		print("About to call populate_fusion_options() with selected_cards[0].card_data:",
			selected_cards[0].card_data.name, "and selected_cards[1].card_data:",
			selected_cards[1].card_data.name)
		enemy_fusion_menu.populate_fusion_options(selected_cards[0].card_data, selected_cards[1].card_data)
		print("populate_fusion_options() call finished.")
		main_node.add_child(enemy_fusion_menu)
		enemy_fusion_menu.position = Vector2(1260, 10) # Adjust these values
		print("EnemyFusionMenu added to Main node; global position:", enemy_fusion_menu.global_position)
	else:
		print("open_enemy_fusion_menu: selected_cards size is", selected_cards.size(), "but should be 2.")



func close_enemy_fusion_menu():
	if enemy_fusion_menu:
		enemy_fusion_menu.queue_free()
		enemy_fusion_menu = null
		# Don't clear selected cards when closing the menu!
		# selected_cards.clear()
		print("EnemyFusionMenu: Closed fusion menu without clearing selected cards.")

func handle_enemy_fusion_selection(fusion_card_instance):
	# Remove the two selected enemy cards.
	# Add the selected cards to the discard pile before removing them
	for card in selected_cards:
		main_node.enemy_discard_pile.append(card.card_data)
		print("Added card to enemy discard pile:", card.card_data.name)
		
		# Remove the card from hand
		remove_card(card)
		card.queue_free()
	
	selected_cards.clear()
	# Remove the fusion card from its current parent, if any.
	if fusion_card_instance.get_parent():
		fusion_card_instance.get_parent().remove_child(fusion_card_instance)
	
	# Prepare the fusion card for use in the enemy hand
	
	# 1. Ensure the hand_manager is properly set to this enemy hand instance
	fusion_card_instance.hand_manager = self
	
	# 2. Remove any existing gui_input connections
	var connections = fusion_card_instance.get_signal_connection_list("gui_input")
	for connection in connections:
		fusion_card_instance.disconnect("gui_input", connection.callable)
	
	# 3. Connect to our enemy-hand specific click handler
	fusion_card_instance.connect("gui_input", Callable(self, "_on_enemy_card_clicked").bind(fusion_card_instance))
	
	# Add the fusion card to enemy hand.
	add_card(fusion_card_instance)
	add_child(fusion_card_instance)
	print("EnemyFusionMenu: Fusion card added to enemy hand:", fusion_card_instance.card_data.name)
	close_enemy_fusion_menu()


# Replace the summon_highlighted_card function in EnemyHand.gd with this improved version

# Replace the summon_highlighted_card function in EnemyHand.gd with this improved version

func summon_highlighted_card(click_position: Vector2):
	if enemy_summon_timer > 0:
		print("Enemy summoning is on cooldown for", enemy_summon_timer, "seconds.")
		return
	
	if selected_cards.size() == 1:
		var card_instance = selected_cards[0]
		var card_data = card_instance.card_data
		
		# Ensure click_position is within a valid summoning zone
		var valid_position = ensure_valid_summon_position(click_position)
		
		if main_node.summon_creature(card_data, valid_position, true):
			# Remove the card from the hand
			remove_card(card_instance)
			
			# Add the card to the enemy discard pile
			main_node.enemy_discard_pile.append(card_data)
			print("Added card to enemy discard pile:", card_data.name)
			
			# Clear selection and free the card
			card_instance.queue_free()
			selected_cards.clear()
			enemy_summon_timer = enemy_summon_cooldown
			print("EnemyHand: Summoned enemy creature from card:", card_data.name)
		else:
			print("EnemyHand: Summoning failed for card:", card_data.name)
	else:
		print("EnemyHand: Exactly one card must be highlighted to summon.")
# Add this helper function to EnemyHand.gd
func ensure_valid_summon_position(position: Vector2) -> Vector2:
	# Get the enemy summon zone
	var enemy_zone = main_node.get_node("/root/Control/BoardPanel/OpponentSummonerShield/OpponentInitialSummonZone2D") as Area2D
	if not enemy_zone:
		print("EnemyHand: Could not find enemy summon zone")
		return position
	
	# First, find all valid enemy creature zones (both initial and around existing creatures)
	var valid_zones = []
	
	# Add the initial summon zone
	if enemy_zone and enemy_zone.has_node("CollisionShape2D"):
		valid_zones.append({
			"center": enemy_zone.global_position,
			"shape": enemy_zone.get_node("CollisionShape2D").shape,
			"node": enemy_zone
		})
	
	# Add the summon zones around existing enemy creatures
	var enemy_creatures = main_node.get_tree().get_nodes_in_group("enemy_creatures")
	for creature in enemy_creatures:
		if creature.has_node("SummonZone"):
			var summon_zone = creature.get_node("SummonZone") as Area2D
			if summon_zone and summon_zone.has_node("CollisionShape2D"):
				valid_zones.append({
					"center": summon_zone.global_position,
					"shape": summon_zone.get_node("CollisionShape2D").shape,
					"node": summon_zone
				})
	
	# Find the leftmost valid position at approximately the same Y coordinate
	var target_y = position.y  # Try to maintain the same Y-coordinate (same lane)
	var leftmost_valid_x = 9999999  # Start with a large number
	var best_position = enemy_zone.global_position  # Fallback position
	
	# Check each valid zone
	for zone in valid_zones:
		var center = zone.center
		var shape = zone.shape
		
		if shape is CircleShape2D:
			var radius = shape.radius
			
			# Calculate leftmost valid x-coordinate within this circle zone
			# keeping approximately the same y-coordinate
			
			# Calculate how far we can go left/right at this y-coordinate
			var y_diff = abs(center.y - target_y)
			
			# If y_diff is larger than radius, this y-coordinate doesn't intersect the circle
			if y_diff < radius:
				# Calculate how far left/right we can go at this y-coordinate using Pythagorean theorem
				var x_range = sqrt(radius * radius - y_diff * y_diff)
				
				# The leftmost x-coordinate within this circle at this y-coordinate
				var left_x = center.x - x_range
				
				# If this is the leftmost valid position found so far, save it
				if left_x < leftmost_valid_x:
					leftmost_valid_x = left_x
					best_position = Vector2(left_x + 5, target_y)  # Add a small buffer (5 pixels)
		elif shape is RectangleShape2D:
			var extents = shape.extents
			var rect_left = center.x - extents.x
			var rect_top = center.y - extents.y
			var rect_bottom = center.y + extents.y
			
			# Check if the y-coordinate is within this rectangle
			if target_y >= rect_top and target_y <= rect_bottom:
				# If this is the leftmost valid position found so far, save it
				if rect_left < leftmost_valid_x:
					leftmost_valid_x = rect_left
					best_position = Vector2(rect_left + 5, target_y)  # Add a small buffer (5 pixels)
	
	# Double-check this position is actually valid
	if main_node.is_in_valid_summon_zone(best_position, "/root/Control/BoardPanel/OpponentSummonerShield/OpponentInitialSummonZone2D", "enemy_creatures"):
		return best_position
	
	# If not valid, fall back to a safe position in the initial summon zone
	if enemy_zone and enemy_zone.has_node("CollisionShape2D"):
		var shape = enemy_zone.get_node("CollisionShape2D").shape
		if shape is CircleShape2D:
			var radius = shape.radius * 0.8  # 80% of radius for safety
			var center = enemy_zone.global_position
			return Vector2(center.x - radius/2, center.y)  # Slightly left of center
	
	# Last resort fallback
	return enemy_zone.global_position
func _process(delta: float) -> void:
	if enemy_summon_timer > 0:
		enemy_summon_timer -= delta


func get_hand_size() -> int:
	return card_list.size()
