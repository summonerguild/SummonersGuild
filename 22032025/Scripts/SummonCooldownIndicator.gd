extends Control

@export var ring_color: Color = Color(1, 1, 1, 1)
@export var ring_thickness: float = 4.0
@export var ring_radius: float = 20.0

var progress: float = 0.0  # 0.0 means no arc drawn, 1.0 means full ring

func _ready() -> void:
	set_process(true)

func update_progress(value: float) -> void:
	progress = clamp(value, 0.0, 1.0)
	# Instead of update(), call queue_redraw() to force a redraw.
	call_deferred("queue_redraw")

func _process(delta: float) -> void:
	# Optionally, have the indicator follow the mouse.
	global_position = get_viewport().get_mouse_position()
	# Continuously request a redraw.
	call_deferred("queue_redraw")

func _draw() -> void:
	# Draw an arc starting at angle 0 to progress * TAU.
	draw_arc(Vector2.ZERO, ring_radius, 0, progress * TAU, 64, ring_color, ring_thickness)
