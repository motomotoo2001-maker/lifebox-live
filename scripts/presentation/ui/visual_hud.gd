class_name VisualHUD
extends Control

signal resident_requested(character_id: StringName)
signal save_requested
signal load_requested
signal action_requested(action_id: StringName)
signal social_action_requested(
	target_id: StringName,
	action_id: StringName
)

@onready var day_time_label: Label = $TopPanel/DayTimeLabel
@onready var status_label: Label = $TopPanel/StatusLabel
@onready var control_hint_label: Label = $TopPanel/ControlHintLabel
@onready var event_label: Label = $EventPanel/EventLabel
@onready var save_button: Button = $EventPanel/SaveButton
@onready var load_button: Button = $EventPanel/LoadButton
@onready var social_target_option: OptionButton = $SocialPanel/TargetOption
@onready var social_action_buttons: Array[Button] = [
	$SocialPanel/ChatButton,
	$SocialPanel/ComplimentButton,
	$SocialPanel/ArgueButton,
]
@onready var command_buttons: Array[Button] = [
	$CommandPanel/ActionStrip/EatButton,
	$CommandPanel/ActionStrip/ShowerButton,
	$CommandPanel/ActionStrip/SleepButton,
	$CommandPanel/ActionStrip/TVButton,
	$CommandPanel/ActionStrip/ReadButton,
	$CommandPanel/ActionStrip/RelaxButton,
]
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
var _social_target_ids: Array[StringName] = []
var _social_target_id: StringName = &""

func _ready() -> void:
	_connect_resident_buttons()
	_connect_persistence_buttons()
	_connect_command_buttons()
	_connect_social_controls()
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
		_refresh_command_buttons()
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
	_refresh_resident_buttons()
	_refresh_command_buttons()
	_refresh_social_controls()

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

func _connect_social_controls() -> void:
	if (
		is_instance_valid(social_target_option)
		and not social_target_option.item_selected.is_connected(
			_on_social_target_selected
		)
	):
		social_target_option.item_selected.connect(
			_on_social_target_selected
		)

	var action_ids: Array[StringName] = [
		&"chat",
		&"compliment",
		&"argue",
	]
	for index in range(mini(
		social_action_buttons.size(),
		action_ids.size()
	)):
		var button: Button = social_action_buttons[index]
		if button == null:
			continue
		button.pressed.connect(
			_on_social_action_pressed.bind(action_ids[index])
		)

func _on_social_target_selected(index: int) -> void:
	if index < 0 or index >= _social_target_ids.size():
		_social_target_id = &""
		return
	_social_target_id = _social_target_ids[index]

func _on_social_action_pressed(action_id: StringName) -> void:
	if _social_target_id == &"" or _selected_resident_id == &"":
		return
	social_action_requested.emit(_social_target_id, action_id)

func _refresh_social_controls() -> void:
	if not is_instance_valid(social_target_option):
		return

	var previous_target := _social_target_id
	_social_target_ids.clear()
	social_target_option.clear()

	if _world != null and _selected_resident_id != &"":
		for resident in _world.characters():
			if (
				resident == null
				or resident.id == &""
				or resident.id == _selected_resident_id
			):
				continue
			_social_target_ids.append(resident.id)
			social_target_option.add_item(resident.display_name)

	if (
		previous_target != &""
		and previous_target in _social_target_ids
	):
		_social_target_id = previous_target
	elif not _social_target_ids.is_empty():
		_social_target_id = _social_target_ids[0]
	else:
		_social_target_id = &""

	var selected_index := _social_target_ids.find(_social_target_id)
	if selected_index >= 0:
		social_target_option.select(selected_index)

	var enabled := _social_target_id != &""
	social_target_option.disabled = not enabled
	for button in social_action_buttons:
		if button != null:
			button.disabled = not enabled

func _connect_command_buttons() -> void:
	var action_ids: Array[StringName] = [
		&"eat",
		&"shower",
		&"sleep",
		&"watch_tv",
		&"read",
		&"relax",
	]
	for index in range(mini(command_buttons.size(), action_ids.size())):
		var button: Button = command_buttons[index]
		if button == null:
			continue
		button.pressed.connect(
			_on_command_button_pressed.bind(action_ids[index])
		)

func _on_command_button_pressed(action_id: StringName) -> void:
	if _world == null or _selected_resident_id == &"":
		return
	action_requested.emit(action_id)

func _refresh_command_buttons() -> void:
	var enabled := (
		_world != null
		and _selected_resident_id != &""
		and _world.get_character(_selected_resident_id) != null
	)
	for button in command_buttons:
		if button != null:
			button.disabled = not enabled

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
	for panel in [
		$TopPanel,
		$SocialPanel,
		$CommandPanel,
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

	if is_instance_valid(social_target_option):
		social_target_option.add_theme_font_size_override("font_size", 11)

	for social_button in social_action_buttons:
		social_button.add_theme_font_size_override("font_size", 10)
		var social_style := StyleBoxFlat.new()
		social_style.bg_color = Color("241d34")
		social_style.border_color = Color("65507f")
		social_style.set_border_width_all(1)
		social_style.set_corner_radius_all(9)
		social_button.add_theme_stylebox_override("normal", social_style)

		var social_hover := StyleBoxFlat.new()
		social_hover.bg_color = Color("38294d")
		social_hover.border_color = Color("aa84d2")
		social_hover.set_border_width_all(1)
		social_hover.set_corner_radius_all(9)
		social_button.add_theme_stylebox_override("hover", social_hover)

	for command_button in command_buttons:
		command_button.add_theme_font_size_override("font_size", 10)
		var command_style := StyleBoxFlat.new()
		command_style.bg_color = Color("172538")
		command_style.border_color = Color("42617f")
		command_style.set_border_width_all(1)
		command_style.set_corner_radius_all(9)
		command_button.add_theme_stylebox_override("normal", command_style)

		var command_hover := StyleBoxFlat.new()
		command_hover.bg_color = Color("243b54")
		command_hover.border_color = Color("7da7d1")
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
