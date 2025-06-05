extends Ability
class_name OnAllyBuffAbility

# Which stat to buff, e.g., "attack", "move_speed", "mana_regen", etc.
@export var buff_stat: String = ""
# The amount by which to buff the stat.
@export var buff_amount: float = 0.0
# Duration of the buff in seconds.
@export var buff_duration: float = 5.0
# Range within which allies are affected.
@export var effect_range: float = 300.0
# If true, only apply the buff to a single target (e.g., the closest); otherwise, apply to all.
@export var single_target: bool = false
# If true, include the caster in the buff targets (self-buff).
@export var affects_self: bool = false

func execute(caster: Node) -> void:
	# Get allied targets using the caster's ability range.
	var allies: Array = caster.find_all_allied_targets_in_range(caster.card_data.ability_range, affects_self)
	
	# Filter out self if we aren’t allowing self-buff.
	var targets: Array = []
	for ally in allies:
		if not affects_self and ally.get_instance_id() == caster.get_instance_id():
			continue
		targets.append(ally)
	
	if targets.size() > 0:
		if single_target:
			var chosen = targets[0]
			var closest_dist = caster.global_position.distance_to(chosen.global_position)
			for t in targets:
				var d = caster.global_position.distance_to(t.global_position)
				if d < closest_dist:
					chosen = t
					closest_dist = d
			print("OnAllyBuffAbility executing on single ally:", chosen.name)
			chosen.apply_buff(buff_stat, buff_amount, buff_duration)
		else:
			print("OnAllyBuffAbility executing on", targets.size(), "allies")
			for target in targets:
				target.apply_buff(buff_stat, buff_amount, buff_duration)
			print("Buff applied:", buff_stat, "increased by", buff_amount, "for", buff_duration, "seconds.")
	else:
		print("No allied targets found for buff.")



		
func _get_all_allies_in_range(owner: Node, range: float) -> Array:
	var allies = []
	var space_state = owner.get_world_2d().direct_space_state
	var circle = CircleShape2D.new()
	circle.radius = range
	var query = PhysicsShapeQueryParameters2D.new()
	query.transform = Transform2D.IDENTITY.translated(owner.global_position)
	query.shape = circle
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [owner]
	var results = space_state.intersect_shape(query)
	for result in results:
		var collider = result.collider
		# Here we assume your ally creatures are in a specific group (e.g., "ally_creatures")
		if collider and collider.is_in_group("ally_creatures"):
			allies.append(collider)
	return allies
