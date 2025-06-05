extends Node

# Store type advantages in a dictionary
var type_advantages = {
	"swordsman": {"strong_against": ["spearman"], "damage_multiplier": 1.5},
	"spearman": {"strong_against": ["cavalry"], "damage_multiplier": 1.5},
	"cavalry": {"strong_against": ["swordsman"], "damage_multiplier": 1.5},
	
	"archer": {"strong_against": ["flying"], "damage_multiplier": 1.5},
	"flying": {"strong_against": ["siege"], "damage_multiplier": 1.5},
	"siege": {"strong_against": ["archer"], "damage_multiplier": 1.5},
	
	"mage": {"strong_against": [], "damage_multiplier": 1.0},
	"support": {"strong_against": [], "damage_multiplier": 1.0}
}
	
	# Get the damage multiplier for attacker vs defender
func get_damage_multiplier(attacker_type: String, defender_type: String) -> float:
	# Default multiplier is 1.0 (normal damage)
	var multiplier = 1.0
	
	# Check if attacker has advantage against defender
	if type_advantages.has(attacker_type):
		var advantage = type_advantages[attacker_type]
		if defender_type in advantage["strong_against"]:
			multiplier = advantage["damage_multiplier"]
	
	return multiplier
