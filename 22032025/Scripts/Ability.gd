extends Resource
class_name Ability

# Trigger options
##In the Ability class
enum TriggerType {
	ON_MAX_MANA,
	ON_DEATH,
	ON_ATTACK,
	ON_ATTACK_WITH_MAX_MANA,  # New trigger type
	PASSIVE,
	ON_BURN,
	ON_ALLY_BUFF
}
# The trigger type for this ability
@export var trigger_type: TriggerType = TriggerType.ON_MAX_MANA

# Legacy trigger_event string (for backwards compatibility)
@export var trigger_event: String = ""

# Base execute method (override in subclasses)
func execute(owner: Node) -> void:
	print("Executing base ability for ", owner.name)

# Check if this ability should trigger based on the event
func should_trigger(event: String) -> bool:
	match trigger_type:
		TriggerType.ON_MAX_MANA:
			return event == "on_max_mana"
		TriggerType.ON_DEATH:
			return event == "on_death"
		TriggerType.ON_ATTACK:
			return event == "on_attack"
		TriggerType.PASSIVE:
			return event == "passive_update"
		TriggerType.ON_BURN:
			return event == "on_burn"
		TriggerType.ON_ALLY_BUFF:
			return event == "on_ally_buff"
	# Legacy support for string-based trigger events
	return trigger_event == event
