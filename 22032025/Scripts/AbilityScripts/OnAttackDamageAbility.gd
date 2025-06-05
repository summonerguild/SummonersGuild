extends Ability
class_name OnAttackDamageAbility

@export var bonus_damage: int = 50

func execute(owner: Node) -> void:
	if trigger_event != "on_attack":
		return
	# Only execute if owner's mana is at max.
	if owner.mana < owner.max_mana:
		print("OnAttackDamageAbility not executed: not enough mana on", owner.name, 
			  "(", owner.mana, "/", owner.max_mana, ")")
		return

	print("OnAttackDamageAbility executing on", owner.name, "dealing bonus damage:", bonus_damage)
	if owner.current_target:
		owner.current_target.take_damage(bonus_damage)
		print("Dealt bonus damage to", owner.current_target.name)
		# Optionally reset mana after casting the ability.
		owner.mana = 0
	else:
		print("No current target to receive bonus damage.")
