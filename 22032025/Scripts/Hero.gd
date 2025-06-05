extends "res://Scripts/creature.gd"
class_name Hero

# Hero-specific properties
var is_selected: bool = false
var move_target: Vector2 = Vector2.ZERO
var attack_target: Area2D = null



# Add to the Hero.gd script
func _ready():
	super._ready()
	
	# Force the hero to be part of ally_creatures group
	add_to_group("ally_creatures")
	
	print("SPRITE: Hero initialization")
	print("SPRITE: Hero global position: " + str(global_position))
	
	# Get reference to AnimatedSprite2D and attach it to the hero's Node2D
	if card_data and card_data.get("has_animations") and card_data.get("animation_frames"):
		# First make sure we don't already have a sprite in use
		if has_node("Sprite2D"):
			# Remove the existing sprite that's not working correctly
			$Sprite2D.queue_free()
			await get_tree().process_frame
		
		# Create a new sprite directly as a child of this node
		var new_sprite = AnimatedSprite2D.new()
		new_sprite.name = "HeroSprite"
		new_sprite.z_index = 10  # Ensure visibility
		new_sprite.scale = Vector2(0.15, 0.15)  # Reasonable scale
		
		# Add it as a child to inherit transform
		add_child(new_sprite)
		
		# Assign the sprite frames
		new_sprite.sprite_frames = card_data.animation_frames
		
		# Start playing animation
		new_sprite.play("default")
		
		print("SPRITE: Created new sprite attached to hero hierarchy")
		print("SPRITE: Hero position: " + str(global_position))
		print("SPRITE: New sprite global position: " + str(new_sprite.global_position))
	
	# Set up position verification in the next frame
	await get_tree().process_frame
	if has_node("HeroSprite"):
		print("SPRITE: After frame - Hero position: " + str(global_position))
		print("SPRITE: After frame - Sprite position: " + str($HeroSprite.global_position))
	
	# Disable automatic movement and targeting
	can_move = false
	if movement_system:
		movement_system.can_move = false
	
	# Connect to click events
	connect("input_event", Callable(self, "_on_hero_input_event"))
	

	


# In Hero.gd - Update the _on_hero_input_event function
func _on_hero_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Select the hero
			select()
			
			# Emit signal to show hero info in descriptive box
			emit_signal("creature_clicked", self)
			print("Hero emitted creature_clicked signal")
			
			# Prevent event propagation
			get_viewport().set_input_as_handled()
# Process player input and update hero behavior
func _process(delta):
	# Skip if frozen (during preparation phase)
	if is_frozen:
		return
		
	# Process mana regeneration and abilities
	mana += mana_regen * delta
	if mana > max_mana:
		mana = max_mana
	update_mana_bar()
	
	# Handle passive abilities
	execute_abilities_by_trigger("passive_update")
	
	# Process blind effect if applicable
	process_blind_effects(delta)
	
	# Handle movement to target position if selected
	if is_selected and move_target != Vector2.ZERO:
		move_towards_target(delta)
	
	# Handle attacking target if one is set
	if attack_target != null and is_instance_valid(attack_target):
		attack_current_target(delta)
	else:
		# Reset attack timer if no target
		attack_timer = 0.0
		attack_target = null

# Handle player selection of the hero
func select():
	is_selected = true
	var selection_circle = get_node_or_null("SelectionCircle")
	if selection_circle:
		selection_circle.visible = true
	print("Hero selected")

# Handle player deselection of the hero
func deselect():
	is_selected = false
	var selection_circle = get_node_or_null("SelectionCircle")
	if selection_circle:
		selection_circle.visible = false
	print("Hero deselected")

func move_towards_target(delta):
	# Calculate direction and distance
	var direction = (move_target - global_position).normalized()
	var distance = global_position.distance_to(move_target)
	
	# Check if we've arrived at the target
	if distance < 5.0:  # Close enough to target
		move_target = Vector2.ZERO
		return
	
	# Move towards target
	global_position += direction * move_speed * delta
	
	# Update animation based on movement direction
	update_animation(direction * move_speed)
	
	# If we have an attack target but are moving, check if we're in range
	if attack_target != null and is_instance_valid(attack_target):
		if global_position.distance_to(attack_target.global_position) <= attack_range:
			# We're in range, stop moving
			move_target = Vector2.ZERO

# Process blind effects (simplified from creature.gd)
func process_blind_effects(delta):
	if is_blinded:
		blind_timer -= delta
		if blind_timer <= 0:
			# Handle blind expiry logic
			if secondary_blind_effects.size() > 0:
				# Handle secondary blind effects
				secondary_blind_effects.sort_custom(func(a, b): return a.miss_chance > b.miss_chance)
				var next_effect = secondary_blind_effects.pop_front()
				blind_miss_chance = next_effect.miss_chance
				blind_timer = next_effect.timer
			else:
				# Remove blind completely
				is_blinded = false
				blind_miss_chance = 0.0
				blind_timer = 0.0
				if has_node("Sprite2D"):
					var sprite = get_node("Sprite2D")
					sprite.modulate = Color(sprite.modulate.r, sprite.modulate.g, sprite.modulate.b, 1.0)
	
	# Update secondary blind effects
	for i in range(secondary_blind_effects.size() - 1, -1, -1):
		var effect = secondary_blind_effects[i]
		effect.timer -= delta
		if effect.timer <= 0:
			secondary_blind_effects.remove_at(i)

# Attack the current target
# Replace/update attack_current_target in Hero.gd
func attack_current_target(delta):
	if attack_target == null or not is_instance_valid(attack_target):
		print("Attack target no longer valid")
		attack_target = null
		return
		
	var distance = global_position.distance_to(attack_target.global_position)
	print("Distance to target: " + str(distance) + ", attack range: " + str(attack_range))
	
	# Check if target is in range
	if distance <= attack_range:
		print("Target in range, processing attack")
		# Process attack cooldown
		attack_timer -= delta
		if attack_timer <= 0.0:
			print("Attack timer ready, attacking")
			# Reset cooldown timer
			attack_timer = 1.0 / attack_speed
			
			# Check for blindness effect
			if is_blinded and randf() < blind_miss_chance:
				# Attack missed due to blindness
				print(name + " missed attack due to blindness!")
				
				# Visual effect for missed attack
				var miss_label = Label.new()
				miss_label.text = "MISS!"
				miss_label.position = Vector2(0, -30)
				miss_label.modulate = Color(1, 0, 0)
				add_child(miss_label)
				
				# Remove the label after a short time
				var timer = get_tree().create_timer(0.8)
				timer.timeout.connect(func():
					if is_instance_valid(miss_label):
						miss_label.queue_free()
				)
				return
			
			# Deal damage if target can take damage
			if attack_target.has_method("take_damage"):
				# Get attacker's combat type
				var attacker_type = ""
				if card_data != null and "combat_type" in card_data:
					attacker_type = card_data.combat_type
				
				# Deal damage to target
				attack_target.take_damage(attack, attacker_type)
				
				# Trigger on_attack abilities
				execute_abilities_by_trigger("on_attack")
				
				print("Hero dealt " + str(attack) + " damage to " + attack_target.name)
				
				# Visual effect for successful attack
				var attack_line = Line2D.new()
				attack_line.add_point(Vector2.ZERO)
				attack_line.add_point(attack_target.global_position - global_position)
				attack_line.width = 2.0
				attack_line.default_color = Color(1.0, 0.3, 0.3, 0.8)
				add_child(attack_line)
				
				# Remove the line after a short time
				var timer = get_tree().create_timer(0.2)
				timer.timeout.connect(func():
					if is_instance_valid(attack_line):
						attack_line.queue_free()
				)
	else:
		# Target out of range, move towards it
		print("Target out of range, moving towards it")
		move_target = attack_target.global_position
		move_towards_target(delta)

# Set a new movement target (called from Main.gd)
func set_move_target(position: Vector2):
	move_target = position
	attack_target = null  # Clear attack target when moving
	print("Hero moving to: ", position)

# Set a new attack target (called from Main.gd)
func set_attack_target(target: Area2D):
	if target == self:
		print("Cannot attack self")
		return
		
	attack_target = target
	print("Hero attacking: ", target.name)
	
	# If target is out of range, move towards it
	var distance = global_position.distance_to(target.global_position)
	if distance > attack_range:
		move_target = target.global_position
		
		
		
