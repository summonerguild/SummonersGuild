extends Node2D  # The shield now extends Node2D

# Shield health
var max_health = 2000  # Maximum health for the shield
var health = max_health  # Current health starts at max health

var health_bar: TextureProgressBar  # Reference to the health bar

# Called when the node is added to the scene
func _ready():
	# Get reference to the TextureProgressBar node
	health_bar = $HealthBar/TextureProgressBar
	
	# Initialize the health bar values
	health_bar.max_value = max_health
	health_bar.value = health
	
	# Optionally update the shield's visual appearance based on its health
	update_health_visual()

# Update the health bar when the shield takes damage
func update_health_bar():
	if health_bar:
		health_bar.value = health  # Set the value of the health bar to the current health

# Called when the shield takes damage
func take_damage(damage_amount: int):
	# Reduce health by the damage amount
	health -= damage_amount
	print("Shield took", damage_amount, "damage! Current health: ", health)

	# Make sure health doesn't drop below zero
	health = max(health, 0)

	# Update the health bar to reflect the new health
	update_health_bar()

	# Optionally update the visual representation of the shield's health
	update_health_visual()

	# If health is 0 or below, destroy the shield
	if health <= 0:
		destroy_shield()

# Handle shield destruction (e.g., removing it from the game)
func destroy_shield():
	print("Shield destroyed!")
	queue_free()  # Remove the shield from the scene

# Optionally update the shield's appearance based on health (e.g., changing opacity)
func update_health_visual():
	# Reference the sprite node
	var sprite = $Sprite2D
	if sprite:
		# Adjust the opacity based on the percentage of remaining health
		var opacity = float(health) / float(max_health)  # Calculate health percentage
		sprite.modulate.a = opacity  # Update the sprite's transparency
