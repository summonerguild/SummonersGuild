extends Resource
class_name carddata

@export var name: String
@export var image: Texture2D
@export var description: String
@export var attack: int
@export var health: int
@export var armor: int
@export var attack_speed: int
@export var move_speed: int
@export var attack_range: int
@export var max_mana: int
@export var mana_regen: int
@export var health_regen: int
@export var fusion_level: int
@export var element: String       # (Leaving your existing single 'element' in place if you want it)
@export var ability_description: String
@export var abilities: Array[Ability] = []
@export var ability_range: float = 300.0
@export var combat_type: String = ""  # e.g., "swordsman", "spearman", "cavalry", etc.

# NEW FIELDS for improved fusion logic:
@export var card_type: String = "creature"  # or "spell" or future expansions
@export var spell_effect_type: String = ""  # e.g., "damage", "heal", "buff", etc.
@export var spell_range: float = 300.0      # Range of the spell effect
@export var spell_damage: int = 0           # Damage amount (if applicable)
@export var spell_target_type: String = "enemy"  # "enemy", "ally", "all", "board"
@export var spell_aoe_radius: float = 100.0 # Radius for AOE spells
@export var archetype: String = ""
@export var hidden_archetype: String = ""

# In carddata.gd
@export var elements: Array[String] = []  # Format: ["Water:1.0", "Fire:0.3"]



# In carddata.gd
@export var has_animations: bool = false  # Flag to check if this creature has animations
@export var animation_frames: SpriteFrames = null  # Optional SpriteFrames resource


# Helper function to convert to dictionary when needed
func get_elements_dict() -> Dictionary:
	var result = {}
	for pair in elements:
		var parts = pair.split(":")
		if parts.size() == 2:
			result[parts[0]] = float(parts[1])
	return result
	
func get_ability_description() -> String:
	return ability_description
