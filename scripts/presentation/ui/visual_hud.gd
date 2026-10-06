class_name VisualHUD
extends Control

@onready var day_time_label: Label = $TopPanel/DayTimeLabel
@onready var status_label: Label = $TopPanel/StatusLabel
@onready var control_hint_label: Label = $TopPanel/ControlHintLabel
@onready var event_label: Label = $EventPanel/EventLabel
@onready var name_label: Label = $ResidentPanel/NameLabel
@onready var schedule_label: Label = $ResidentPanel/ScheduleLabel
@onready var goal_label: Label = $ResidentPanel/GoalLabel
@onready var action_label: Label = $ResidentPanel/ActionLabel
@onready var money_label: Label = $ResidentPanel/MoneyLabel
@onready var hunger_label: Label = $ResidentPanel/HungerLabel
@onready var energy_label: Label = $ResidentPanel/EnergyLabel
@onready var social_label: Label = $ResidentPanel/SocialLabel
@onready var mood_label: Label = $ResidentPanel/MoodLabel
@onready var hunger_bar: ProgressBar = $ResidentPanel/HungerBar
@onready var energy_bar: ProgressBar = $ResidentPanel/EnergyBar
@onready var social_bar: ProgressBar = $ResidentPanel/SocialBar
@onready var mood_bar: ProgressBar = $ResidentPanel/MoodBar

var _world: SimulationWorld = null
var _selected_resident_id: StringName = &""
var _latest_event: String = "Simulation online"
var _refresh_accumulator: float = 0.0
var _simulation_running: bool = true

func _ready() -> void:
	_apply_styles()
	refresh()

func _process(delta: float) -> void:
	_refresh_accumulator += delta
	if _refresh_accumulator < 0.2:
		return
	_refresh_accumulator = 0.0
	refresh()

func bind_world(world: SimulationWorld) -> void:
	_world = world
	if _world != null and _selected_resident_id == &"":
		var residents: Array[CharacterState] = _world.characters()
		if not residents.is_empty() and residents[0] != null:
			_selected_resident_id = residents[0].id
	refresh()

func set_selected_resident(character_id: StringName) -> void:
	_selected_resident_id = character_id
	refresh()

func set_simulation_running(value: bool) -> void:
	_simulation_running = value
	refresh()

func set_latest_event(value: String) -> void:
	_latest_event = value
	if is_instance_valid(event_label):
		event_label.text = value

func refresh() -> void:
	if not is_instance_valid(day_time_label):
		return

	if _world == null:
		day_time_label.text = "DAY --  --:--"
		status_label.text = "NO WORLD"
		event_label.text = _latest_event
		_clear_resident_panel()
		return

	var simulation_seconds: float = _world.clock.get_simulation_seconds()
	var day_index := int(floor(simulation_seconds / 86400.0))
	var day_seconds := fmod(simulation_seconds, 86400.0)
	var hour := int(floor(day_seconds / 3600.0))
	var minute := int(floor(fmod(day_seconds, 3600.0) / 60.0))
	day_time_label.text = "DAY %d   %02d:%02d" % [
		day_index + 1,
		hour,
		minute,
	]
	status_label.text = "AUTONOMOUS  •  %s  •  %.0fx  •  %d" % [
		"RUN" if _simulation_running else "PAUSED",
		_world.clock.get_time_scale(),
		_world.characters().size(),
	]
	event_label.text = _latest_event

	var character: CharacterState = _world.get_character(_selected_resident_id)
	if character == null:
		_clear_resident_panel()
		return

	name_label.text = character.display_name
	money_label.text = "$%.0f" % character.money
	schedule_label.text = _schedule_text(character)
	goal_label.text = _goal_text(character)
	action_label.text = "Action: %s" % _action_text(character)
	hunger_bar.value = character.needs.hunger.value
	energy_bar.value = character.needs.energy.value
	social_bar.value = character.needs.social.value
	mood_bar.value = character.needs.mood.value
	hunger_label.text = "HUNGER %02d" % int(round(character.needs.hunger.value))
	energy_label.text = "ENERGY %02d" % int(round(character.needs.energy.value))
	social_label.text = "SOCIAL %02d" % int(round(character.needs.social.value))
	mood_label.text = "MOOD %02d" % int(round(character.needs.mood.value))

func _action_text(character: CharacterState) -> String:
	var value := str(character.current_action_id).strip_edges()
	if value.is_empty() or value == "idle":
		return "idle"
	return value.replace("_", " ")

func _schedule_text(character: CharacterState) -> String:
	if character.schedule == null:
		return "Schedule: —"
	if character.schedule.active_block_id == &"":
		return "Schedule: free"
	return "Schedule: %s" % str(character.schedule.active_block_id)

func _goal_text(character: CharacterState) -> String:
	if character.goals == null:
		return "Goal: —"

	var active: Array = character.goals.active_goals()
	if not active.is_empty():
		var goal = active[0]
		if goal != null and goal.definition != null:
			var suffix := ""
			if goal.definition.target_resident_id != &"":
				suffix = " → %s" % goal.definition.target_resident_id
			return "Goal: %s%s" % [
				str(goal.definition.category),
				suffix,
			]

	var history: Array = character.goals.goals()
	if not history.is_empty():
		var last = history[-1]
		if last != null and last.definition != null:
			return "Goal: %s (%s)" % [
				str(last.definition.category),
				str(last.status),
			]

	return "Goal: —"

func _clear_resident_panel() -> void:
	name_label.text = "NO RESIDENT"
	schedule_label.text = "Schedule: —"
	goal_label.text = "Goal: —"
	action_label.text = "Action: —"
	money_label.text = "$0"
	hunger_label.text = "HUNGER --"
	energy_label.text = "ENERGY --"
	social_label.text = "SOCIAL --"
	mood_label.text = "MOOD --"
	for bar in [hunger_bar, energy_bar, social_bar, mood_bar]:
		bar.value = 0.0

func _apply_styles() -> void:
	for panel in [$TopPanel, $EventPanel, $ResidentPanel]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.05, 0.08, 0.13, 0.9)
		style.border_color = Color("3b4d65")
		style.set_border_width_all(1)
		style.set_corner_radius_all(18)
		panel.add_theme_stylebox_override("panel", style)

	day_time_label.add_theme_font_size_override("font_size", 26)
	status_label.add_theme_font_size_override("font_size", 12)
	control_hint_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_font_size_override("font_size", 24)
	action_label.add_theme_font_size_override("font_size", 13)
	action_label.modulate = Color("d5dde8")
	event_label.add_theme_font_size_override("font_size", 14)

	for label in [hunger_label, energy_label, social_label, mood_label]:
		label.add_theme_font_size_override("font_size", 10)
		label.modulate = Color("b7c2d0")

	var progress_colors: Array[Color] = [
		Color("ef8354"),
		Color("69c779"),
		Color("6da9f5"),
		Color("e5c95c"),
	]
	var bars := [hunger_bar, energy_bar, social_bar, mood_bar]
	for index in range(bars.size()):
		var bar: ProgressBar = bars[index]
		bar.min_value = 0.0
		bar.max_value = 100.0
		bar.show_percentage = false

		var background := StyleBoxFlat.new()
		background.bg_color = Color("182231")
		background.set_corner_radius_all(7)
		bar.add_theme_stylebox_override("background", background)

		var fill := StyleBoxFlat.new()
		fill.bg_color = progress_colors[index]
		fill.set_corner_radius_all(7)
		bar.add_theme_stylebox_override("fill", fill)
