class_name VisualSimulationShell
extends Node3D

const RESIDENT_ACTOR_SCENE := preload(
	"res://scenes/characters/resident_actor_3d.tscn"
)

@export var advance_simulation: bool = true
@export var manual_focus_seconds: float = 6.0
@export var manual_focus_ortho_size: float = 16.5

@onready var household: HouseholdBlockout = $HouseholdBlockout
@onready var resident_actors: Node3D = $ResidentActors
@onready var camera_rig: VerticalCameraRig = $VerticalCameraRig
@onready var camera_director: CameraDirector = $CameraDirector
@onready var hud: VisualHUD = $HUDLayer/VisualHUD

var _world: SimulationWorld = null
var _actors: Dictionary = {}
var _active_target_ids: Dictionary = {}
var _social_session_ids: Dictionary = {}
var _selected_resident_id: StringName = &""
var _manual_focus_remaining: float = 0.0

func _ready() -> void:
	if camera_director != null:
		camera_director.bind_camera_rig(camera_rig)
	if hud != null:
		if not hud.resident_requested.is_connected(
			_on_hud_resident_requested
		):
			hud.resident_requested.connect(_on_hud_resident_requested)
		if not hud.command_requested.is_connected(
			_on_hud_command_requested
		):
			hud.command_requested.connect(_on_hud_command_requested)

var _palette: Array[Color] = [
	Color("58a6ff"),
	Color("a371f7"),
	Color("f78166"),
	Color("3fb950"),
	Color("d29922"),
	Color("db61a2"),
]

func _process(delta: float) -> void:
	if _world == null:
		return
	if advance_simulation:
		_world.step(delta)
	sync_visuals()
	_update_camera_director(delta)
	if hud != null:
		hud.set_simulation_running(advance_simulation)

func _unhandled_input(event: InputEvent) -> void:
	if _world == null or not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	if key_event.keycode == KEY_SPACE:
		advance_simulation = not advance_simulation
		if hud != null:
			hud.set_simulation_running(advance_simulation)
			hud.set_latest_event(
				"Simulation resumed" if advance_simulation
				else "Simulation paused"
			)
		get_viewport().set_input_as_handled()
		return

	if key_event.keycode == KEY_ESCAPE:
		_manual_focus_remaining = 0.0
		if camera_director != null:
			camera_director.force_establishing()
		if hud != null:
			hud.set_latest_event("Camera overview")
		get_viewport().set_input_as_handled()
		return

	if key_event.unicode == 43 or key_event.keycode == KEY_EQUAL:
		_shift_time_scale(1)
		get_viewport().set_input_as_handled()
		return
	if key_event.unicode == 45 or key_event.keycode == KEY_MINUS:
		_shift_time_scale(-1)
		get_viewport().set_input_as_handled()
		return

	var resident_index := -1
	match key_event.keycode:
		KEY_1:
			resident_index = 0
		KEY_2:
			resident_index = 1
		KEY_3:
			resident_index = 2
		KEY_4:
			resident_index = 3
		KEY_5:
			resident_index = 4
		KEY_6:
			resident_index = 5

	if resident_index < 0:
		return
	var residents: Array[CharacterState] = _world.characters()
	if resident_index >= residents.size() or residents[resident_index] == null:
		return
	select_resident(residents[resident_index].id)
	get_viewport().set_input_as_handled()

func bind_world(world: SimulationWorld) -> bool:
	if world == null:
		return false

	_clear_actors()
	_world = world
	hud.bind_world(_world)

	var residents: Array[CharacterState] = _world.characters()
	for index in range(residents.size()):
		var character: CharacterState = residents[index]
		if character == null or character.id == &"":
			continue

		var actor: ResidentActor3D = RESIDENT_ACTOR_SCENE.instantiate() as ResidentActor3D
		if actor == null:
			return false

		resident_actors.add_child(actor)
		var spawn: Marker3D = household.get_resident_spawn(index + 1)
		if spawn != null:
			actor.global_position = spawn.global_position
		else:
			actor.global_position = Vector3(
				float(index) * 1.4 - 4.0,
				0.0,
				-3.0
			)

		actor.bind_character(character.id)
		actor.set_display_name(character.display_name)
		actor.set_visual_profile(index)
		actor.set_visual_color(_palette[index % _palette.size()])
		actor.movement_arrived.connect(_on_actor_arrived)
		actor.movement_failed.connect(_on_actor_failed)
		actor.resident_selected.connect(_on_actor_selected)
		_actors[character.id] = actor

	if not residents.is_empty() and residents[0] != null:
		select_resident(residents[0].id, false)
	sync_visuals()
	return true

func sync_visuals() -> void:
	if _world == null:
		return

	for character in _world.characters():
		if character == null:
			continue
		var actor := actor_for(character.id)
		if actor == null:
			continue

		actor.set_presentation_state(presentation_state_for(character))
		actor.set_selected(character.id == _selected_resident_id)
		var badge_text := activity_badge_for(character)
		if badge_text.is_empty():
			actor.clear_activity_badge()
		else:
			actor.set_activity_badge(badge_text)

		var social_session: SocialSession = (
			_world.social_system.reservation_book.get_session_for(character.id)
		)
		if (
			character.movement.status == MovementState.STATUS_MOVING
			and character.movement.intent != null
		):
			_social_session_ids.erase(character.id)
			var intent: MovementIntent = character.movement.intent
			var active_target: StringName = _active_target_ids.get(
				character.id,
				&""
			)
			if active_target != intent.target_object_id:
				actor.set_movement_target(
					_presentation_target_for(character.id, intent),
					intent.arrival_radius
				)
				_active_target_ids[character.id] = intent.target_object_id
		else:
			if _active_target_ids.has(character.id):
				actor.stop_movement()
				_active_target_ids.erase(character.id)
			_sync_social_presentation(
				character.id,
				actor,
				social_session
			)

func _sync_social_presentation(
	character_id: StringName,
	actor: ResidentActor3D,
	session: SocialSession
) -> void:
	if actor == null:
		return

	if session == null:
		if _social_session_ids.has(character_id):
			actor.stop_movement()
			_social_session_ids.erase(character_id)
		return

	var active_session: StringName = _social_session_ids.get(
		character_id,
		&""
	)
	if active_session == session.session_id:
		return

	var target := _social_target_for(session, character_id)
	actor.set_movement_target(target, 0.32)
	_social_session_ids[character_id] = session.session_id

func _social_target_for(
	session: SocialSession,
	character_id: StringName
) -> Vector3:
	if session == null:
		return Vector3.ZERO

	var initiator_actor := actor_for(session.initiator_id)
	var target_actor := actor_for(session.target_id)
	if initiator_actor == null or target_actor == null:
		var fallback := actor_for(character_id)
		return fallback.global_position if fallback != null else Vector3.ZERO

	var initiator_position := initiator_actor.global_position
	var target_position := target_actor.global_position
	var direction := target_position - initiator_position
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		direction = Vector3(1.0, 0.0, 0.0)
	else:
		direction = direction.normalized()

	var midpoint := (initiator_position + target_position) * 0.5
	var half_spacing := 0.62
	if character_id == session.initiator_id:
		return midpoint - direction * half_spacing
	return midpoint + direction * half_spacing

func social_presentation_count() -> int:
	return _social_session_ids.size()

func _presentation_target_for(
	character_id: StringName,
	intent: MovementIntent
) -> Vector3:
	if intent == null:
		return Vector3.ZERO

	var target := intent.target_position
	var target_id := intent.target_object_id

	if target_id == &"fridge_main":
		return target + Vector3(0.0, 0.0, -0.92)
	if target_id == &"shower_main":
		return target + Vector3(-0.72, 0.0, -0.56)
	if str(target_id).begins_with("bed_"):
		return target + Vector3(0.0, 0.0, 1.02)
	if target_id != &"sofa_main":
		return target

	var sofa_slots: Array[Vector3] = [
		Vector3(-0.82, 0.0, -0.62),
		Vector3(0.0, 0.0, -0.72),
		Vector3(0.82, 0.0, -0.62),
		Vector3(-0.82, 0.0, 0.48),
		Vector3(0.0, 0.0, 0.58),
		Vector3(0.82, 0.0, 0.48),
	]
	var suffix := str(character_id).get_slice("_", 1).to_int()
	var slot_index := maxi(suffix - 1, 0) % sofa_slots.size()
	return target + sofa_slots[slot_index]

func _shift_time_scale(direction: int) -> void:
	if _world == null or direction == 0:
		return

	var scales: Array[float] = [1.0, 5.0, 10.0, 20.0]
	var current := _world.clock.get_time_scale()
	var next_scale := current

	if direction > 0:
		for scale in scales:
			if scale > current + 0.001:
				next_scale = scale
				break
	else:
		for index in range(scales.size() - 1, -1, -1):
			var scale: float = scales[index]
			if scale < current - 0.001:
				next_scale = scale
				break

	_world.clock.set_time_scale(next_scale)
	if hud != null:
		hud.set_latest_event("Simulation speed %.0fx" % next_scale)
		hud.refresh()

func select_resident(
	character_id: StringName,
	focus_camera: bool = true
) -> bool:
	if _world == null or character_id == &"":
		return false
	var character := _world.get_character(character_id)
	var actor := actor_for(character_id)
	if character == null or actor == null:
		return false

	_selected_resident_id = character_id
	for actor_id in _actors.keys():
		var candidate := actor_for(actor_id)
		if candidate != null:
			candidate.set_selected(actor_id == character_id)

	if hud != null:
		hud.set_selected_resident(character_id)
		hud.set_latest_event("Selected %s" % character.display_name)

	if focus_camera:
		_manual_focus_remaining = maxf(manual_focus_seconds, 0.0)
	return true

func selected_resident_id() -> StringName:
	return _selected_resident_id

func set_simulation_paused(value: bool) -> void:
	advance_simulation = not value
	if hud != null:
		hud.set_simulation_running(advance_simulation)

func is_simulation_paused() -> bool:
	return not advance_simulation

func _on_actor_selected(character_id: StringName) -> void:
	select_resident(character_id)

func _on_hud_resident_requested(character_id: StringName) -> void:
	select_resident(character_id)

func _on_hud_command_requested(command_id: StringName) -> void:
	if _world == null or _selected_resident_id == &"":
		return
	var target := _command_target(command_id, _selected_resident_id)
	if target.is_empty():
		if hud != null:
			hud.set_latest_event("Unknown command: %s" % command_id)
		return

	var character := _world.get_character(_selected_resident_id)
	if character == null:
		return

	var accepted := _world.request_interaction(
		_selected_resident_id,
		target["object_id"],
		target["interaction_id"]
	)
	if hud != null:
		if accepted:
			hud.set_latest_event(
				"%s → %s" % [
					character.display_name,
					target["label"],
				]
			)
		else:
			hud.set_latest_event(
				"%s cannot %s right now" % [
					character.display_name,
					target["label"],
				]
			)

func _command_target(
	command_id: StringName,
	character_id: StringName
) -> Dictionary:
	match command_id:
		&"eat":
			return {
				"object_id": &"fridge_main",
				"interaction_id": &"eat",
				"label": "eat",
			}
		&"relax":
			return {
				"object_id": &"sofa_main",
				"interaction_id": &"relax",
				"label": "relax",
			}
		&"shower":
			return {
				"object_id": &"shower_main",
				"interaction_id": &"shower",
				"label": "shower",
			}
		&"watch_tv":
			return {
				"object_id": &"tv_main",
				"interaction_id": &"watch_tv",
				"label": "watch TV",
			}
		&"read":
			return {
				"object_id": &"bookshelf_main",
				"interaction_id": &"read",
				"label": "read",
			}
		&"sleep":
			var suffix := str(character_id).get_slice("_", 1).to_int()
			if suffix <= 0:
				return {}
			return {
				"object_id": StringName("bed_%02d" % suffix),
				"interaction_id": StringName("sleep_%02d" % suffix),
				"label": "sleep",
			}
	return {}

func _update_camera_director(delta: float) -> void:
	if camera_director == null or _world == null:
		return

	if _manual_focus_remaining > 0.0:
		_manual_focus_remaining = maxf(
			_manual_focus_remaining - maxf(delta, 0.0),
			0.0
		)
		var selected_actor := actor_for(_selected_resident_id)
		if selected_actor != null and camera_rig != null:
			camera_rig.focus_world_position(
				selected_actor.global_position + Vector3(0.0, 0.85, 0.0),
				manual_focus_ortho_size
			)
			return

	for character in _world.characters():
		if character == null:
			continue
		var actor := actor_for(character.id)
		if actor == null:
			continue

		var interest := _presentation_interest(character)
		camera_director.suggest_focus(
			character.id,
			actor.global_position + Vector3(0.0, 0.85, 0.0),
			interest
		)

	camera_director.tick(delta)

func _presentation_interest(character: CharacterState) -> float:
	var score := 0.0

	if character.current_action_id != &"idle":
		score += 24.0
	if character.movement.status == MovementState.STATUS_MOVING:
		score += 34.0
	if _world.social_system.reservation_book.is_reserved(character.id):
		score += 28.0
	if character.needs.hunger.value <= 20.0:
		score += 18.0
	if character.needs.energy.value <= 20.0:
		score += 18.0
	if character.goals != null and not character.goals.active_goals().is_empty():
		score += 5.0

	return score

func activity_badge_for(character: CharacterState) -> String:
	if character == null:
		return ""

	if (
		_world != null
		and _world.social_system.reservation_book.is_reserved(character.id)
	):
		return "SOCIAL"

	var action_text := str(character.current_action_id).to_lower()
	if action_text.is_empty() or action_text == "idle":
		return ""
	if (
		"eat" in action_text
		or "meal" in action_text
		or "coffee" in action_text
		or "food" in action_text
	):
		return "MEAL"
	if "work" in action_text:
		return "WORK"
	if (
		"shower" in action_text
		or "wash" in action_text
		or "hygiene" in action_text
	):
		return "CARE"
	if (
		"relax" in action_text
		or "fun" in action_text
		or "sofa" in action_text
		or "watch" in action_text
		or "tv" in action_text
		or "read" in action_text
	):
		return "FUN"
	return "ACTION"

func presentation_state_for(character: CharacterState) -> StringName:
	if character == null:
		return ResidentActor3D.STATE_IDLE

	if (
		character.movement.status == MovementState.STATUS_MOVING
		and character.movement.intent != null
	):
		return ResidentActor3D.STATE_WALK

	if (
		_world != null
		and _world.social_system.reservation_book.is_reserved(character.id)
	):
		return ResidentActor3D.STATE_SOCIAL

	if character.current_action_id != &"idle":
		return ResidentActor3D.STATE_INTERACT

	return ResidentActor3D.STATE_IDLE

func actor_for(character_id: StringName) -> ResidentActor3D:
	return _actors.get(character_id) as ResidentActor3D

func actor_count() -> int:
	return _actors.size()

func active_movement_count() -> int:
	return _active_target_ids.size()

func validate_visual_state() -> Array[String]:
	var errors: Array[String] = []
	if _world == null:
		errors.append("visual shell has no bound world")
		return errors

	var residents: Array[CharacterState] = _world.characters()
	if _actors.size() != residents.size():
		errors.append(
			"actor count %d does not match resident count %d"
			% [_actors.size(), residents.size()]
		)

	if _selected_resident_id != &"" and actor_for(_selected_resident_id) == null:
		errors.append(
			"selected resident has no actor: %s" % _selected_resident_id
		)

	var resident_ids: Dictionary = {}
	for character in residents:
		if character == null or character.id == &"":
			errors.append("visual shell contains invalid resident")
			continue
		resident_ids[character.id] = true

		var actor := actor_for(character.id)
		if actor == null or not is_instance_valid(actor):
			errors.append("missing actor for resident %s" % character.id)
			continue
		if actor.is_selected() != (character.id == _selected_resident_id):
			errors.append(
				"selection marker mismatch for %s" % character.id
			)

		var has_visual_target := _active_target_ids.has(character.id)
		var is_authoritatively_moving: bool = (
			character.movement.status == MovementState.STATUS_MOVING
			and character.movement.intent != null
		)

		if has_visual_target and not is_authoritatively_moving:
			errors.append(
				"stale visual movement ownership for %s"
				% character.id
			)
		elif has_visual_target and is_authoritatively_moving:
			var visual_target: StringName = _active_target_ids[character.id]
			if visual_target != character.movement.intent.target_object_id:
				errors.append(
					"visual movement target mismatch for %s"
					% character.id
				)

	for actor_id in _actors.keys():
		if not resident_ids.has(actor_id):
			errors.append("orphan visual actor %s" % actor_id)

	for moving_id in _active_target_ids.keys():
		if not resident_ids.has(moving_id):
			errors.append("orphan visual movement owner %s" % moving_id)

	for social_id in _social_session_ids.keys():
		if not resident_ids.has(social_id):
			errors.append("orphan social presentation owner %s" % social_id)
			continue
		var session := _world.social_system.reservation_book.get_session_for(
			social_id
		)
		if session == null:
			errors.append("stale social presentation owner %s" % social_id)
		elif _social_session_ids[social_id] != session.session_id:
			errors.append("social presentation session mismatch for %s" % social_id)

	return errors

func _target_display_name(target_id: StringName) -> String:
	match target_id:
		&"fridge_main":
			return "fridge"
		&"sofa_main":
			return "sofa"
		&"shower_main":
			return "shower"
		&"tv_main":
			return "TV"
		&"bathroom_sink_main":
			return "bathroom sink"
		&"bookshelf_main":
			return "bookshelf"

	var raw := str(target_id)
	if raw.begins_with("bed_"):
		var number := raw.trim_prefix("bed_").to_int()
		return "bed %d" % number
	return raw.replace("_", " ")

func _on_actor_arrived(character_id: StringName) -> void:
	if _world == null:
		return
	var target_id: StringName = _active_target_ids.get(character_id, &"")
	if target_id == &"":
		return

	_world.report_arrival(character_id, target_id)
	var character := _world.get_character(character_id)
	var display_name := (
		character.display_name if character != null else str(character_id)
	)
	hud.set_latest_event(
		"%s arrived at %s" % [
			display_name,
			_target_display_name(target_id),
		]
	)
	var actor := actor_for(character_id)
	if camera_director != null and actor != null:
		camera_director.suggest_focus(
			character_id,
			actor.global_position + Vector3(0.0, 0.85, 0.0),
			90.0
		)
	_active_target_ids.erase(character_id)

func _on_actor_failed(character_id: StringName) -> void:
	if _world == null:
		return
	var target_id: StringName = _active_target_ids.get(character_id, &"")
	if target_id == &"":
		return

	_world.report_movement_failure(character_id, target_id)
	var character := _world.get_character(character_id)
	var display_name := (
		character.display_name if character != null else str(character_id)
	)
	hud.set_latest_event(
		"%s could not reach %s" % [
			display_name,
			_target_display_name(target_id),
		]
	)
	_active_target_ids.erase(character_id)

func _clear_actors() -> void:
	_active_target_ids.clear()
	_social_session_ids.clear()
	_actors.clear()
	_selected_resident_id = &""
	_manual_focus_remaining = 0.0

	if not is_instance_valid(resident_actors):
		return
	for child in resident_actors.get_children():
		child.queue_free()
