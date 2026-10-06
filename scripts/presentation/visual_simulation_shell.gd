class_name VisualSimulationShell
extends Node3D

const RESIDENT_ACTOR_SCENE := preload(
	"res://scenes/characters/resident_actor_3d.tscn"
)

@export var advance_simulation: bool = true

@onready var household: HouseholdBlockout = $HouseholdBlockout
@onready var resident_actors: Node3D = $ResidentActors
@onready var camera_rig: VerticalCameraRig = $VerticalCameraRig
@onready var camera_director: CameraDirector = $CameraDirector
@onready var hud: VisualHUD = $HUDLayer/VisualHUD

var _world: SimulationWorld = null
var _actors: Dictionary = {}
var _active_target_ids: Dictionary = {}

func _ready() -> void:
	if camera_director != null:
		camera_director.bind_camera_rig(camera_rig)

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
		actor.set_visual_color(_palette[index % _palette.size()])
		actor.movement_arrived.connect(_on_actor_arrived)
		actor.movement_failed.connect(_on_actor_failed)
		_actors[character.id] = actor

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

		if (
			character.movement.status == MovementState.STATUS_MOVING
			and character.movement.intent != null
		):
			var intent: MovementIntent = character.movement.intent
			var active_target: StringName = _active_target_ids.get(
				character.id,
				&""
			)
			if active_target != intent.target_object_id:
				actor.set_movement_target(
					intent.target_position,
					intent.arrival_radius
				)
				_active_target_ids[character.id] = intent.target_object_id
		else:
			if _active_target_ids.has(character.id):
				actor.stop_movement()
				_active_target_ids.erase(character.id)

func _update_camera_director(delta: float) -> void:
	if camera_director == null or _world == null:
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

func actor_for(character_id: StringName) -> ResidentActor3D:
	return _actors.get(character_id) as ResidentActor3D

func actor_count() -> int:
	return _actors.size()

func _on_actor_arrived(character_id: StringName) -> void:
	if _world == null:
		return
	var target_id: StringName = _active_target_ids.get(character_id, &"")
	if target_id == &"":
		return

	_world.report_arrival(character_id, target_id)
	hud.set_latest_event("%s arrived at %s" % [character_id, target_id])
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
	hud.set_latest_event("%s movement failed: %s" % [character_id, target_id])
	_active_target_ids.erase(character_id)

func _clear_actors() -> void:
	_active_target_ids.clear()
	_actors.clear()

	if not is_instance_valid(resident_actors):
		return
	for child in resident_actors.get_children():
		child.queue_free()
