extends Ability
class_name BurnAbility

# Default tick rate at 0.5 seconds
@export var tick_interval: float = 0.5

# Burn stacks (damage per tick)
@export var initial_stacks: int = 7

# Range parameters
@export var effect_range: float = 300.0

# Targeting options
@export var single_target: bool = false
@export var affects_allies: bool = false
@export var affects_self: bool = false

# Success flag
var executed_successfully: bool = false

func execute(caster: Node) -> void:
	executed_successfully = false
	print("BurnAbility: Attempting to execute on " + caster.name)
	print("BurnAbility: affects_self = " + str(affects_self) + ", affects_allies = " + str(affects_allies))
	
	# Determine target type based on affects_allies.
	var target_type = "ally" if affects_allies else "enemy"
	var targets: Array = []
	
	# If affects_self is true, add self as the first target
	if affects_self:
		targets.append(caster)
		print("BurnAbility: Added self (" + caster.name + ") as target")
	
	# Use the creature's unified target-finding functions if looking for other targets
	if single_target:
		var target = caster.find_closest_target_in_range(effect_range, target_type, false) # Don't include self here since we already handled it
		if target:
			targets.append(target)
	else:
		# Get other targets (not self)
		var other_targets = caster.find_targets_in_range(effect_range, target_type, false)
		targets.append_array(other_targets)
	
	if targets.size() == 0:
		print("BurnAbility: No valid targets found within range", effect_range)
		return  # Do not spend mana if no valid target exists.
	
	# Apply the burn effect to each found target.
	for target in targets:
		if target.has_method("apply_burn_stacks"):
			target.apply_burn_stacks(initial_stacks)
			print("BurnAbility: Applied", initial_stacks, "burn stacks to", target.name)
			executed_successfully = true
		else:
			print("BurnAbility: Target", target.name, "cannot receive burn stacks (no apply_burn_stacks method)")

func _apply_burn_effect(caster: Node, target: Node) -> void:
	# Check if target has the necessary methods
	if target.has_method("apply_burn_stacks"):
		target.apply_burn_stacks(initial_stacks)
		print("BurnAbility: Applied", initial_stacks, "burn stacks to", target.name)
	else:
		print("BurnAbility: Target", target.name, "cannot receive burn stacks")
