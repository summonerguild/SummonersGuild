extends Ability
class_name FlexibleDamageAbility

# Damage properties
@export var damage: int = 10

# Range properties
@export var effect_range: float = 100.0

# Targeting options
enum TargetingMode {
	SINGLE_TARGET,  # Only hit closest target
	AOE             # Hit all targets in range
}

enum TargetCenter {
	SELF,           # Centered on the caster
	TARGET          # Centered on the current target
}

@export var targeting_mode: TargetingMode = TargetingMode.AOE
@export var target_center: TargetCenter = TargetCenter.SELF
@export var affects_allies: bool = false
@export var affects_enemies: bool = true

func execute(owner: Node) -> void:
	print("FlexibleDamageAbility executing on", owner.name)
	
	# Determine the center position for the effect
	var center_position = owner.global_position
	if target_center == TargetCenter.TARGET and owner.current_target:
		center_position = owner.current_target.global_position
	
	# Find valid targets
	var valid_targets = find_valid_targets(owner, center_position)
	
	if valid_targets.size() == 0:
		print("FlexibleDamageAbility: No valid targets found.")
		return
	
	# Apply damage based on targeting mode
	if targeting_mode == TargetingMode.SINGLE_TARGET:
		# Find closest target
		var closest_target = valid_targets[0]
		var closest_dist = center_position.distance_to(closest_target.global_position)
		
		for target in valid_targets:
			var dist = center_position.distance_to(target.global_position)
			if dist < closest_dist:
				closest_target = target
				closest_dist = dist
		
		print("FlexibleDamageAbility: Dealing", damage, "damage to single target:", closest_target.name)
		closest_target.take_damage(damage)
	else:
		# Apply damage to all targets
		for target in valid_targets:
			print("FlexibleDamageAbility: Dealing", damage, "damage to:", target.name)
			target.take_damage(damage)

func find_valid_targets(owner: Node, center_position: Vector2) -> Array:
	var valid_targets = []
	
	# Physics query to find potential targets
	var space_state = owner.get_world_2d().direct_space_state
	var circle = CircleShape2D.new()
	circle.radius = effect_range
	
	var query = PhysicsShapeQueryParameters2D.new()
	query.transform = Transform2D.IDENTITY.translated(center_position)
	query.shape = circle
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 0xFFFFFFFF
	query.exclude = [owner]
	
	var results = space_state.intersect_shape(query)
	
	# Filter to only include targetable objects that can take damage
	for result in results:
		var collider = result.collider
		if collider and collider.has_method("take_damage"):
			var is_ally = (owner.is_in_group("ally_creatures") and collider.is_in_group("ally_creatures")) or (owner.is_in_group("enemy_creatures") and collider.is_in_group("enemy_creatures"))
			
			var is_enemy = (owner.is_in_group("ally_creatures") and collider.is_in_group("enemy_creatures")) or (owner.is_in_group("enemy_creatures") and collider.is_in_group("ally_creatures"))
			
			# Check if target is valid based on affects_allies/affects_enemies settings
			if (is_ally and affects_allies) or (is_enemy and affects_enemies):
				valid_targets.append(collider)
	
	return valid_targets
