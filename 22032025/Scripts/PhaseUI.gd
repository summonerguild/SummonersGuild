extends Control

@onready var phase_label = $PhaseLabel
@onready var timer_label = $TimerLabel
@onready var ready_button = $ReadyButton

func _ready():
	GameStateManager.connect("phase_changed", Callable(self, "_on_phase_changed"))
	GameStateManager.connect("phase2_time_updated", Callable(self, "_on_phase2_time_updated"))
	GameStateManager.connect("phase1_time_updated", Callable(self, "_on_phase1_time_updated"))
	ready_button.connect("pressed", Callable(self, "_on_ready_button_pressed"))
	
	_update_ui()
	print("PhaseUI initialized and connected to GameStateManager")

func _on_phase_changed(_new_phase):
	_update_ui()

func _on_phase1_time_updated(time_remaining):
	if GameStateManager.is_preparation_phase():
		timer_label.text = "Preparation Time: " + str(int(time_remaining)) + "s"
		
func _on_phase2_time_updated(time_remaining):
	if not GameStateManager.is_preparation_phase():
		timer_label.text = "Combat Time: " + str(int(time_remaining)) + "s"

func _on_ready_button_pressed():
	if GameStateManager.is_preparation_phase():
		GameStateManager.transition_to_phase2()

func _update_ui():
	if GameStateManager.is_preparation_phase():
		phase_label.text = "PHASE 1: PREPARATION"
		phase_label.add_theme_color_override("font_color", Color(0.2, 0.6, 1.0)) # Blue
		timer_label.visible = true
		timer_label.text = "Preparation Time: 60s"
		ready_button.visible = true
		ready_button.text = "READY (Skip to Combat)"
	else:
		phase_label.text = "PHASE 2: COMBAT"
		phase_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3)) # Red
		timer_label.visible = true
		ready_button.visible = false
	
	# Force redraw to make sure changes are applied
	queue_redraw()
	print("Phase UI updated: " + phase_label.text)
