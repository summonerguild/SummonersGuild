extends Node2D

# Shield health
var max_health = 2000
var health = max_health

# Attack properties
var attack_damage = 0
var attack_speed = 1.0  # Attacks per second
var attack_range = 300.0  # Range in pixels
var attack_timer = 0.0

var health_bar: TextureProgressBar

func _ready():
	health_bar = $HealthBar/TextureProgressBar
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health
	else:
		print("Warning: HealthBar/TextureProgressBar not found in shield")

	update_health_visual()

func _process(delta):
	# Increment attack timer and attack if it's time
	attack_timer += delta
	if attack_timer >= 1.0 / attack_speed:
		attack_timer = 0
		attack_nearest_enemy()

func update_health_bar():
	if health_bar:
		health_bar.value = health

func take_damage(damage_amount: int):
	health -= damage_amount
	print("Shield took", damage_amount, "damage! Current health: ", health)

	health = max(health, 0)
	update_health_bar()
	update_health_visual()

	if health <= 0:
		destroy_shield()

func destroy_shield():
	print("Shield destroyed!")
	queue_free()

func update_health_visual():
	var sprite = $Sprite2D
	if sprite:
		var opacity = float(health) / float(max_health)
		sprite.modulate.a = opacity

func attack_nearest_enemy():
	# Determine which target group to attack based on shield type
	var target_group = "enemy_creatures"
	if name == "OpponentSummonerShield":
		target_group = "ally_creatures"
	
	# Find all potential targets in range
	var targets = get_tree().get_nodes_in_group(target_group)
	var nearest_target = null
	var nearest_distance = attack_range + 1  # Start with a value larger than attack_range
	
	for target in targets:
		var distance = global_position.distance_to(target.global_position)
		if distance <= attack_range and distance < nearest_distance:
			nearest_target = target
			nearest_distance = distance
	
	# Attack the nearest target if found
	if nearest_target and nearest_target.has_method("take_damage"):
		nearest_target.take_damage(attack_damage)
		print(name + " attacked " + nearest_target.name + " for " + str(attack_damage) + " damage")
		
		# Create a simple visual effect to show the attack
		var line = Line2D.new()
		line.add_point(Vector2.ZERO)  # Local coordinates, so starting at origin
		line.add_point(nearest_target.global_position - global_position)  # Convert to local coords
		line.width = 2.0
		
		# Set color based on shield type
		if name == "AllySummonerShield":
			line.default_color = Color(0, 0.5, 1.0, 0.8)  # Blue for ally
		else:
			line.default_color = Color(1.0, 0.2, 0.2, 0.8)  # Red for opponent
		
		add_child(line)
		
		# Create a timer to remove the line after a short time
		var timer = get_tree().create_timer(0.2)
		timer.timeout.connect(func(): line.queue_free())
		
		
		
		
