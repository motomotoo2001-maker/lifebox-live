class_name VisualHUD
extends Control

signal resident_requested(character_id: StringName)
signal save_requested
signal load_requested
signal command_requested(command_id: StringName)

@onready var day_time_label: Label = $TopPanel/DayTimeLabel
@onready var status_label: Label = $TopPanel/StatusLabel
@onready var control_hint_label: Label = $TopPanel/ControlHintLabel
@onready var event_label: Label = $EventPanel/EventLabel
@onready var insight_title_label: Label = $InsightPanel/TitleLabel
@onready var career_label: Label = $InsightPanel/CareerLabel
@onready var household_label: Label = $InsightPanel/HouseholdLabel
@onready var relationship_label: Label = $InsightPanel/RelationshipLabel
@onready var memory_label: Label = $InsightPanel/MemoryLabel
@onready var save_button: Button = $EventPanel/SaveButton
@onready var load_button: Button = $EventPanel/LoadButton
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
@onready var command_buttons: Array[Button] = [
	$CommandPanel/CommandStrip/EatButton,
	$CommandPanel/CommandStrip/RelaxButton,
	$CommandPanel/CommandStrip/ShowerButton,
	$CommandPanel/CommandStrip/TVButton,
	$CommandPanel/CommandStrip/ReadButton,
	$CommandPanel/CommandStrip/SleepButton,
]
@onready var resident_buttons: Array[Button] = [
	$TopPanel/ResidentStrip/ResidentButton1,
	$TopPanel/ResidentStrip/ResidentButton2,
	$TopPanel/ResidentStrip/ResidentButton3,
	$TopPanel/ResidentStrip/ResidentButton4,
	$TopPanel/ResidentStrip/ResidentButton5,
	$TopPanel/ResidentStrip/ResidentButton6,
]

var _world: SimulationWorld = null
var _selected_resident_id: StringName = &""
var _latest_event: String = "Simulation online"
var _refresh_accumulator: float = 0.0
var _simulation_running: bool = true

func _ready() -> void:
	_connect_resident_buttons()
	_connect_command_buttons()
	_connect_persistence_buttons()
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

func set_save_available(value: bool) -> void:
	if is_instance_valid(load_button):
		load_button.disabled = not value

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
	status_label.text = "AUTONOMOUS  •  %s  •  %s  •  %.0fx  •  %d" % [
		"RUN" if _simulation_running else "PAUSED",
		_day_phase_text(hour),
		_world.clock.get_time_scale(),
		_world.characters().size(),
	]
	event_label.text = _latest_event
	_refresh_resident_buttons()

	var character: CharacterState = _world.get_character(_selected_resident_id)
	if character == null:
		_clear_resident_panel()
		return

	name_label.text = character.display_name
	money_label.text = "$%.0f" % character.money
	schedule_label.text = _schedule_text(character)
	goal_label.text = _goal_text(character)
	action_label.text = "Action: %s" % _action_text(character)
	career_label.text = _job_text(character)
	household_label.text = _household_text()
	relationship_label.text = _relationship_text(character)
	memory_label.text = _memory_text(character)
	hunger_bar.value = character.needs.hunger.value
	energy_bar.value = character.needs.energy.value
	social_bar.value = character.needs.social.value
	mood_bar.value = character.needs.mood.value
	hunger_label.text = "HUNGER %02d" % int(round(character.needs.hunger.value))
	energy_label.text = "ENERGY %02d" % int(round(character.needs.energy.value))
	social_label.text = "SOCIAL %02d" % int(round(character.needs.social.value))
	mood_label.text = "MOOD %02d" % int(round(character.needs.mood.value))

func _connect_command_buttons() -> void:
	var command_ids: Array[StringName] = [
		&"eat",
		&"relax",
		&"shower",
		&"watch_tv",
		&"read",
		&"sleep",
	]
	for index in range(command_buttons.size()):
		var button: Button = command_buttons[index]
		if button == null or index >= command_ids.size():
			continue
		button.pressed.connect(
			_on_command_button_pressed.bind(command_ids[index])
		)

func _on_command_button_pressed(command_id: StringName) -> void:
	if command_id == &"":
		return
	command_requested.emit(command_id)

func _connect_persistence_buttons() -> void:
	if is_instance_valid(save_button) and not save_button.pressed.is_connected(
		_on_save_pressed
	):
		save_button.pressed.connect(_on_save_pressed)
	if is_instance_valid(load_button) and not load_button.pressed.is_connected(
		_on_load_pressed
	):
		load_button.pressed.connect(_on_load_pressed)

func _on_save_pressed() -> void:
	save_requested.emit()

func _on_load_pressed() -> void:
	load_requested.emit()

func _connect_resident_buttons() -> void:
	for index in range(resident_buttons.size()):
		var button: Button = resident_buttons[index]
		if button == null:
			continue
		button.pressed.connect(_on_resident_button_pressed.bind(index))

func _on_resident_button_pressed(index: int) -> void:
	if _world == null:
		return
	var residents: Array[CharacterState] = _world.characters()
	if index < 0 or index >= residents.size():
		return
	var character: CharacterState = residents[index]
	if character == null or character.id == &"":
		return
	resident_requested.emit(character.id)

func _refresh_resident_buttons() -> void:
	if resident_buttons.is_empty():
		return

	var residents: Array[CharacterState] = []
	if _world != null:
		residents = _world.characters()

	for index in range(resident_buttons.size()):
		var button: Button = resident_buttons[index]
		if button == null:
			continue
		if index >= residents.size() or residents[index] == null:
			button.text = "%d —" % (index + 1)
			button.disabled = true
			button.button_pressed = false
			button.tooltip_text = ""
			continue

		var character: CharacterState = residents[index]
		button.disabled = false
		button.text = "%d %s" % [index + 1, character.display_name]
		button.button_pressed = character.id == _selected_resident_id
		button.tooltip_text = "%s • %s" % [
			character.display_name,
			_action_text(character),
		]

func _action_text(character: CharacterState) -> String:
	var value := str(character.current_action_id).strip_edges()
	if value.is_empty() or value == "idle":
		return "idle"

	if _world != null:
		var session := _world.social_system.reservation_book.get_session_for(
			character.id
		)
		if session != null:
			var other_id := (
				session.target_id
				if session.initiator_id == character.id
				else session.initiator_id
			)
			var other := _world.get_character(other_id)
			var other_name := (
				other.display_name if other != null else str(other_id)
			)
			return "%s with %s" % [
				value.replace("_", " "),
				other_name,
			]

	return value.replace("_", " ")

func _day_phase_text(hour: int) -> String:
	if hour < 6:
		return "NIGHT"
	if hour < 9:
		return "DAWN"
	if hour < 18:
		return "DAY"
	if hour < 21:
		return "DUSK"
	return "NIGHT"

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
			return "Goal: %s%s  %d%%" % [
				str(goal.definition.category),
				suffix,
				int(round(goal.progress * 100.0)),
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

func _job_text(character: CharacterState) -> String:
	if character == null or character.job == null:
		return "Job: —"
	var definition: JobDefinition = character.job.definition
	if definition == null:
		return "Job: unemployed"

	var start_hour := int(floor(definition.shift_start_hour))
	var start_minute := int(round(
		(definition.shift_start_hour - float(start_hour)) * 60.0
	))
	var end_value := fposmod(
		definition.shift_start_hour + definition.shift_duration_hours,
		24.0
	)
	var end_hour := int(floor(end_value))
	var end_minute := int(round((end_value - float(end_hour)) * 60.0))
	return "Job: %s  $%.0f/h  %02d:%02d–%02d:%02d" % [
		str(definition.id).replace("_", " "),
		definition.pay_per_sim_hour,
		start_hour,
		start_minute,
		end_hour,
		end_minute,
	]

func _household_text() -> String:
	if _world == null or _world.household_expense_system == null:
		return "Bills: —"
	var expenses := _world.household_expense_system
	return "Bills: $%.0f/day\nArrears: $%.0f" % [
		expenses.daily_amount,
		expenses.arrears,
	]

func _relationship_text(character: CharacterState) -> String:
	if _world == null or character == null:
		return "Closest: —"

	var best_character: CharacterState = null
	var best_state: RelationshipState = null
	var best_score := -INF

	for candidate in _world.characters():
		if candidate == null or candidate.id == character.id:
			continue
		var state := _world.relationship_graph.get_relationship(
			character.id,
			candidate.id
		)
		if state == null:
			continue
		var score := (
			state.affinity
			+ state.trust * 0.6
			- maxf(state.tension, 0.0) * 0.8
		)
		if (
			best_character == null
			or score > best_score + 0.0001
			or (
				is_equal_approx(score, best_score)
				and str(candidate.id) < str(best_character.id)
			)
		):
			best_character = candidate
			best_state = state
			best_score = score

	if best_character == null or best_state == null:
		return "Closest: —"

	return "Closest: %s\nAFF %.0f  TRUST %.0f  TENSION %.0f" % [
		best_character.display_name,
		best_state.affinity,
		best_state.trust,
		best_state.tension,
	]

func _memory_text(character: CharacterState) -> String:
	if character == null or character.memory == null:
		return "Memory: —"
	var memories: Array[MemoryEvent] = character.memory.events()
	if memories.is_empty():
		return "Memory: none yet"

	var latest: MemoryEvent = memories[0]
	for memory in memories:
		if memory == null:
			continue
		if (
			latest == null
			or memory.simulation_seconds > latest.simulation_seconds
			or (
				is_equal_approx(
					memory.simulation_seconds,
					latest.simulation_seconds
				)
				and str(memory.event_id) > str(latest.event_id)
			)
		):
			latest = memory

	if latest == null:
		return "Memory: none yet"

	var partner := ""
	if not latest.related_resident_ids.is_empty() and _world != null:
		var related := _world.get_character(latest.related_resident_ids[0])
		if related != null:
			partner = " with %s" % related.display_name

	var tone := "neutral"
	if latest.valence > 0.15:
		tone = "positive"
	elif latest.valence < -0.15:
		tone = "negative"

	return "Memory: %s%s\n%s • importance %d%%" % [
		str(latest.kind).replace("_", " "),
		partner,
		tone,
		int(round(latest.importance * 100.0)),
	]

func _clear_resident_panel() -> void:
	name_label.text = "NO RESIDENT"
	schedule_label.text = "Schedule: —"
	goal_label.text = "Goal: —"
	action_label.text = "Action: —"
	career_label.text = "Job: —"
	household_label.text = "Bills: —"
	relationship_label.text = "Closest: —"
	memory_label.text = "Memory: —"
	money_label.text = "$0"
	hunger_label.text = "HUNGER --"
	energy_label.text = "ENERGY --"
	social_label.text = "SOCIAL --"
	mood_label.text = "MOOD --"
	for bar in [hunger_bar, energy_bar, social_bar, mood_bar]:
		bar.value = 0.0

func _apply_styles() -> void:
	for panel in [
		$TopPanel,
		$CommandPanel,
		$InsightPanel,
		$EventPanel,
		$ResidentPanel,
	]:
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
	insight_title_label.add_theme_font_size_override("font_size", 13)
	insight_title_label.modulate = Color("ffd65a")
	for insight_label in [
		career_label,
		household_label,
		relationship_label,
		memory_label,
	]:
		insight_label.add_theme_font_size_override("font_size", 12)
		insight_label.modulate = Color("c9d3df")

	for command_button in command_buttons:
		command_button.add_theme_font_size_override("font_size", 11)
		var command_style := StyleBoxFlat.new()
		command_style.bg_color = Color("172638")
		command_style.border_color = Color("45627f")
		command_style.set_border_width_all(1)
		command_style.set_corner_radius_all(9)
		command_button.add_theme_stylebox_override("normal", command_style)

		var command_hover := StyleBoxFlat.new()
		command_hover.bg_color = Color("263c53")
		command_hover.border_color = Color("72a7d8")
		command_hover.set_border_width_all(1)
		command_hover.set_corner_radius_all(9)
		command_button.add_theme_stylebox_override("hover", command_hover)

	for persistence_button in [save_button, load_button]:
		persistence_button.add_theme_font_size_override("font_size", 11)
		var action_style := StyleBoxFlat.new()
		action_style.bg_color = Color("152234")
		action_style.border_color = Color("49627f")
		action_style.set_border_width_all(1)
		action_style.set_corner_radius_all(10)
		persistence_button.add_theme_stylebox_override("normal", action_style)

	for button in resident_buttons:
		button.add_theme_font_size_override("font_size", 11)
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color("121d2a")
		normal.border_color = Color("33465c")
		normal.set_border_width_all(1)
		normal.set_corner_radius_all(9)
		button.add_theme_stylebox_override("normal", normal)

		var hover := StyleBoxFlat.new()
		hover.bg_color = Color("1b2a3a")
		hover.border_color = Color("607a98")
		hover.set_border_width_all(1)
		hover.set_corner_radius_all(9)
		button.add_theme_stylebox_override("hover", hover)

		var pressed := StyleBoxFlat.new()
		pressed.bg_color = Color("604e20")
		pressed.border_color = Color("ffd65a")
		pressed.set_border_width_all(2)
		pressed.set_corner_radius_all(9)
		button.add_theme_stylebox_override("pressed", pressed)

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
