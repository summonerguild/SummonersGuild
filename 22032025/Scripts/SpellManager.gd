extends Node
class_name SpellManager

var main_node  # Reference to the main game node

func _init(main_reference):
	main_node = main_reference

func cast_spell(spell_data: carddata, target_position: Vector2, is_enemy_cast: bool = false) -> bool:
	if not spell_data or spell_data.card_type != "spell":
		print("Invalid spell data")
		return false
		
	print("Casting spell: ", spell_data.name)
	
	# If the spell has abilities, use them directly (similar to creatures)
	if spell_data.abilities.size() > 0:
		var success = execute_spell_abilities(spell_data, target_position, is_enemy_cast)
		return success
	else:
		# Fallback to basic spell types if no abilities are defined
		match spell_data.spell_effect_type:
			"damage":
				return cast_damage_spell(spell_data, target_position, is_enemy_cast)
			"heal":
				return cast_heal_spell(spell_data, target_position, is_enemy_cast)
			"buff":
				return cast_buff_spell(spell_data, target_position, is_enemy_cast)
			"burn":
				return cast_burn_spell(spell_data, target_position, is_enemy_cast)
			_:
				print("Unknown spell effect type: ", spell_data.spell_effect_type)
				return false

# Execute spell abilities - similar to how creatures execute their abilities
func execute_spell_abilities(spell_data: carddata, target_position: Vector2, is_enemy_cast: bool) -> bool:
	var success = false
	
	# Create a temporary node to hold the spell's position and execute abilities
	var spell_node = Node2D.new()
	spell_node.global_position = target_position
	main_node.add_child(spell_node)
	
	# Set up the spell node to target correctly based on who cast it
	if is_enemy_cast:
		spell_node.add_to_group("enemy_spells_targeting")  # Use spell-specific group
	else:
		spell_node.add_to_group("ally_spells_targeting")  # Use spell-specific group
	
	# Add necessary properties and methods that abilities might expect
	# Instead of directly assigning properties, use a metadata approach
	spell_node.set_meta("card_data", spell_data)
	spell_node.set_meta("current_target", null)
	spell_node.set_meta("is_enemy_cast", is_enemy_cast)  # Store this for targeting logic
	
	# Also add a method to access the metadata as if it were a property
	spell_node.get_card_data = func(): return spell_node.get_meta("card_data")
	spell_node.current_target = null  # This is okay because it's a null assignment
	
	# Add find_targets method similar to the one in Creature
	spell_node.find_targets_in_range = func(range_val, target_type, include_self = false) -> Array:
		var targets = []
		var space_state = main_node.get_world_2d().direct_space_state
		var circle = CircleShape2D.new()
		circle.radius = range_val
		var query = PhysicsShapeQueryParameters2D.new()
		query.transform = Transform2D.IDENTITY.translated(spell_node.global_position)
		query.shape = circle
		query.collide_with_areas = true
		query.collide_with_bodies = true
		
		var results = space_state.intersect_shape(query)
		for result in results:
			var collider = result.collider
			if collider == spell_node:
				continue
				
			# Skip other spells (visual objects)
			if collider.is_in_group("ally_spells") or collider.is_in_group("enemy_spells"):
				continue
				
			# Calculate distance to check if truly within radius
			var distance = spell_node.global_position.distance_to(collider.global_position)
			if distance > range_val:
				continue
			
			# Get whether we're an enemy cast from metadata
			var is_enemy = spell_node.get_meta("is_enemy_cast")
			
			# Filter based on target type and caster faction
			if target_type == "enemy":
				if ((!is_enemy and collider.is_in_group("enemy_creatures")) or
					(is_enemy and collider.is_in_group("ally_creatures"))):
					targets.append(collider)
			elif target_type == "ally":
				if ((!is_enemy and collider.is_in_group("ally_creatures")) or
					(is_enemy and collider.is_in_group("enemy_creatures"))):
					targets.append(collider)
		
		return targets
	
	# Add find_closest_target method for single-target spells
	spell_node.find_closest_target_in_range = func(range_val, target_type, include_self = false) -> Node:
		var targets = spell_node.find_targets_in_range.call(range_val, target_type, include_self)
		if targets.size() > 0:
			var closest = targets[0]
			var closest_dist = spell_node.global_position.distance_to(closest.global_position)
			for t in targets:
				var dist = spell_node.global_position.distance_to(t.global_position)
				if dist < closest_dist:
					closest = t
					closest_dist = dist
			return closest
		return null
	
	# Execute each ability with "on_cast" trigger
	for ability in spell_data.abilities:
		if ability.has_method("should_trigger") and ability.should_trigger("on_cast"):
			# For compatibility, create references to any properties the ability might need
			if ability.has_method("execute"):
				# Patch the spell_node to better match what abilities expect
				spell_node.card_data = spell_node.get_meta("card_data")  # Temporarily add this for the execute call
				
				# Debug prints before execution
				print("SpellManager: Executing ability for spell: ", spell_data.name)
				print("SpellManager: Target position: ", target_position)
				print("SpellManager: Is enemy cast: ", is_enemy_cast)
				
				ability.execute(spell_node)
				
				# Remove the temporary property to avoid further errors
				@warning_ignore("unsafe_property_access")
				spell_node.card_data = null
				
				success = true
				
				# Create visual effect
				create_spell_visual_effect(target_position, spell_data)
	
	# Free the temporary node after execution
	spell_node.queue_free()
	
	return success

func cast_damage_spell(spell_data: carddata, target_position: Vector2, is_enemy_cast: bool) -> bool:
	# Get appropriate target group based on who cast the spell
	var target_group = "ally_creatures" if is_enemy_cast else "enemy_creatures"
	
	# Get all targets in the AOE radius
	var targets = find_targets_in_radius(target_position, spell_data.spell_aoe_radius, target_group)
	
	if targets.size() == 0:
		print("No valid targets found for damage spell")
		return false
		
	# Apply damage to all targets
	for target in targets:
		if target.has_method("take_damage"):
			target.take_damage(spell_data.spell_damage)
			print("Dealt ", spell_data.spell_damage, " damage to ", target.name)
			
	# Create visual effect
	create_spell_visual_effect(target_position, spell_data)
	
	return true

func cast_heal_spell(spell_data: carddata, target_position: Vector2, is_enemy_cast: bool) -> bool:
	# Get appropriate target group based on who cast the spell
	var target_group = "enemy_creatures" if is_enemy_cast else "ally_creatures"
	
	# Get all targets in the AOE radius
	var targets = find_targets_in_radius(target_position, spell_data.spell_aoe_radius, target_group)
	
	if targets.size() == 0:
		print("No valid targets found for heal spell")
		return false
		
	# Apply healing to all targets - assuming they have a receive_healing method
	for target in targets:
		if target.has_method("receive_healing"):
			target.receive_healing(spell_data.spell_damage)  # Using spell_damage for healing amount
			print("Healed ", spell_data.spell_damage, " to ", target.name)
		elif target.has_method("take_damage"):
			# Fallback: Negative damage = healing
			target.take_damage(-spell_data.spell_damage)
			print("Healed ", spell_data.spell_damage, " to ", target.name)
			
	# Create visual effect
	create_spell_visual_effect(target_position, spell_data, Color(0, 1, 0, 0.5))  # Green for healing
	
	return true

func cast_buff_spell(spell_data: carddata, target_position: Vector2, is_enemy_cast: bool) -> bool:
	# Get appropriate target group based on who cast the spell
	var target_group = "enemy_creatures" if is_enemy_cast else "ally_creatures"
	
	# Get all targets in the AOE radius
	var targets = find_targets_in_radius(target_position, spell_data.spell_aoe_radius, target_group)
	
	if targets.size() == 0:
		print("No valid targets found for buff spell")
		return false
		
	# Apply buff to all targets
	for target in targets:
		if target.has_method("apply_buff"):
			# Assuming ability_description contains buff info
			var buff_parts = spell_data.ability_description.split("|")
			if buff_parts.size() >= 3:
				var stat = buff_parts[0].strip_edges()
				var amount = float(buff_parts[1].strip_edges())
				var duration = float(buff_parts[2].strip_edges())
				
				target.apply_buff(stat, amount, duration)
				print("Applied buff to ", target.name, ": ", stat, " +", amount, " for ", duration, " seconds")
			
	# Create visual effect
	create_spell_visual_effect(target_position, spell_data, Color(0, 0, 1, 0.5))  # Blue for buff
	
	return true

func cast_burn_spell(spell_data: carddata, target_position: Vector2, is_enemy_cast: bool) -> bool:
	# Get appropriate target group based on who cast the spell
	var target_group = "ally_creatures" if is_enemy_cast else "enemy_creatures"
	
	# Get all targets in the AOE radius
	var targets = find_targets_in_radius(target_position, spell_data.spell_aoe_radius, target_group)
	
	if targets.size() == 0:
		print("No valid targets found for burn spell")
		return false
		
	# Apply burn to all targets
	for target in targets:
		if target.has_method("apply_burn_stacks"):
			target.apply_burn_stacks(spell_data.spell_damage)  # Using spell_damage for burn stacks
			print("Applied ", spell_data.spell_damage, " burn stacks to ", target.name)
			
	# Create visual effect
	create_spell_visual_effect(target_position, spell_data, Color(1, 0.5, 0, 0.5))  # Orange for burn
	
	return true

func find_targets_in_radius(center: Vector2, radius: float, target_group: String) -> Array:
	var targets = []
	var space_state = main_node.get_world_2d().direct_space_state
	
	var circle = CircleShape2D.new()
	circle.radius = radius
	
	var query = PhysicsShapeQueryParameters2D.new()
	query.transform = Transform2D.IDENTITY.translated(center)
	query.shape = circle
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
	var results = space_state.intersect_shape(query)
	
	for result in results:
		var collider = result.collider
		
		# Filter based on target group
		if collider.is_in_group(target_group):
			targets.append(collider)
			
	return targets

func create_spell_visual_effect(position: Vector2, spell_data: carddata, color = null):
	# Create a simple visual effect for the spell
	var effect = Node2D.new()
	effect.position = position
	
	# Add a sprite or particles based on spell type
	var circle = ColorRect.new()
	circle.material = CanvasItemMaterial.new()
	circle.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	
	# Set color based on spell type if not provided
	if color == null:
		color = Color(1, 0, 0, 0.5) # Default red for damage
		if spell_data.spell_effect_type == "heal":
			color = Color(0, 1, 0, 0.5) # Green for heal
		elif spell_data.spell_effect_type == "buff":
			color = Color(0, 0, 1, 0.5) # Blue for buff
		elif spell_data.spell_effect_type == "burn":
			color = Color(1, 0.5, 0, 0.5) # Orange for burn
	
	circle.color = color
	
	# Set size based on AOE radius
	var radius = spell_data.spell_aoe_radius if spell_data.has("spell_aoe_radius") else 100.0
	var size = Vector2(radius * 2, radius * 2)
	circle.size = size
	circle.position = -size/2 # Center the rectangle
	
	effect.add_child(circle)
	main_node.add_child(effect)
	
	# Create a timer to fade out and remove the effect
	var timer = main_node.get_tree().create_timer(0.5)
	timer.timeout.connect(func(): effect.queue_free())
	
	
	# Add this helper function to the SpellManager class
func safe_execute_ability(ability, target_node, spell_data):
	# Save the original target_node state
	var had_card_data = target_node.has_meta("card_data")
	
	# Set up the node for ability execution
	target_node.set_meta("card_data", spell_data)
	
	# Execute the ability
	var result = ability.execute(target_node)
	
	# Clean up if we added temporary data
	if !had_card_data:
		target_node.remove_meta("card_data")
		
	return result
