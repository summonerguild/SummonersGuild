extends Node2D  # Change to Node2D since we need to track health, collisions, etc.

# Shield health
var max_health = 2000
var health = max_health  # Current health

var health_bar: TextureProgressBar

# Ready function to initialize the health bar
func _ready():
	health_bar = $HealthBar/TextureProgressBar
	health_bar.max_value = max_health
	health_bar.value = health

# Update the health bar value based on the current health
func update_health_bar():
	if health_bar:
		health_bar.value = health

# Called when the shield takes damage
func take_damage(damage_amount: int):
	health -= damage_amount
	health = max(health, 0)  # Ensure health doesn't drop below 0
	print("Ally shield took", damage_amount, "damage! Current health:", health)

	# Update the health bar
	update_health_bar()

	# If health is 0 or below, destroy the shield
	if health <= 0:
		destroy_shield()

# Function to handle the shield being destroyed
func destroy_shield():
	print("Ally shield destroyed!")
	queue_free()  # Remove the shield from the scene
