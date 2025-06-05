# AudioManager.gd
extends Node

# Music tracks dictionary
var music_tracks = {
	"main_menu": preload("res://Audio/Music/main_menu.mp3"),
	"gameplay": preload("res://Audio/Music/gameplay.mp3"),
	# Element-based music tracks
#	"fire": preload("res://Audio/Music/fire_theme.mp3"),
	#"water": preload("res://Audio/Music/water_theme.mp3"),
	#"earth": preload("res://Audio/Music/earth_theme.mp3"),
	#"air": preload("res://Audio/Music/air_theme.mp3"),
	#"dark": preload("res://Audio/Music/dark_theme.mp3")
	# Add other element tracks as needed
}

# Audio players
var music_player: AudioStreamPlayer
var music_volume = 0.8
var current_track = ""

# Element music control
var element_music_timer: Timer
var can_change_element_music = false
var initial_gameplay_duration = 30.0  # 30 seconds of base gameplay music before element check

func _ready():
	# Create the music player
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	music_player.volume_db = linear_to_db(music_volume)
	music_player.finished.connect(_on_music_finished)
	add_child(music_player)
	
	# Create element music timer
	element_music_timer = Timer.new()
	element_music_timer.wait_time = initial_gameplay_duration
	element_music_timer.one_shot = true
	element_music_timer.timeout.connect(_on_element_music_timer_timeout)
	add_child(element_music_timer)
	
	# Auto-play main menu music
	#play_music("main_menu")

func play_music(track_name: String):
	if track_name == current_track and music_player.playing:
		return
	
	print("Playing music track: " + track_name)
	
	if not track_name in music_tracks:
		push_error("Track not found: " + track_name)
		return
	
	current_track = track_name
	music_player.stream = music_tracks[track_name]
	music_player.play()

func stop_music():
	music_player.stop()
	current_track = ""

# This ensures music loops
func _on_music_finished():
	if current_track != "":
		music_player.play()

# Called when gameplay starts - begins with base gameplay music
func start_gameplay_music():
	play_music("gameplay")
	# Start the timer for element-based music
	element_music_timer.start()
	can_change_element_music = false

# Timer timeout allows element-based music to play
func _on_element_music_timer_timeout():
	can_change_element_music = true
	check_dominant_element()
	# Reset the timer to check every 30 seconds after the initial period
	element_music_timer.wait_time = 30.0
	element_music_timer.start()

# Check which element is dominant on the board
func check_dominant_element():
	if not can_change_element_music:
		return
	
	# Get all creatures on the board
	var all_creatures = []
	all_creatures.append_array(get_tree().get_nodes_in_group("ally_creatures"))
	all_creatures.append_array(get_tree().get_nodes_in_group("enemy_creatures"))
	
	if all_creatures.size() == 0:
		# No creatures, stick with gameplay music
		if current_track != "gameplay":
			play_music("gameplay")
		return
	
	# Count occurrences of each element
	var element_counts = {}
	for creature in all_creatures:
		if creature.card_data and creature.card_data.element:
			var element = creature.card_data.element.to_lower()
			if element in element_counts:
				element_counts[element] += 1
			else:
				element_counts[element] = 1
	
	print("Element counts: ", element_counts)
	
	# Find the dominant element
	var dominant_element = "none"
	var highest_count = 0
	
	for element in element_counts.keys():
		if element_counts[element] > highest_count:
			highest_count = element_counts[element]
			dominant_element = element
	
	print("Dominant element: ", dominant_element)
	
	# Play the appropriate music if it's different from current
	if dominant_element in music_tracks:
		if current_track != dominant_element:
			play_music(dominant_element)
	else:
		# Fallback to default gameplay music if no element track exists
		if current_track != "gameplay":
			play_music("gameplay")

func set_music_volume(volume: float):
	music_volume = clamp(volume, 0.0, 1.0)
	music_player.volume_db = linear_to_db(music_volume)
