extends Ability
class_name BlindAbility

# Blinding effect parameters
@export var blind_chance: float = 0.5  # 50% chance to miss by default
@export var blind_duration: float = 5.0  # Duration in seconds
@export var effect_range: float = 200.0  # Range to apply the blind
@export var single_target: bool = false  # Whether to target single or multiple creatures
@export var affects_allies: bool = false  # Whether to blind allies

func execute(owner: Node) -> void:
	print("BlindAbility: Attempting to execute on " + owner.name)
	
	# Determine target type based on affects_allies
	var target_type = "ally" if affects_allies else "enemy"
	var targets: Array = []
	
	# Find appropriate targets
	if single_target:
		var target = owner.find_closest_target_in_range(effect_range, target_type, false)
		if target:
			targets.append(target)
	else:
		targets = owner.find_targets_in_range(effect_range, target_type, false)
	
	if targets.size() == 0:
		print("BlindAbility: No valid targets found within range", effect_range)
		return
	
	# Apply the blind effect to each found target
	for target in targets:
		if target.has_method("apply_blind"):
			target.apply_blind(blind_chance, blind_duration)
			print("BlindAbility: Applied blind with", blind_chance * 100, "% miss chance to", target.name, "for", blind_duration, "seconds")
		else:
			print("BlindAbility: Target", target.name, "cannot receive blind effect (no apply_blind method)")
