extends Ability
class_name OnMaxManaRangedDamageAbility

# Default bonus damage and range.
@export var bonus_damage: int = 50
@export var ability_range: float = 300.0  # Default effective range if carddata doesn't override it.

func execute(owner: Node) -> void:
	# This ability is meant to trigger on special attack.
	if trigger_event != "on_special_attack":
		return

	# Only proceed if the owner's mana is full.
	if owner.mana < owner.max_mana:
		print("OnMaxManaRangedDamageAbility not executed on", owner.name, 
			  ": insufficient mana (", owner.mana, "/", owner.max_mana, ")")
		return

	# Determine effective range. If owner.card_data defines ability_range, use it.
	var effective_range = 300.0  # Fallback default
	if owner.card_data:
		effective_range = owner.card_data.ability_range
	print("Effective ability range is", effective_range)
	
	# Get the current target; if none, search for a valid enemy within effective_range.
	var target = owner.current_target
	if target == null:
		print("No current target for", owner.name, "- searching for enemy within range", effective_range)
		target = find_valid_enemy_target(owner, effective_range)
		if target:
			print("Found enemy target:", target.name)
		else:
			print("No enemy target found in range for", owner.name)
			return
	
	# Verify target is within effective_range.
	var dist = owner.global_position.distance_to(target.global_position)
	if dist > effective_range:
		print("Target", target.name, "is out of special ability range (Range:", effective_range, "vs Distance:", dist, ")")
		return

	# Check that the target is a valid enemy.
	if owner.is_in_group("ally_creatures") and not target.is_in_group("enemy_creatures"):
		print("Target", target.name, "is not a valid enemy for", owner.name)
		return
	elif owner.is_in_group("enemy_creatures") and not target.is_in_group("ally_creatures"):
		print("Target", target.name, "is not a valid enemy for", owner.name)
		return

	# Execute ability: deal bonus damage and reset mana.
	print("OnMaxManaRangedDamageAbility executing on", owner.name, "dealing", bonus_damage, "damage to", target.name)
	if target.has_method("take_damage"):
		target.take_damage(bonus_damage)
		owner.mana = 0  # Reset mana after ability use.
	else:
		print("Target", target.name, "cannot take damage.")

# Helper function: searches for the closest enemy target within 'range'
func find_valid_enemy_target(owner: Node, range: float) -> Node:
	var space_state = owner.get_world_2d().direct_space_state
	var circle = CircleShape2D.new()
	circle.radius = range
	var query = PhysicsShapeQueryParameters2D.new()
	# Use a standard transform centered at owner's position.
	query.transform = Transform2D.IDENTITY.translated(owner.global_position)
	query.shape = circle
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 0xFFFFFFFF
	query.exclude = [owner]
	
	var results = space_state.intersect_shape(query)
	print("Physics query returned", results.size(), "results for", owner.name)
	var enemy_candidates = []
	for result in results:
		var collider = result.collider
		if collider:
			if owner.is_in_group("ally_creatures") and collider.is_in_group("enemy_creatures"):
				enemy_candidates.append(collider)
			elif owner.is_in_group("enemy_creatures") and collider.is_in_group("ally_creatures"):
				enemy_candidates.append(collider)
	
	if enemy_candidates.size() > 0:
		var closest = enemy_candidates[0]
		var closest_dist = owner.global_position.distance_to(closest.global_position)
		for candidate in enemy_candidates:
			var d = owner.global_position.distance_to(candidate.global_position)
			if d < closest_dist:
				closest = candidate
				closest_dist = d
		return closest
	return null
