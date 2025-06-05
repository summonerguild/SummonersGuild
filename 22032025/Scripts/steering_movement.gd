extends Node
class_name SteeringMovement

@export var max_speed: float = 150.0       # Maximum speed (pixels/sec)
@export var max_force: float = 300.0       # Maximum steering force (acceleration)
@export var desired_separation: float = 40.0  # Desired separation distance (pixels)
@export var seek_weight: float = 1.0
@export var separation_weight: float = 1.5
@export var obstacle_weight: float = 2.0
@export var obstacle_detection_distance: float = 50.0  # Lookahead distance for obstacles

# Internal state:
var velocity: Vector2 = Vector2.ZERO

# References and settings:
var owner_node: Node2D = null            # The node that uses this controller
var target_position: Vector2 = Vector2.ZERO   # The current target to seek
var obstacle_collision_mask: int = 0      # Collision mask for obstacles

# Call this method after instancing to initialize the controller.
func init(owner: Node2D, obstacle_mask: int = 0) -> void:
	owner_node = owner
	obstacle_collision_mask = obstacle_mask

func seek(target: Vector2) -> Vector2:
	var desired_velocity: Vector2 = (target - owner_node.global_position).normalized() * max_speed
	var steer: Vector2 = desired_velocity - velocity
	if steer.length() > max_force:
		steer = steer.normalized() * max_force
	return steer

func separate(neighbors: Array) -> Vector2:
	var steer: Vector2 = Vector2.ZERO
	var count: int = 0
	for neighbor in neighbors:
		if neighbor == owner_node:
			continue
		var diff: Vector2 = owner_node.global_position - neighbor.global_position
		var d: float = diff.length()
		if d > 0 and d < desired_separation:
			steer += diff.normalized() / d
			count += 1
	if count > 0:
		steer /= count
		if steer.length() > 0:
			steer = steer.normalized() * max_speed - velocity
			if steer.length() > max_force:
				steer = steer.normalized() * max_force
	return steer

func avoid_obstacles() -> Vector2:
	var avoid_force: Vector2 = Vector2.ZERO
	if velocity.length() == 0:
		return avoid_force
	var direction: Vector2 = velocity.normalized()
	var ray_origin: Vector2 = owner_node.global_position
	var ray_end: Vector2 = ray_origin + direction * obstacle_detection_distance
	var space_state = owner_node.get_world_2d().direct_space_state
	
	var query = PhysicsRayQueryParameters2D.new()
	query.from = ray_origin
	query.to = ray_end
	query.exclude = [owner_node]
	query.collision_mask = obstacle_collision_mask
	
	var result = space_state.intersect_ray(query)
	if result:
		var diff: Vector2 = owner_node.global_position - result.position
		avoid_force = diff.normalized() * max_force
	return avoid_force

func update_movement(delta: float) -> void:
	var acceleration: Vector2 = Vector2.ZERO
	
	# (1) Seek the target.
	acceleration += seek(target_position) * seek_weight
	
	# (2) Separation: check neighbors from the same group.
	var group_name: String = ""
	if owner_node.is_in_group("ally_creatures"):
		group_name = "ally_creatures"
	elif owner_node.is_in_group("enemy_creatures"):
		group_name = "enemy_creatures"
	if group_name != "":
		var neighbors = owner_node.get_tree().get_nodes_in_group(group_name)
		acceleration += separate(neighbors) * separation_weight
	
	# (3) Obstacle avoidance.
	acceleration += avoid_obstacles() * obstacle_weight
	
	# Update velocity:
	velocity += acceleration * delta
	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed
	
	# Update the owner's position:
	owner_node.global_position += velocity * delta
	
	# Optionally, rotate the owner to face its movement direction:
	if velocity.length() > 0.1:
		owner_node.rotation = velocity.angle()
