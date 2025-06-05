extends Ability
class_name SpellAbility

# Trigger options for spells
enum SpellTriggerType {
	ON_CAST,
	ON_DISCARD
}

# Targeting options
@export var spell_range: float = 300.0
@export var affects_allies: bool = false
@export var affects_enemies: bool = true
@export var single_target: bool = false
@export var aoe_radius: float = 100.0
@export var blind_chance: float = 0.0
@export var blind_duration: float = 0.0
# Effect values
@export var damage: int = 0
@export var heal_amount: int = 0
@export var burn_stacks: int = 0

# Buff properties
@export var buff_stat: String = ""
@export var buff_amount: float = 0.0
@export var buff_duration: float = 0.0

# Override trigger type
@export var spell_trigger_type: SpellTriggerType = SpellTriggerType.ON_CAST

# Override the base should_trigger method
func should_trigger(event: String) -> bool:
	match spell_trigger_type:
		SpellTriggerType.ON_CAST:
			return event == "on_cast"
		SpellTriggerType.ON_DISCARD:
			return event == "on_discard"
	
	# Fallback to parent class method
	return super.should_trigger(event)

# Find valid targets for the spell
# Update the apply_effects_to_target function in SpellAbility.gd to properly use radius
func find_valid_targets(caster: Node) -> Array:
	var targets = []
	
	# Determine target type
	var target_type = "ally" if affects_allies else "enemy"
	
	# Debug output
	print("SpellAbility: Finding targets with range:", spell_range, "AOE radius:", aoe_radius)
	print("SpellAbility: single_target =", single_target, ", target_type =", target_type)
	
	# Use caster's find_targets_in_range method
	if caster.has_method("find_targets_in_range"):
		# For single target spells, use find_closest_target_in_range
		if single_target:
			var target = caster.find_closest_target_in_range(spell_range, target_type, false)
			if target:
				targets.append(target)
				print("SpellAbility: Found single target:", target.name)
		else:
			# For AOE spells, use the aoe_radius parameter
			targets = caster.find_targets_in_range(aoe_radius, target_type, false)
			print("SpellAbility: Found", targets.size(), "targets in AOE radius:", aoe_radius)
	else:
		print("SpellAbility: Caster lacks find_targets_in_range method!")
	
	return targets

# Also update the execute method for better debug output
func execute(caster: Node) -> void:
	print("SpellAbility: Executing spell from", caster.name)
	print("SpellAbility: affects_allies =", affects_allies, ", affects_enemies =", affects_enemies)
	print("SpellAbility: spell_range =", spell_range, ", aoe_radius =", aoe_radius)
	
	# Determine which targets to affect
	var targets = find_valid_targets(caster)
	
	if targets.size() == 0:
		print("SpellAbility: No valid targets found within range or radius")
		return
	
	print("SpellAbility: Applying effects to", targets.size(), "targets")
	
	# Apply effects to targets
	for target in targets:
		apply_effects_to_target(target)
	
	print("SpellAbility: Spell effects applied successfully")

# Apply the appropriate effects to a target
func apply_effects_to_target(target: Node) -> void:
	# Save the original movement state before applying effects
	var original_can_move = true
	if target.has_method("get") and "can_move" in target:
		original_can_move = target.can_move
	
	# Apply damage if specified
	if damage > 0 and target.has_method("take_damage"):
		target.take_damage(damage)
		print("SpellAbility: Applied", damage, "damage to", target.name)
	
	# Apply healing if specified
	if heal_amount > 0:
		if target.has_method("receive_healing"):
			target.receive_healing(heal_amount)
			print("SpellAbility: Healed", heal_amount, "to", target.name)
		elif target.has_method("take_damage"):
			# Fallback: use negative damage for healing
			target.take_damage(-heal_amount)
			print("SpellAbility: Healed", heal_amount, "to", target.name)
	
	# Apply burn if specified
	if burn_stacks > 0 and target.has_method("apply_burn_stacks"):
		target.apply_burn_stacks(burn_stacks)
		print("SpellAbility: Applied", burn_stacks, "burn stacks to", target.name)
	
	# Apply buff if specified
	if buff_stat != "" and buff_amount > 0 and target.has_method("apply_buff"):
		target.apply_buff(buff_stat, buff_amount, buff_duration)
		print("SpellAbility: Applied buff to", target.name, ":", buff_stat, "+", buff_amount, "for", buff_duration, "seconds")
		
			# Apply blind if specified
	if blind_chance > 0 and blind_duration > 0 and target.has_method("apply_blind"):
		target.apply_blind(blind_chance, blind_duration)
		print("SpellAbility: Applied blind effect to", target.name, "with", blind_chance * 100, "% miss chance for", blind_duration, "seconds")
	
	# Restore the original movement state after applying effects
	if target.has_method("set") and "can_move" in target:
		target.can_move = original_can_move
		# Also update movement system if it exists
		if target.has_method("get") and "movement_system" in target and target.movement_system != null:
			target.movement_system.can_move = original_can_move
