extends ColorRect  # ColorRect inherits from CanvasItem

@export var ring_color: Color = Color(1, 1, 1, 1)
@export var ring_thickness: float = 4.0
@export var ring_radius: float = 20.0
var progress: float = 0.0

func _ready() -> void:
	set_process(true)

func update_arc(p: float) -> void:
	progress = clamp(p, 0.0, 1.0)
	update()  # This should now work on this fresh node.

func _process(delta: float) -> void:
	# Optionally update position or any other properties.
	update()

func _draw() -> void:
	draw_arc(Vector2.ZERO, ring_radius, 0, progress * TAU, 64, ring_color, ring_thickness)
