extends Ability
class_name OnDeathAreaDamageAbility

# Damage dealt when triggered.
@export var damage: int = 10
# Radius (in pixels) in which the damage is applied.
@export var radius: float = 100.0

# If true, the effect will also affect allied targets.
@export var affects_allies: bool = false
# If true, only the single closest target will be affected.
@export var single_target: bool = false

func execute(owner: Node) -> void:
	# Only run if the trigger event matches.
	if trigger_event != "on_death":
		return

	print("OnDeathAreaDamageAbility executing on", owner.name, "dealing", damage, "damage in radius", radius)
	
	var space_state = owner.get_world_2d().direct_space_state
	var circle = CircleShape2D.new()
	circle.radius = radius
	
	var query = PhysicsShapeQueryParameters2D.new()
	query.transform = Transform2D.IDENTITY.translated(owner.global_position)
	query.shape = circle
	query.collide_with_areas = true
	query.collide_with_bodies = true
	# Use a broad collision mask for now.
	query.collision_mask = 0xFFFFFFFF
	# Exclude the owner so it never damages itself.
	query.exclude = [owner]
	
	var results = space_state.intersect_shape(query)
	print("Physics query returned", results.size(), "results.")
	
	# Collect valid targets
	var valid_targets = []
	for result in results:
		var collider = result.collider
		if collider:
			# Skip spells and other non-creature objects
			if collider.is_in_group("ally_spells") or collider.is_in_group("enemy_spells"):
				continue
				
			# If affects_allies is true, accept any collider;
			# otherwise, only accept targets on the opposing side.
			if affects_allies:
				valid_targets.append(collider)
			else:
				if owner.is_in_group("ally_creatures") and collider.is_in_group("enemy_creatures"):
					valid_targets.append(collider)
				elif owner.is_in_group("enemy_creatures") and collider.is_in_group("ally_creatures"):
					valid_targets.append(collider)
	
	# If single_target is true, choose the closest target.
	if valid_targets.size() > 0:
		if single_target:
			var chosen = valid_targets[0]
			var closest_dist = owner.global_position.distance_to(chosen.global_position)
			for target in valid_targets:
				var d = owner.global_position.distance_to(target.global_position)
				if d < closest_dist:
					chosen = target
					closest_dist = d
			print("OnDeathAreaDamageAbility executing on single target:", chosen.name)
			
			# Check if the target has the take_damage method
			if chosen.has_method("take_damage"):
				chosen.take_damage(damage)
			else:
				print("WARNING: Target", chosen.name, "doesn't have take_damage method")
		else:
			for target in valid_targets:
				print("OnDeathAreaDamageAbility executing on", target.name, "dealing", damage, "damage")
				
				# Check if the target has the take_damage method
				if target.has_method("take_damage"):
					target.take_damage(damage)
				else:
					print("WARNING: Target", target.name, "doesn't have take_damage method")
	else:
		print("No valid targets for OnDeathAreaDamageAbility.")
