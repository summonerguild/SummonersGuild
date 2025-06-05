extends Node

class_name EnemyAI

# References
var enemy_hand  # Reference to the EnemyHand instance
var main_node   # Reference to the Main node

# AI parameters
var action_interval: float = 5.0   # Time between AI actions (in seconds)
var action_timer: float = 0.0      # Current timer value
var fusion_chance: float = 0.5     # Chance to attempt fusion vs summoning (0-1)

func _init(hand_reference, main_reference):
	enemy_hand = hand_reference
	main_node = main_reference
	# Randomize the initial timer to prevent predictable patterns
	action_timer = randf_range(0.5, action_interval)


# Try to perform fusion with cards in the enemy hand
func attempt_fusion():
	print("AI: Attempting to fuse cards")
	
	# Clear any previously selected cards
	for card in enemy_hand.selected_cards:
		card.toggle_highlight()
	enemy_hand.selected_cards.clear()
	
	# Find pairs of cards with the same fusion level
	var fusion_level_groups = {}
	
	for card in enemy_hand.card_list:
		var level = card.card_data.fusion_level
		if not fusion_level_groups.has(level):
			fusion_level_groups[level] = []
		fusion_level_groups[level].append(card)
	
	# Check if we have a valid fusion pair
	var valid_pair = false
	var selected_level = null
	
	# First, try to find a level with exactly 2 cards
	for level in fusion_level_groups.keys():
		if fusion_level_groups[level].size() == 2:
			selected_level = level
			valid_pair = true
			break
	
	# If no level with exactly 2 cards, try to find a level with more than 2 cards
	if not valid_pair:
		for level in fusion_level_groups.keys():
			if fusion_level_groups[level].size() >= 2:
				selected_level = level
				valid_pair = true
				break
	
	if valid_pair:
		# Select the first two cards of the chosen level
		var card1 = fusion_level_groups[selected_level][0]
		var card2 = fusion_level_groups[selected_level][1]
		
		# Simulate clicking on these cards to highlight them
		_simulate_card_click(card1)
		_simulate_card_click(card2)
		
		print("AI: Selected cards for fusion with fusion level", selected_level)
		
		# Wait for a short moment before opening the fusion menu
		await get_tree().create_timer(0.5).timeout
		
		# Open the fusion menu
		enemy_hand.open_enemy_fusion_menu()
		
		# Wait for a short moment before selecting a fusion option
		await get_tree().create_timer(0.5).timeout
		
		# If the fusion menu was opened successfully, select a random fusion option
		var fusion_menu = enemy_hand.enemy_fusion_menu
		if fusion_menu and fusion_menu.fusion_options.size() > 0:
			# Get a random child (fusion option) from the fusion menu
			var fusion_options = fusion_menu.get_children()
			if fusion_options.size() > 0:
				var random_option = fusion_options[randi() % fusion_options.size()]
				
				# Simulate right-clicking the fusion option
				var event = InputEventMouseButton.new()
				event.button_index = MOUSE_BUTTON_RIGHT
				event.pressed = true
				
				fusion_menu._on_fusion_card_selected(event, random_option)
				print("AI: Selected fusion option")
	else:
		print("AI: No valid fusion pairs found")

# Try to summon a creature
func attempt_summoning():
	print("AI: Attempting to summon a creature")
	
	# Clear any previously selected cards
	for card in enemy_hand.selected_cards:
		card.toggle_highlight()
	enemy_hand.selected_cards.clear()
	
	if enemy_hand.card_list.size() > 0:
		# Filter for creature cards only
		var creature_cards = []
		for card in enemy_hand.card_list:
			print("AI: Card in hand:", card.card_data.name, "Type:", card.card_data.card_type)
			if card.card_data.card_type == "creature":
				creature_cards.append(card)
		
		if creature_cards.size() == 0:
			print("AI: No creature cards in hand, only spells. Aborting summoning attempt.")
			return
			
		# Select a random creature card to summon
		var card_to_summon = creature_cards[randi() % creature_cards.size()]
		
		# Double-check this is a creature card
		if card_to_summon.card_data.card_type != "creature":
			print("AI: ERROR - Attempted to summon a non-creature card type:", card_to_summon.card_data.card_type)
			return
			
		print("AI: Selected creature card for summoning:", card_to_summon.card_data.name)
		
		# Simulate clicking the card to highlight it
		_simulate_card_click(card_to_summon)
		
		# Find player creatures to target
		var player_creatures = get_tree().get_nodes_in_group("ally_creatures")
		var target_position = Vector2.ZERO
		var enemy_summoner = main_node.get_node("BoardPanel/OpponentSummonerShield")
		
		if player_creatures.size() > 0:
			# Find the player creature closest to the enemy's summoner
			var closest_creature = player_creatures[0]
			var closest_distance = enemy_summoner.global_position.distance_to(closest_creature.global_position)
			
			for creature in player_creatures:
				var distance = enemy_summoner.global_position.distance_to(creature.global_position)
				if distance < closest_distance:
					closest_creature = creature
					closest_distance = distance
			
			# Calculate a position in the same lane as the player's creature
			var base_position = Vector2(
				enemy_summoner.global_position.x,  # Start at the same x as the summoner
				closest_creature.global_position.y  # But use the y of the creature (same lane)
			)
			
			# This position will be refined by ensure_valid_summon_position to be the leftmost valid position
			target_position = base_position
		else:
			# If no player creatures, calculate a default position
			target_position = Vector2(
				enemy_summoner.global_position.x,  # Start with summoner's x position
				enemy_summoner.global_position.y + 200  # Move down a bit from the summoner
			)
		
		# Summon the creature at the calculated position
		enemy_hand.summon_highlighted_card(target_position)
		print("AI: Summoned creature at position", target_position)
	else:
		print("AI: No cards available to summon")

# Add or update this method in the EnemyAI class
func attempt_spell_casting():
	print("AI: Attempting to cast a spell")
	
	# Clear any previously selected cards
	for card in enemy_hand.selected_cards:
		card.toggle_highlight()
	enemy_hand.selected_cards.clear()
	
	# Find spell cards in the enemy hand
	var spell_cards = []
	for card in enemy_hand.card_list:
		print("AI: Card:", card.name, "Type:", card.card_data.card_type if card.card_data else "No card_data")
		if card.card_data and card.card_data.card_type == "spell":
			spell_cards.append(card)
	
	if spell_cards.size() == 0:
		print("AI: No spell cards in hand")
		return
	
	print("AI: Found", spell_cards.size(), "spell cards")
	
	# Find potential targets on the board, filtering out spell objects
	var enemy_creatures = []
	var player_creatures = []
	
	# Get all enemy creatures but filter out any spell objects
	for creature in main_node.get_tree().get_nodes_in_group("enemy_creatures"):
		# Skip if it's a spell (check if it's in one of the spell groups)
		if creature.is_in_group("enemy_spells") or creature.is_in_group("ally_spells"):
			continue
		enemy_creatures.append(creature)
	
	# Get all player creatures but filter out any spell objects
	for creature in main_node.get_tree().get_nodes_in_group("ally_creatures"):
		# Skip if it's a spell
		if creature.is_in_group("enemy_spells") or creature.is_in_group("ally_spells"):
			continue
		player_creatures.append(creature)
	
	# Check if there are any targets at all before proceeding
	var has_potential_targets = false
	if player_creatures.size() > 0 or enemy_creatures.size() > 0:
		has_potential_targets = true
	
	if not has_potential_targets:
		print("AI: No potential targets for any spells, aborting spell cast attempt")
		# Important: Make sure no cards remain selected
		for card in enemy_hand.selected_cards:
			card.toggle_highlight()
		enemy_hand.selected_cards.clear()
		return
	
	# Shuffle spell cards for random selection
	spell_cards.shuffle()
	
	# Try each spell until we find one with valid targets
	for spell_card in spell_cards:
		print("AI: Evaluating spell card:", spell_card.card_data.name)
		
		# Determine if this is a buff/healing spell or a damage/debuff spell
		var is_buff = false
		
		# Check abilities to determine spell type
		if spell_card.card_data.abilities.size() > 0:
			for ability in spell_card.card_data.abilities:
				if ability.get("affects_allies") != null:
					is_buff = ability.affects_allies and (ability.get("affects_enemies") == null or not ability.affects_enemies)
					break
		else:
			# Fall back to checking spell_effect_type
			if spell_card.card_data.get("spell_effect_type") != null:
				is_buff = spell_card.card_data.spell_effect_type == "buff" or spell_card.card_data.spell_effect_type == "heal"
		
		print("AI: Spell is buff/heal type:", is_buff)
		
		# SIMPLER TARGETING: Get direct board position of a creature
		var target_position = Vector2.ZERO
		var has_target = false
		
		if is_buff:
			# For buffs, target enemy creatures (AI's allies)
			if enemy_creatures.size() > 0:
				# Just pick a random enemy creature
				var target_creature = enemy_creatures[randi() % enemy_creatures.size()]
				
				# Use the creature's direct position
				target_position = target_creature.position
				
				print("AI: Targeting enemy creature at position:", target_position)
				has_target = true
			else:
				print("AI: No enemy creatures to buff")
		else:
			# For damage spells, target player creatures
			if player_creatures.size() > 0:
				# Just pick a random player creature
				var target_creature = player_creatures[randi() % player_creatures.size()]
				
				# Use the creature's direct position
				target_position = target_creature.position
				
				print("AI: Targeting player creature at position:", target_position)
				has_target = true
			else:
				print("AI: No player creatures to target")
		
		if has_target:
			# Select the card
			_simulate_card_click(spell_card)
			
			# Cast the spell through enemy_play_card which will route to cast_enemy_spell
			print("AI: Casting spell at position:", target_position)
			main_node.call_deferred("cast_enemy_spell", target_position)
			return
		else:
			print("AI: Skipping spell", spell_card.card_data.name, "- no valid targets")
	
	# If no spells could be cast, make sure no cards remain selected
	print("AI: No suitable spells to cast, ending attempt")
	for card in enemy_hand.selected_cards:
		card.toggle_highlight()
	enemy_hand.selected_cards.clear()
	
	
func _process(delta):
	# Update the action timer
	action_timer -= delta
	
	# If it's time to take an action
	if action_timer <= 0.0:
		# Reset the timer
		action_timer = action_interval
		
		# Check if there are valid spell targets, filtering out spells
		var has_valid_spell_targets = false
		var enemy_creatures = []
		var player_creatures = []
		
		# Filter out spell objects from enemy creatures
		for creature in main_node.get_tree().get_nodes_in_group("enemy_creatures"):
			if not (creature.is_in_group("enemy_spells") or creature.is_in_group("ally_spells")):
				enemy_creatures.append(creature)
		
		# Filter out spell objects from player creatures
		for creature in main_node.get_tree().get_nodes_in_group("ally_creatures"):
			if not (creature.is_in_group("enemy_spells") or creature.is_in_group("ally_spells")):
				player_creatures.append(creature)
		
		if player_creatures.size() > 0 or enemy_creatures.size() > 0:
			has_valid_spell_targets = true
		# Generate a random number for action selection
		var action_choice = randf()
		
		# Now use a balanced approach to action selection:
		if has_valid_spell_targets and action_choice < 0.4:
			# 20% chance to cast spells when targets exist
			print("AI: Choosing to cast a spell (20% probability)")
			attempt_spell_casting()
		elif action_choice < 0.5:
			# 30% chance to attempt fusion (50% - 20%)
			print("AI: Choosing to attempt fusion")
			attempt_fusion()
		else:
			# 50% chance to attempt summoning
			print("AI: Choosing to attempt summoning")
			attempt_summoning()


# Helper function to simulate clicking a card
func _simulate_card_click(card):
	# Create a fake mouse click event
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	
	# Call the enemy hand's card click handler
	enemy_hand._on_enemy_card_clicked(event, card)
