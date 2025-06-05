extends Area2D
class_name Spell

# Card data reference
var card_data: carddata = null

# Helper variables for targeting
var target_position: Vector2
var is_enemy_cast: bool = false

# Visual effect
var effect_sprite: Sprite2D

func _ready():
	# Initialize visual effect
	effect_sprite = $EffectSprite  # Assuming you add this to the scene
	
	# Execute spell effect immediately on creation
	execute_spell_effect()
	
	# Set up a timer to remove the spell after effects are done
	var timer = get_tree().create_timer(0.5)  # Adjust time as needed
	timer.timeout.connect(queue_free)

func initialize(spell_data: carddata, pos: Vector2, enemy_cast: bool = false):
	card_data = spell_data
	target_position = pos
	global_position = pos
	is_enemy_cast = enemy_cast
	
	# Add to spell-specific groups
	if is_enemy_cast:
		add_to_group("enemy_spells")
	else:
		add_to_group("ally_spells")
	
	# IMPORTANT: Also add to creature groups for targeting compatibility
	# but make sure other code knows to ignore when considering movement targets
	if is_enemy_cast:
		add_to_group("enemy_spells_targeting")  # New group for targeting logic
	else:
		add_to_group("ally_spells_targeting")   # New group for targeting logic
	
	return self

func execute_spell_effect():
	if card_data:
		# Execute each ability with "on_cast" trigger
		for ability in card_data.abilities:
			if ability.should_trigger("on_cast"):
				ability.execute(self)
	
	# Display visual effect based on spell type
	show_visual_effect()

# Add this function to Spell.gd
func find_closest_target_in_range(range_val: float, target_type: String, include_self: bool = false) -> Node:
	var targets = find_targets_in_range(range_val, target_type, include_self)
	if targets.size() > 0:
		var closest = targets[0]
		var closest_dist = global_position.distance_to(closest.global_position)
		for target in targets:
			var dist = global_position.distance_to(target.global_position)
			if dist < closest_dist:
				closest = target
				closest_dist = dist
		return closest
	return null


func show_visual_effect():
	# Create appropriate visual based on spell type
	if card_data and card_data.get("spell_effect_type") != null:
		if card_data.spell_effect_type == "damage":
			create_damage_effect()
		elif card_data.spell_effect_type == "heal":
			create_heal_effect()
		elif card_data.spell_effect_type == "buff":
			create_buff_effect()
		elif card_data.spell_effect_type == "burn":
			create_burn_effect()
		else:
			create_default_effect()
	else:
		create_default_effect()

func create_damage_effect():
	# Create a red circular effect
	var circle = ColorRect.new()
	circle.material = CanvasItemMaterial.new()
	circle.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	circle.color = Color(1, 0, 0, 0.5)  # Red for damage
	
	# Set size based on AOE radius
	var radius = card_data.get("spell_aoe_radius") if card_data.get("spell_aoe_radius") != null else 100.0
	var size = Vector2(radius * 2, radius * 2)
	circle.size = size
	circle.position = -size/2  # Center the rectangle
	
	add_child(circle)

func create_heal_effect():
	# Create a green circular effect
	var circle = ColorRect.new()
	circle.material = CanvasItemMaterial.new()
	circle.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	circle.color = Color(0, 1, 0, 0.5)  # Green for healing
	
	# Set size based on AOE radius
	var radius = card_data.get("spell_aoe_radius") if card_data.get("spell_aoe_radius") != null else 100.0
	var size = Vector2(radius * 2, radius * 2)
	circle.size = size
	circle.position = -size/2  # Center the rectangle
	
	add_child(circle)

func create_buff_effect():
	# Create a blue circular effect
	var circle = ColorRect.new()
	circle.material = CanvasItemMaterial.new()
	circle.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	circle.color = Color(0, 0, 1, 0.5)  # Blue for buffs
	
	# Set size based on AOE radius
	var radius = card_data.get("spell_aoe_radius") if card_data.get("spell_aoe_radius") != null else 100.0
	var size = Vector2(radius * 2, radius * 2)
	circle.size = size
	circle.position = -size/2  # Center the rectangle
	
	add_child(circle)

func create_burn_effect():
	# Create an orange circular effect
	var circle = ColorRect.new()
	circle.material = CanvasItemMaterial.new()
	circle.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	circle.color = Color(1, 0.5, 0, 0.5)  # Orange for burn
	
	# Set size based on AOE radius
	var radius = card_data.get("spell_aoe_radius") if card_data.get("spell_aoe_radius") != null else 100.0
	var size = Vector2(radius * 2, radius * 2)
	circle.size = size
	circle.position = -size/2  # Center the rectangle
	
	add_child(circle)

func create_default_effect():
	# Create a purple circular effect as default
	var circle = ColorRect.new()
	circle.material = CanvasItemMaterial.new()
	circle.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	circle.color = Color(0.8, 0.3, 0.8, 0.5)  # Purple for generic spell
	
	# Use a default radius
	var radius = 100.0
	var size = Vector2(radius * 2, radius * 2)
	circle.size = size
	circle.position = -size/2  # Center the rectangle
	
	add_child(circle)

# Target finding methods similar to your Creature class
func find_targets_in_range(range_val: float, target_type: String, include_self: bool = false) -> Array:
	var targets = []
	var space_state = get_world_2d().direct_space_state
	
	# Create a circle shape with the specified radius
	var circle = CircleShape2D.new()
	circle.radius = range_val
	
	# Setup the query parameters
	var query = PhysicsShapeQueryParameters2D.new()
	query.transform = Transform2D.IDENTITY.translated(global_position)
	query.shape = circle
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
	# Debug output
	print("Spell: Finding targets with radius:", range_val, "at position:", global_position)
	
	# Perform the shape query to find potential targets
	var results = space_state.intersect_shape(query)
	print("Spell: Found", results.size(), "potential targets")
	
	# Process results to filter valid targets
	for result in results:
		var collider = result.collider
		if collider == self and not include_self:
			continue
		
		# Skip other spells
		if collider.is_in_group("ally_spells") or collider.is_in_group("enemy_spells"):
			continue
		
		# Calculate distance to check if truly within radius
		var distance = global_position.distance_to(collider.global_position)
		print("Target:", collider.name, "Distance:", distance, "Radius:", range_val)
		
		if distance > range_val:
			print("Target outside radius, skipping")
			continue
			
		# Filter based on target type - use is_enemy_cast to determine friend/foe
		if target_type == "enemy":
			if ((!is_enemy_cast and collider.is_in_group("enemy_creatures")) or
				(is_enemy_cast and collider.is_in_group("ally_creatures"))):
				targets.append(collider)
				print("Valid enemy target found:", collider.name)
		elif target_type == "ally":
			if ((!is_enemy_cast and collider.is_in_group("ally_creatures")) or
				(is_enemy_cast and collider.is_in_group("enemy_creatures"))):
				targets.append(collider)
				print("Valid ally target found:", collider.name)
	
	print("Spell: Final valid targets:", targets.size())
	return targets
