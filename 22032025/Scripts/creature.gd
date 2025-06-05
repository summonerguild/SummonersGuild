extends Area2D

# At the top of Creature.gd
signal creature_clicked
# Basic properties for the creature (set by card data)
@export var attack: int = 10
@export var health: int = 100
@export var armor: int = 0  # Armor reduces damage taken
@export var attack_speed: float = 1.0  # Time between attacks in seconds
@export var move_speed: float = 0.0  # Movement speed for the creature
@export var attack_range: int = 0  # How close the creature must be to attack
@export var health_regen: float = 0  # Health regeneration rate per second
@export var max_mana: int = 0  # Mana value for special abilities (if any)
@export var health_bar: TextureProgressBar
@export var creature_id: int = randi()  # Generate a unique ID for each creature
@export var mana_regen: float = 0.0        # Mana regeneration rate (per second)
@export var mana_bar: TextureProgressBar   # Reference to your ManaBar's TextureProgressBar

var movement_system: CreatureMovement = null
var abilities: Array = []
var mana: float = 0.0  # Current mana, now as a float.
var special_check_interval: float = 1.0   # Check every 1 second once max mana is reached.
var special_check_timer: float = 0.0
const MovementDebugVisualizer = preload("res://Scripts/MovementDebugVisualizer.gd")
var is_frozen: bool = false  # Controls if creature is completely frozen
# Random attack delay for the first attack in combat
@export var attack_delay: float = 0.0
@export var first_attack: bool = true  # Flag to check if it's the first attack in combat

# Internal state for attack cooldown and movement
@export var attack_timer: float = 0.0
@export var can_move: bool = true  # Flag to control movement

# References for the ally summoner and opponent summoner
@export var opponent_summoner: Area2D  # Usually for the opponent's shield
@export var ally_summoner: Area2D  # For sandbox testing, this will target the ally shield instead
@export var current_target: Area2D = null  # Current creature or shield target
@export var target_ally: bool = false  # This will be set during summoning

# Pathfinding and movement variables
@export var path_points = []
@export var path_index = 0
@export var base_avoidance_distance = 500.0  # Increase this if no visible change

# Constants for separation behavior
const MIN_SEPARATION_DISTANCE = 40.0  # Minimum distance between allies
const SEPARATION_STRENGTH = 3.0      # Strength of the separation force

@export var ability_description: String
@export var card_image: Texture2D  # This will store the creature's image
@onready var animated_sprite = $AnimatedSprite2D
var card_data: carddata = null


# RayCast2D nodes for wall detection
@onready var ray_n = $RayCastN
@onready var ray_ne = $RayCastNE
@onready var ray_e = $RayCastE
@onready var ray_se = $RayCastSE
@onready var ray_s = $RayCastS
@onready var ray_sw = $RayCastSW
@onready var ray_w = $RayCastW
@onready var ray_nw = $RayCastNW
@onready var path_visualizer = get_node("../PathVisualizer")


# Add these variables to Creature.gd at the top
# Blind effect variables
var is_blinded: bool = false
var blind_miss_chance: float = 0.0
var blind_timer: float = 0.0
var blind_effect_node: Node = null
# Add a new array to track secondary blind effects
var secondary_blind_effects = []  # Will hold {miss_chance, timer} dictionaries

# Declare a variable to hold the path movement instance
var path_movement_script

func get_creature_at_click_position(click_position: Vector2) -> Node:
	var space_state = $BoardPanel.get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = click_position
	query.collide_with_areas = true
	var results = space_state.intersect_point(query)

	for result in results:
		var collider = result.collider
		if collider and (collider.is_in_group("ally_creatures") or collider.is_in_group("enemy_creatures")):
			print("Detected creature at click:", collider.name)
			return collider

	print("No creature detected at click position:", click_position)
	return null



	
func initialize_with_card_data(card_data: carddata):
	self.card_data = card_data
	print("SPRITE: Initializing creature with card: " + card_data.name)
	
	# Basic properties assignment
	attack = card_data.attack
	health = card_data.health
	armor = card_data.armor
	attack_speed = card_data.attack_speed
	move_speed = card_data.move_speed
	attack_range = card_data.attack_range
	health_regen = card_data.health_regen
	mana_regen = card_data.mana_regen
	card_image = card_data.image
	ability_description = card_data.ability_description
	max_mana = card_data.max_mana
	mana = 0
	
	# Handle the sprite - use the actual node name "Sprite2D" rather than type checking
	if has_node("Sprite2D"):
		var sprite_node = $Sprite2D
		var has_animations = card_data.get("has_animations") if card_data.has_method("get") and "has_animations" in card_data else false
		
		print("SPRITE: Found sprite node for: " + card_data.name)
		print("SPRITE: Card has animations: " + str(has_animations))
		print("SPRITE: Card image exists: " + str(card_data.image != null))
		print("SPRITE: Actual node type: " + sprite_node.get_class())
		
		# If it's an AnimatedSprite2D with the name "Sprite2D"
		if sprite_node is AnimatedSprite2D:
			if has_animations and card_data.get("animation_frames") != null:
				# For animated creatures, use their predefined SpriteFrames
				sprite_node.sprite_frames = card_data.animation_frames
				print("SPRITE: Using predefined animations for " + card_data.name)
			else:
				# For regular creatures, create a basic SpriteFrames
				print("SPRITE: Creating basic SpriteFrames for " + card_data.name)
				
				# Create or get existing SpriteFrames
				var frames = sprite_node.sprite_frames
				if frames == null:
					frames = SpriteFrames.new()
					sprite_node.sprite_frames = frames
					print("SPRITE: Created new SpriteFrames")
				
				# Ensure default animation exists
				if !frames.has_animation("default"):
					frames.add_animation("default")
					frames.set_animation_loop("default", true)
					frames.set_animation_speed("default", 5)
					print("SPRITE: Added default animation")
				
				# Clear existing frames and add the static image
				var frame_count = frames.get_frame_count("default")
				print("SPRITE: Clearing " + str(frame_count) + " existing frames")
				for i in range(frame_count):
					frames.remove_frame("default", 0)
				
				if card_data.image:
					frames.add_frame("default", card_data.image)
					print("SPRITE: Added image to default animation")
				else:
					print("SPRITE: WARNING - No image available for " + card_data.name)
			
			# Start playing the default animation
			sprite_node.play("default")
			print("SPRITE: Started playing default animation")
		# If it's a regular Sprite2D (for backward compatibility)
		elif sprite_node is Sprite2D:
			if card_data.image:
				sprite_node.texture = card_data.image
				print("SPRITE: Set texture directly on Sprite2D")
			else:
				print("SPRITE: WARNING - No image available for " + card_data.name)
	else:
		print("SPRITE: ERROR - No Sprite2D node found in creature!")
	
	# Rest of your initialization
	update_aggrozone()
	for ability_res in card_data.abilities:
		var ability_instance = ability_res.instance() if ability_res.has_method("instance") else ability_res
		abilities.append(ability_instance)
	
	attack_delay = randf_range(0.1, 0.5)





# Called when the node is added to the scene
func _ready():

#	emit_signal("creature_clicked", self)
#	print("signalemitted")
	# Use Callable to reference the function within the same script
	connect("input_event", Callable(self, "_on_input_event"))
	health_bar = $HealthBar/TextureProgressBar
	update_health_bar()

	mana_bar = $ManaBar/TextureProgressBar
	update_mana_bar()


	# Determine group and set color based on creature type
	if is_in_group("ally_creatures"):
		print("Creature is in ally_creatures group on ready")
		health_bar.modulate = Color(0.0, 1.0, 0.0)  # Green for allies
	elif is_in_group("enemy_creatures"):
		print("Creature is in enemy_creatures group on ready")
		health_bar.modulate = Color(1.0, 0.0, 0.0)  # Red for enemies
	else:
		print("Creature is not in any expected group on ready")
		health_bar.modulate = Color(1.0, 1.0, 1.0)  # Default white if no group
	
	#call_deferred("assign_paths", false)  # or true depending on the default behavior

	# Check which group the creature is in
	if is_in_group("ally_creatures"):
		print("Creature is in ally_creatures group on ready")
	elif is_in_group("enemy_creatures"):
		print("Creature is in enemy_creatures group on ready")
	else:
		print("Creature is not in any expected group on ready")

	health_bar = $HealthBar/TextureProgressBar
	update_health_bar()

	creature_id = randi()  # Unique ID for debugging purposes
	print("Creature ID:", creature_id)

	# Activate all the raycasts to detect walls
	ray_n.enabled = true
	ray_ne.enabled = true
	ray_e.enabled = true
	ray_se.enabled = true
	ray_s.enabled = true
	ray_sw.enabled = true
	ray_w.enabled = true
	ray_nw.enabled = true


	# Initialize the movement system
	movement_system = CreatureMovement.new(self)
	movement_system.set_move_speed(move_speed)
	add_child(movement_system)
	
	# Make sure the movement system gets the right size of the board
	movement_system.board_panel = get_parent()
	
	# Set up the target summoner
	if is_in_group("ally_creatures"):
		opponent_summoner = get_node("/root/Control/BoardPanel/OpponentSummonerShield")
		movement_system.target_summoner = opponent_summoner
	elif is_in_group("enemy_creatures"):
		opponent_summoner = get_node("/root/Control/BoardPanel/AllySummonerShield")
		movement_system.target_summoner = opponent_summoner

		#var debug_visualizer = MovementDebugVisualizer.new(self, movement_system)
		#add_child(debug_visualizer)
#
#
	## Make sure this happens for all creatures, not just in one code path
	#if movement_system:
		#var debug_visualizer = MovementDebugVisualizer.new(self, movement_system)
		#add_child(debug_visualizer)
		#print("Added debug visualizer to: " + name)

func update_aggrozone():
	var aggro_zone = $AggroZone
	if aggro_zone:
		var collision_shape = aggro_zone.get_node("CollisionShape2D")
		if collision_shape and collision_shape.shape is CircleShape2D:
			# Always duplicate the shape so that each creature gets its own copy.
			collision_shape.shape = collision_shape.shape.duplicate()
			collision_shape.shape.radius = attack_range + 100  # Adjust the buffer as needed.
		else:
			print("AggroZone's collision shape is not a CircleShape2D.")
	else:
		print("No aggro zone found.")




# You can adjust the raycast length for detecting allies
#	var raycast_length: float = 50  # Adjust 

	# Connect the shield's area_entered signal to start attacking when we enter the shield area
	if opponent_summoner:
		opponent_summoner.connect("area_entered", Callable(self, "_on_opponent_summoner_shield_area_entered"))
	
	# Connect aggrozone signals to detect enemy creatures
	$AggroZone.connect("area_entered", Callable(self, "_on_aggrozone_entered"))
	$AggroZone.connect("area_exited", Callable(self, "_on_aggrozone_exited"))



# Update the health bar when health changes
func update_health_bar():
	if health_bar:
		health_bar.value = health  # Update the bar's value based on the current health
	
	
func update_mana_bar():
	if mana_bar:
		mana_bar.value = mana

	

func _process(delta):
	# Skip all processing if frozen
	if is_frozen:
		return
	# Always update mana at the beginning of every frame
	mana += mana_regen * delta
	if mana > max_mana:
		mana = max_mana
	update_mana_bar()
	
	# Handle passive abilities every frame
	execute_abilities_by_trigger("passive_update")
	
	# Handle blind effects
	if is_blinded:
		blind_timer -= delta
		
		# Debug output to track blind status
		print(name + " primary blind: " + str(blind_miss_chance * 100) + "% with " + str(blind_timer) + "s remaining")
		
		if blind_timer <= 0:
			print("Primary blind effect expired")
			
			# Check if we have secondary effects to promote
			if secondary_blind_effects.size() > 0:
				# Sort by miss_chance (strongest first)
				secondary_blind_effects.sort_custom(func(a, b): return a.miss_chance > b.miss_chance)
				
				# Promote the strongest one to primary
				var next_effect = secondary_blind_effects.pop_front()
				blind_miss_chance = next_effect.miss_chance
				blind_timer = next_effect.timer
				
				print(name + " now using secondary blind: " + str(blind_miss_chance * 100) + "% for " + str(blind_timer) + "s")
			else:
				# No secondary effects, remove blind completely
				is_blinded = false
				blind_miss_chance = 0.0
				blind_timer = 0.0
				
				# Restore sprite
				if has_node("Sprite2D"):
					var sprite = get_node("Sprite2D")
					sprite.modulate = Color(sprite.modulate.r, sprite.modulate.g, sprite.modulate.b, 1.0)
					
				print(name + " is no longer blinded")
	
	# Update secondary blind effects
	for i in range(secondary_blind_effects.size() - 1, -1, -1):
		var effect = secondary_blind_effects[i]
		effect.timer -= delta
		
		if effect.timer <= 0:
			secondary_blind_effects.remove_at(i)
			print("Secondary blind effect expired")
			
			
	# Handle max mana abilities
	if mana >= max_mana:
		special_check_timer -= delta
		if special_check_timer <= 0:
			special_check_timer = special_check_interval
			execute_abilities_by_trigger("on_max_mana")
	
	# 1. Update our opponent_summoner reference
	if target_ally:
		opponent_summoner = get_node("/root/Control/BoardPanel/AllySummonerShield")
		if movement_system:
			movement_system.target_summoner = opponent_summoner
	else:
		opponent_summoner = get_node("/root/Control/BoardPanel/OpponentSummonerShield")
		if movement_system:
			movement_system.target_summoner = opponent_summoner
	
	# 2. Check if we already have a target that's not in range yet
	if current_target != null:
		var distance_to_target = global_position.distance_to(current_target.global_position)
		
		if distance_to_target <= attack_range:
			# Target is now in range, stop movement and attack
			can_move = false
			if movement_system:
				movement_system.can_move = false
			attack_opponent(delta)
			return
		else:
			# Target not in range yet, keep movement enabled but move towards target
			can_move = true
			if movement_system:
				movement_system.can_move = true
			# Call attack_opponent which will handle movement towards target
			attack_opponent(delta)
			return
	
	# 3. Look for a valid enemy creature within melee range
	var enemy_candidate = find_valid_enemy_target_in_range(attack_range)
	if enemy_candidate:
		current_target = enemy_candidate
		can_move = false
		if movement_system:
			movement_system.can_move = false
		first_attack = true
		attack_opponent(delta)
		return
	
	# 4. If no enemy candidate, then check if we're in range of the opponent's shield
	if current_target == null and is_in_attack_range(global_position):
		current_target = opponent_summoner
		can_move = false
		if movement_system:
			movement_system.can_move = false
		attack_opponent(delta)
		return
	
	# 5. Movement logic: if still no target, use our new movement system
	if can_move and opponent_summoner and current_target == null:
		if movement_system:
			# Use the new movement system
			movement_system.can_move = true
			movement_system.update_movement(delta)
		else:
			# Fallback to old movement if system not initialized
			if path_points.size() > 0:
				if is_in_attack_range(global_position):
					can_move = false
					attack_opponent(delta)
				else:
					var result = path_movement_script.follow_path(delta, global_position, move_speed, path_points, path_index)
					global_position = result.new_position
					path_index = result.updated_index
			else:
				move_towards_opponent(delta)


# In Creature.gd – add these functions to handle burn effects.
func apply_burn(initial_damage: int, duration: float) -> void:
	# This function applies a burn effect that ticks every second.
	# 'duration' here is in seconds; we’ll treat it as the number of ticks.
	print("Applying burn effect on", self.name, "with initial damage", initial_damage, "for", duration, "seconds")
	# Create a burn dictionary holding the current damage and number of ticks remaining.
	var burn_effect = {"damage": initial_damage, "ticks": int(duration)}
	_apply_burn_tick(burn_effect)

func _apply_burn_tick(burn: Dictionary) -> void:
	if burn["ticks"] > 0 and burn["damage"] > 0:
		# Apply the current burn damage to self.
		take_damage(burn["damage"])
		print("Burn tick on", self.name, "for", burn["damage"], "damage")
		burn["ticks"] -= 1
		burn["damage"] = max(burn["damage"] - 1, 0)
		# Schedule the next tick after 1 second.
		var timer = get_tree().create_timer(1.0)
		timer.timeout.connect(Callable(self, "_apply_burn_tick").bind(burn))
	else:
		print("Burn effect on", self.name, "has ended.")



func apply_buff(stat: String, amount: float, duration: float) -> void:
	print("Applying buff on", self.name, ":", stat, "increased by", amount, "for", duration, "seconds")
	
	# Handle all possible stat types
	match stat:
		"attack":
			attack += amount
			print("Attack increased from", attack - amount, "to", attack)
		
		"health":
			health += amount
			# Cap health at whatever the maximum health might be
			# You may want to update this logic based on your game design
			print("Health increased from", health - amount, "to", health)
			update_health_bar()
		
		"armor":
			armor += amount
			print("Armor increased from", armor - amount, "to", armor)
		
		"attack_speed":
			attack_speed += amount
			print("Attack speed increased from", attack_speed - amount, "to", attack_speed)
		
		"move_speed":
			move_speed += amount
			print("Movement speed increased from", move_speed - amount, "to", move_speed)
		
		"attack_range":
			attack_range += int(amount)  # Since attack_range is likely an integer
			print("Attack range increased from", attack_range - int(amount), "to", attack_range)
			# If you use attack_range to set the AggroZone size, update it
			update_aggrozone()
		
		"max_mana":
			max_mana += int(amount)
			print("Maximum mana increased from", max_mana - int(amount), "to", max_mana)
			# Optionally also increase current mana
			mana = min(mana + int(amount), max_mana)
			update_mana_bar()
		
		"mana_regen":
			mana_regen += amount
			print("Mana regeneration increased from", mana_regen - amount, "to", mana_regen)
		
		"health_regen":
			health_regen += amount
			print("Health regeneration increased from", health_regen - amount, "to", health_regen)
		
		# You could even add special buffs like these:
		"ability_range":
			if card_data:
				card_data.ability_range += amount
				print("Ability range increased from", card_data.ability_range - amount, "to", card_data.ability_range)
			else:
				print("Cannot buff ability_range: card_data is null")
		
		"all_stats":
			# A special buff type that increases multiple stats at once
			apply_buff("attack", amount, duration)
			apply_buff("health", amount * 10, duration)  # Scaled for health which is typically larger
			apply_buff("armor", amount / 2, duration)    # Scaled for armor which is typically smaller
			apply_buff("attack_speed", amount / 5, duration)  # Scaled for attack_speed
			apply_buff("move_speed", amount, duration)
			# Skip recursively calling for "all_stats" to avoid infinite recursion
			
		_:
			print("Warning: Buff stat", stat, "not recognized.")
	
	# Create a visual effect to show the buff being applied
	#flash_buff_visual_effect()
	
	# Schedule the buff removal after the duration
	var timer = get_tree().create_timer(duration)
	timer.timeout.connect(Callable(self, "_remove_buff").bind(stat, amount))

func _remove_buff(stat: String, amount: float) -> void:
	# Need to handle all the same cases as apply_buff
	match stat:
		"attack":
			attack -= amount
			print("Attack buff expired. Attack decreased to", attack)
		
		"health":
			health -= amount
			# Don't allow health to go below 1 due to buff expiration
			health = max(health, 1)
			print("Health buff expired. Health decreased to", health)
			update_health_bar()
		
		"armor":
			armor -= amount
			print("Armor buff expired. Armor decreased to", armor)
		
		"attack_speed":
			attack_speed -= amount
			print("Attack speed buff expired. Attack speed decreased to", attack_speed)
		
		"move_speed":
			move_speed -= amount
			print("Movement speed buff expired. Movement speed decreased to", move_speed)
		
		"attack_range":
			attack_range -= int(amount)
			print("Attack range buff expired. Attack range decreased to", attack_range)
			# Update the AggroZone size
			update_aggrozone()
		
		"max_mana":
			max_mana -= int(amount)
			# Cap current mana at new max_mana
			mana = min(mana, max_mana)
			print("Maximum mana buff expired. Maximum mana decreased to", max_mana)
			update_mana_bar()
		
		"mana_regen":
			mana_regen -= amount
			print("Mana regeneration buff expired. Mana regeneration decreased to", mana_regen)
		
		"health_regen":
			health_regen -= amount
			print("Health regeneration buff expired. Health regeneration decreased to", health_regen)
		
		"ability_range":
			if card_data:
				card_data.ability_range -= amount
				print("Ability range buff expired. Ability range decreased to", card_data.ability_range)
			
		"all_stats":
			# Remove all the buffs that were applied
			_remove_buff("attack", amount)
			_remove_buff("health", amount * 10)
			_remove_buff("armor", amount / 2)
			_remove_buff("attack_speed", amount / 5)
			_remove_buff("move_speed", amount)
		
		_:
			print("Warning: Buff stat", stat, "not recognized during removal.")
	
	print("Buff on", self.name, "for", stat, "has ended.")

## Optional visual effect for buff application
#func flash_buff_visual_effect():
	## If you have a Sprite2D, make it flash briefly
	#if has_node("Sprite2D"):
		#var sprite = get_node("Sprite2D")
		#var original_modulate = sprite.modulate
		#
		## Flash green for buff
		#sprite.modulate = Color(0.5, 1.0, 0.5, 1.0)  # Light green
		#
		## Create a timer to restore original color
		#var timer = get_tree().create_timer(0.2)
		#timer.timeout.connect(func(): sprite.modulate = original_modulate)

# Function to apply a blind effect
# In Creature.gd
# This is your apply_blind function
# Function to apply a blind effect
func apply_blind(miss_chance: float, duration: float) -> void:
	print("apply_blind called with miss_chance=" + str(miss_chance) + ", duration=" + str(duration))
	
	# If no current blind effect or new one is stronger, make it the primary
	if !is_blinded || miss_chance > blind_miss_chance:
		# If we already have a blind effect, move it to secondary
		if is_blinded:
			# Store the current effect to secondary array
			secondary_blind_effects.append({
				"miss_chance": blind_miss_chance,
				"timer": blind_timer
			})
		
		# Set the new effect as primary
		is_blinded = true
		blind_miss_chance = miss_chance
		blind_timer = duration
		
		# Apply visual effect
		if has_node("Sprite2D"):
			var sprite = get_node("Sprite2D")
			sprite.modulate = Color(sprite.modulate.r, sprite.modulate.g, sprite.modulate.b, 0.5)
			
		print(name + " is blinded with " + str(miss_chance * 100) + "% miss chance for " + str(duration) + " seconds")
	else:
		# New effect is weaker, add to secondary array
		secondary_blind_effects.append({
			"miss_chance": miss_chance,
			"timer": duration
		})
		print(name + " has secondary blind effect added: " + str(miss_chance * 100) + "% for " + str(duration) + " seconds")
		
		
func separate_same_group() -> bool:
	# Determine which group to check.
	var group_name = "ally_creatures" if is_in_group("ally_creatures") else "enemy_creatures"
	var neighbors = get_tree().get_nodes_in_group(group_name)
	
	var total_adjustment: Vector2 = Vector2.ZERO
	var did_adjust: bool = false
	
	# For each neighbor, if too close, compute an adjustment.
	for neighbor in neighbors:
		if neighbor == self:
			continue
		var d: float = global_position.distance_to(neighbor.global_position)
		if d < MIN_SEPARATION_DISTANCE and d > 0:
			var diff: Vector2 = global_position - neighbor.global_position
			# For stationary neighbors, steer perpendicularly.
			if not neighbor.can_move:
				# Compute two perpendicular directions.
				var perp1: Vector2 = diff.rotated(PI / 2)
				var perp2: Vector2 = diff.rotated(-PI / 2)
				# Determine desired movement direction. Default to right.
				var desired: Vector2 = Vector2.RIGHT
				if target_ally and ally_summoner:
					desired = (ally_summoner.global_position - global_position).normalized()
				elif opponent_summoner:
					desired = (opponent_summoner.global_position - global_position).normalized()
				# Choose the perpendicular that deviates less from the desired direction.
				var angle1: float = abs(perp1.angle_to(desired))
				var angle2: float = abs(perp2.angle_to(desired))
				var chosen: Vector2 = perp1 if angle1 < angle2 else perp2
				# Scale adjustment: the closer the neighbor, the stronger the force.
				total_adjustment += chosen.normalized() * (move_speed * SEPARATION_STRENGTH / d) * get_process_delta_time()
			else:
				# For moving neighbors, use a simple repulsive force.
				total_adjustment += diff.normalized() * (move_speed * SEPARATION_STRENGTH / d) * get_process_delta_time()
			did_adjust = true
	
	if did_adjust and total_adjustment != Vector2.ZERO:
		global_position += total_adjustment
		print("Applied separation adjustment:", total_adjustment)
		return true
	
	return false




# Function to return the ability description for display
func get_ability_description() -> String:
	return ability_description




func execute_abilities_by_trigger(trigger: String) -> void:
	var executed_any = false
	
	for ability in abilities:
		if ability.should_trigger(trigger):
			ability.execute(self)
			executed_any = true
	
	# If this was a mana-based trigger and we executed at least one ability, reset mana
	if trigger == "on_max_mana" and executed_any:
		mana = 0.0
		update_mana_bar()


# Check if the creature is within attack range of the target (opponent's shield or enemy creature)
func is_in_attack_range(current_position: Vector2) -> bool:
	if opponent_summoner != null:
		var distance_to_target = current_position.distance_to(opponent_summoner.global_position)
		var shield_radius = 0

		# Check if the opponent summoner has a CollisionShape2D (get the shield radius if it's a circle)
		for child in opponent_summoner.get_children():
			if child is CollisionShape2D:
				var collision_shape = child as CollisionShape2D
				if collision_shape.shape is CircleShape2D:
					shield_radius = collision_shape.shape.radius
					break

		# Check if the creature is within attack range
		return distance_to_target <= (attack_range + shield_radius + 25)  # Add a buffer if necessary
	return false

func is_ally(collider: Object) -> bool:
	# Make sure collider is a creature with a CollisionShape2D
	if collider is CollisionShape2D:
		var parent_creature = collider.get_parent()  # Get the Area2D parent node
		if parent_creature is Area2D:
			# Check if the collider and this creature are both in the ally group
			return parent_creature.is_in_group("ally_creatures") and self.is_in_group("ally_creatures")
	return false



#	# Regenerate health if needed
#	if health_regen > 0:
#		health += health_regen * delta
#		health = min(health, 100)  # Limit to max health (adjust as necessary)



# Helper function to get the bounding rectangle from a CollisionShape2D
func get_collision_shape_rect(collision_shape: CollisionShape2D) -> Rect2:
	if collision_shape.shape is RectangleShape2D:
		var rect_shape = collision_shape.shape as RectangleShape2D
		var extents = rect_shape.extents
		var top_left = collision_shape.global_position - extents
		return Rect2(top_left, extents * 2)
	else:
		print("Warning: Not using a RectangleShape2D.")
		return Rect2()  # Return an empty Rect2 if not rectangular





func _on_opponent_summoner_shield_area_entered(area: Area2D):
	print("Collided with:", area.name, "Instance ID:", area.get_instance_id(), "Type:", typeof(area))
	if area == opponent_summoner:
		print("Creature collided with opponent's shield!")
		
		# Deal damage based on fusion level
		var damage_amount = 100 * card_data.fusion_level
		opponent_summoner.take_damage(damage_amount)
		
		print("Creature " + name + " dealt " + str(damage_amount) + 
			  " damage to shield and sacrificed itself")
		
		# Creature dies after dealing damage
		die()
	else:
		print("Collided with:", area.name)


# Move towards the opponent's shield
func move_towards_opponent(delta):
	if opponent_summoner == null:
		print("No opponent summoner assigned")
		return


	## Check for wall collisions using RayCast2D nodes
	if ray_n.is_colliding() or ray_ne.is_colliding() or ray_e.is_colliding() or ray_se.is_colliding() or ray_s.is_colliding() or ray_sw.is_colliding() or ray_w.is_colliding() or ray_nw.is_colliding():
		print("Wall detected, adjusting path!")
		avoid_wall(delta)  # Custom function to avoid the wall
		return

	# If no wall, move towards the shield as normal


	var opponent_position = opponent_summoner.global_position
	var direction = (opponent_position - global_position).normalized()
	var distance_to_target = global_position.distance_to(opponent_position)

	# Initialize shield_radius
	var shield_radius = 0

	# Check if the opponent summoner has a CollisionShape2D as a child
	for child in opponent_summoner.get_children():
		if child is CollisionShape2D:
			var collision_shape = child as CollisionShape2D
			if collision_shape.shape is CircleShape2D:
				shield_radius = collision_shape.shape.radius
				break

	# Adjust stopping distance to account for the shield's radius and attack range
	var stop_distance = shield_radius + attack_range + 25

	# If within the calculated stopping distance, start attacking
	if distance_to_target <= stop_distance:
		current_target = opponent_summoner
		can_move = false  # Stop movement when attacking
		attack_opponent(delta)
	else:
		# Move the creature towards the opponent summoner
		global_position += direction * move_speed * delta


# Function to avoid walls based on which raycast is colliding
func avoid_wall(delta):
	var adjustment = Vector2.ZERO
#
	# Adjust the movement direction based on the raycast that's colliding
	if ray_n.is_colliding():
		adjustment.y += move_speed * delta
	elif ray_s.is_colliding():
		adjustment.y -= move_speed * delta
	elif ray_e.is_colliding():
		adjustment.x -= move_speed * delta
	elif ray_w.is_colliding():
		adjustment.x += move_speed * delta
	elif ray_ne.is_colliding():
		adjustment.x -= move_speed * delta
		adjustment.y += move_speed * delta
	elif ray_nw.is_colliding():
		adjustment.x += move_speed * delta
		adjustment.y += move_speed * delta
	elif ray_se.is_colliding():
		adjustment.x -= move_speed * delta
		adjustment.y -= move_speed * delta
	elif ray_sw.is_colliding():
		adjustment.x += move_speed * delta
		adjustment.y -= move_speed * delta

	# Apply the adjustment to avoid the wall
	global_position += adjustment




# Handle aggrozone detection with random attack delay for first attack
func _on_aggrozone_entered(area: Area2D):
	# Skip self reference and spells
	if area == self or area.is_in_group("ally_spells") or area.is_in_group("enemy_spells"):
		return
		
	# Only consider enemy creatures
	if not (area.is_in_group("ally_creatures") or area.is_in_group("enemy_creatures")):
		return

	# Compute the distance between this creature and the incoming area.
	var d = global_position.distance_to(area.global_position)
	
	# If valid enemy, set as target but don't immediately stop movement
	if is_in_group("ally_creatures") and area.is_in_group("enemy_creatures"):
		current_target = area
		print("Detected enemy creature. Distance:", d, "Attack range:", attack_range)
		# Don't set can_move = false immediately
	elif is_in_group("enemy_creatures") and area.is_in_group("ally_creatures"):
		current_target = area
		print("Detected ally creature. Distance:", d, "Attack range:", attack_range)
		# Don't set can_move = false immediately
		
		
# Handle aggrozone exit (stop targeting the creature when it leaves)
func _on_aggrozone_exited(area: Area2D):
	if current_target == area:
		current_target = null  # Reset the target if it exits the zone
		print("Lost target. Refocusing on shield.")
		can_move = true  # Resume moving towards the shield if no enemies are around

# Add this to your Creature class if it doesn't already exist
# Add this property to the Creature class
var burn_stacks: int = 0

# Add this method to handle applying burn stacks
func apply_burn_stacks(stacks: int) -> void:
	burn_stacks += stacks
	print("Burn stacks on", self.name, "increased to", burn_stacks)
	
	# If this is the first application of burn, start the burn tick process
	if burn_stacks > 0 and not has_meta("burn_ticking"):
		set_meta("burn_ticking", true)
		_process_burn_tick()

# Process a single burn tick
func _process_burn_tick() -> void:
	if burn_stacks <= 0:
		remove_meta("burn_ticking")
		print("Burn effect on", self.name, "has ended.")
		return
	
	# Apply damage equal to current number of burn stacks
	take_damage(burn_stacks)
	print("Burn tick on", self.name, "for", burn_stacks, "damage")
	
	# Reduce stacks by 1
	burn_stacks -= 1
	print("Burn stacks reduced to", burn_stacks)
	
	# Schedule the next tick after the tick interval (0.5 seconds by default)
	var timer = get_tree().create_timer(0.5)
	timer.timeout.connect(Callable(self, "_process_burn_tick"))

# Attack logic
# Attack logic
func attack_opponent(delta):
	# Check if target is a shield (summoner)
	if current_target == opponent_summoner:
		# Handle shield collision with fusion-based damage
		var damage_amount = 100 * card_data.fusion_level
		opponent_summoner.take_damage(damage_amount)
		print(name + " sacrificed itself and dealt " + str(damage_amount) + " damage to shield!")
		die()
		return
	
	# Check if target is in attack range, if not, move towards it
	if current_target != null:
		var distance_to_target = global_position.distance_to(current_target.global_position)
		
		# If beyond attack range, move towards target
		if distance_to_target > attack_range:
			# We're in aggrozone but not yet in attack range - move towards target
			var direction = (current_target.global_position - global_position).normalized()
			global_position += direction * move_speed * delta
			print("Moving towards target: distance =", distance_to_target, ", attack_range =", attack_range)
			return
	
	# Only proceed with attack if we have a target and we're close enough
	if current_target == null:
		return
		
	# Add this debug line right before the blindness check
	print("DEBUG: Attack check - is_blinded=" + str(is_blinded) + ", blind_miss_chance=" + str(blind_miss_chance))
	
	# Check if blinded and determine if attack misses
	if is_blinded && randf() < blind_miss_chance:
		# Attack misses due to blindness
		print("DEBUG: Miss condition triggered - blind roll: " + str(randf()) + " < " + str(blind_miss_chance))
		attack_timer -= delta
		if attack_timer <= 0.0:
			attack_timer = 1.0 / attack_speed
			print(name + " missed attack due to blindness!")
			
			# Visual effect for missed attack
			var miss_label = Label.new()
			miss_label.text = "MISS!"
			miss_label.position = Vector2(0, -30)
			miss_label.modulate = Color(1, 0, 0)
			add_child(miss_label)
			
			# Create a reference to self that will be captured in the lambda
			var creature_ref = self
			
			# Remove the label after a short time, but check if the creature still exists
			var timer = get_tree().create_timer(0.8)
			timer.timeout.connect(func():
				# Check if the creature and label still exist
				if is_instance_valid(creature_ref) and is_instance_valid(miss_label):
					miss_label.queue_free()
			)
			
		return
		
	if first_attack:
		attack_timer -= delta
	if attack_timer <= 0.0:
		attack_timer = 1.0 / attack_speed
		first_attack = false
		if current_target != null and current_target.has_method("take_damage"):
			# Get attacker's combat type
			var attacker_type = ""
			if card_data != null:
				# Check if the property exists before accessing it
				if "combat_type" in card_data:
					attacker_type = card_data.combat_type
			
			current_target.take_damage(attack, attacker_type)
			execute_abilities_by_trigger("on_attack")
			print("Dealing", attack, "damage to target on first attack as", attacker_type)
	else:
	# Subsequent attacks
		attack_timer -= delta
	if attack_timer <= 0.0:
		attack_timer = 1.0 / attack_speed
		if current_target != null and current_target.has_method("take_damage"):
			# Get attacker's combat type
			var attacker_type = ""
			if card_data != null:
				# Check if the property exists before accessing it
				if "combat_type" in card_data:
					attacker_type = card_data.combat_type
			
			current_target.take_damage(attack, attacker_type)
			print("Dealing", attack, "damage to target as", attacker_type)

# In creature.gd, modify the take_damage function
func take_damage(damage_amount: int, attacker_type: String = ""):
	var final_damage = damage_amount
	
	# Apply type advantage if attacker_type is provided
	if attacker_type != "" and card_data and card_data.combat_type != "":
		var combat_manager = get_node("/root/CombatAdvantageManager")
		if combat_manager:
			var multiplier = combat_manager.get_damage_multiplier(attacker_type, card_data.combat_type)
			final_damage = int(final_damage * multiplier)
			
			# Display type advantage message if applicable
			if multiplier > 1.0:
				print("Type advantage! " + attacker_type + " is strong against " + card_data.combat_type)

	
	# Apply armor reduction
	final_damage = max(final_damage - armor, 0)
	
	health -= final_damage
	print("Creature took", final_damage, "damage. Remaining health:", health)
	
	# Update the health bar
	update_health_bar()
	
	if health <= 0:
		die()

var on_death_triggered: bool = false

func die():
	# Only execute on-death abilities once
	if not on_death_triggered:
		on_death_triggered = true
		execute_abilities_by_trigger("on_death")
	queue_free()
	print("Creature has died.")



# Handle the input event and emit the custom signal
func _on_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed:
		print("Click detected directly on Creature instance.")
		# Emit the custom creature_clicked signal, passing `self` as the creature reference
		emit_signal("creature_clicked", self)




# Returns an Array of all targets in range.
# target_type should be either "ally" or "enemy".
# If include_self is true and target_type is "ally", the caster (self) will be included.
func find_targets_in_range(range: float, target_type: String, include_self: bool = false) -> Array:
	var space_state = get_world_2d().direct_space_state
	var circle = CircleShape2D.new()
	circle.radius = range
	var query = PhysicsShapeQueryParameters2D.new()
	query.transform = Transform2D.IDENTITY.translated(global_position)
	query.shape = circle
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 0xFFFFFFFF
	# Exclude self if we don't want to include it.
	if not include_self:
		query.exclude = [self]
	
	var results = space_state.intersect_shape(query)
	var targets: Array = []
	for result in results:
		var collider = result.collider
		if collider:
			# For allies, both must be on the same side.
			if target_type == "ally":
				if ((is_in_group("ally_creatures") and collider.is_in_group("ally_creatures")) or
					(is_in_group("enemy_creatures") and collider.is_in_group("enemy_creatures"))):
					targets.append(collider)
			# For enemies, they must be on opposite sides.
			elif target_type == "enemy":
				if ((is_in_group("ally_creatures") and collider.is_in_group("enemy_creatures")) or
					(is_in_group("enemy_creatures") and collider.is_in_group("ally_creatures"))):
					targets.append(collider)
	return targets

# Returns the closest target (or null if none found) from the targets found using find_targets_in_range().
# Ensure this function properly handles the affects_self parameter
func find_closest_target_in_range(range: float, target_type: String, include_self: bool = false) -> Node:
	var targets = find_targets_in_range(range, target_type, include_self)
	if include_self and target_type == "ally":
		# Make sure "self" is included if requested
		var self_included = false
		for t in targets:
			if t == self:
				self_included = true
				break
		if !self_included:
			targets.append(self)
			print("Explicitly adding self to targets list")
	
	if targets.size() > 0:
		var closest = targets[0]
		var closest_dist = global_position.distance_to(closest.global_position)
		for t in targets:
			var d = global_position.distance_to(t.global_position)
			if d < closest_dist:
				closest = t
				closest_dist = d
		return closest
	return null


# For compatibility with existing code:
func find_valid_enemy_target_in_range(range: float) -> Node:
	return find_closest_target_in_range(range, "enemy", false)

func find_all_allied_targets_in_range(range: float, include_self: bool = false) -> Array:
	return find_targets_in_range(range, "ally", include_self)


# In creature.gd
func update_animation(velocity: Vector2):
	# Skip if not using animations
	if !card_data or !card_data.has_animations:
		print("Animation skipped: no card_data or animations not enabled")
		return
	
	# Get the correct sprite reference - check for both possible names
	var sprite = null
	if has_node("AnimatedSprite2D"):
		sprite = $AnimatedSprite2D
	elif has_node("HeroSprite"):
		sprite = $HeroSprite
	
	if sprite == null:
		print("Animation error: Could not find sprite node")
		return
	
	# Handle stopped state
	if velocity.length() < 0.1:
		if sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")
			print("Playing idle animation (hero stopped)")
		else:
			sprite.play("default")
			print("Playing default animation (hero stopped, no idle animation)")
		return
	
	# Convert movement vector to direction name
	var iso_direction = convert_to_isometric_direction(velocity)
	print("Movement direction: " + iso_direction + " from velocity: " + str(velocity))
	
	# Try specific direction animation
	var anim_name = "move_" + iso_direction
	if sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
		print("Playing direction-specific animation: " + anim_name)
		return
	
	# For diagonal directions, fall back to cardinal direction
	if iso_direction.length() > 1:
		# For diagonals like "ne", try just "e"
		var cardinal = iso_direction[1]  # Get second character (e.g., "e" from "ne")
		var cardinal_anim = "move_" + cardinal
		
		if sprite.sprite_frames.has_animation(cardinal_anim):
			sprite.play(cardinal_anim)
			print("Playing cardinal fallback animation: " + cardinal_anim)
			return
	
	# Last resort - use default animation
	sprite.play("default")
	print("Playing default animation (no suitable directional animation found)")

func convert_to_isometric_direction(velocity: Vector2) -> String:
	# Convert world-space velocity to isometric-space direction
	var dir = velocity.normalized()
	
	# Isometric angle calculation
	# Taking the dot product with the isometric axes
	# The standard isometric view has main axes at 30° above/below the horizontal
	var iso_x = dir.x
	var iso_y = dir.y * 2  # Y is half scale in isometric projection
	
	# Calculate the angle in the isometric plane
	var angle = atan2(iso_y, iso_x)
	
	# Convert angle to 8 compass directions
	# Adjust these angles based on your specific isometric projection
	if angle < -2.7: return "w"
	if angle < -1.9: return "nw"
	if angle < -0.7: return "n" 
	if angle < 0.0: return "ne"
	if angle < 0.7: return "e"
	if angle < 1.9: return "se"
	if angle < 2.7: return "s"
	return "sw"


## In Creature.gd
#func _on_creature_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	## Check if the input event is a mouse button press
	#if event is InputEventMouseButton and event.pressed:
		## Verify if it’s a left-click (button index 1 is usually the left mouse button)
		#if event.button_index == MOUSE_BUTTON_LEFT:
			#print("Creature clicked!")
			## Emit the creature_clicked signal with `self` as the parameter
			#emit_signal("creature_clicked", self)
