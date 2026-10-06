class_name DayNightController
extends Node

@export var update_interval_seconds: float = 0.15

var _world: SimulationWorld = null
var _refresh_accumulator: float = 0.0

@onready var world_environment: WorldEnvironment = $"../WorldEnvironment"
@onready var key_light: DirectionalLight3D = $"../KeyLight"
@onready var fill_light: DirectionalLight3D = $"../FillLight"
@onready var indoor_lights: Array[OmniLight3D] = [
	$"../KitchenWarmLight",
	$"../LivingWarmLight",
	$"../BedroomWarmLight",
	$"../BathroomCoolLight",
]

func _ready() -> void:
	_apply_hour(0.0)

func _process(delta: float) -> void:
	if _world == null:
		return
	_refresh_accumulator += maxf(delta, 0.0)
	if _refresh_accumulator < maxf(update_interval_seconds, 0.02):
		return
	_refresh_accumulator = 0.0

	var seconds := _world.clock.get_simulation_seconds()
	var hour := fmod(seconds / 3600.0, 24.0)
	_apply_hour(hour)

func bind_world(world: SimulationWorld) -> void:
	_world = world
	if _world != null:
		var seconds := _world.clock.get_simulation_seconds()
		_apply_hour(fmod(seconds / 3600.0, 24.0))

func phase_for_hour(hour: float) -> StringName:
	var normalized := fposmod(hour, 24.0)
	if normalized < 5.5:
		return &"night"
	if normalized < 8.0:
		return &"dawn"
	if normalized < 18.0:
		return &"day"
	if normalized < 21.0:
		return &"dusk"
	return &"night"

func sample_for_hour(hour: float) -> Dictionary:
	var normalized := fposmod(hour, 24.0)
	var phase := phase_for_hour(normalized)

	var sample := {
		"phase": phase,
		"background": Color("08101d"),
		"ambient_color": Color("617aa8"),
		"ambient_energy": 0.24,
		"key_color": Color("8ea9d6"),
		"key_energy": 0.18,
		"fill_energy": 0.10,
		"indoor_energy": 1.30,
		"sun_pitch": -28.0,
		"sun_yaw": -160.0,
	}

	if phase == &"day":
		var daylight: float = 1.0 - absf(normalized - 13.0) / 5.0
		daylight = clampf(daylight, 0.35, 1.0)
		sample["background"] = Color("7fa6cb").lerp(
			Color("a9c9e4"),
			daylight
		)
		sample["ambient_color"] = Color("d5e5f3")
		sample["ambient_energy"] = 0.72 + daylight * 0.18
		sample["key_color"] = Color("fff0cf")
		sample["key_energy"] = 0.92 + daylight * 0.30
		sample["fill_energy"] = 0.30
		sample["indoor_energy"] = 0.16
		sample["sun_pitch"] = -38.0 - daylight * 25.0
		sample["sun_yaw"] = lerpf(-80.0, 45.0, (normalized - 8.0) / 10.0)
		return sample

	if phase == &"dawn":
		var t := clampf((normalized - 5.5) / 2.5, 0.0, 1.0)
		sample["background"] = Color("10192b").lerp(Color("b88778"), t)
		sample["ambient_color"] = Color("7185ad").lerp(Color("d7b3a5"), t)
		sample["ambient_energy"] = lerpf(0.26, 0.68, t)
		sample["key_color"] = Color("94acd1").lerp(Color("ffd0a0"), t)
		sample["key_energy"] = lerpf(0.20, 0.86, t)
		sample["fill_energy"] = lerpf(0.11, 0.28, t)
		sample["indoor_energy"] = lerpf(1.22, 0.35, t)
		sample["sun_pitch"] = lerpf(-20.0, -42.0, t)
		sample["sun_yaw"] = lerpf(-118.0, -78.0, t)
		return sample

	if phase == &"dusk":
		var t := clampf((normalized - 18.0) / 3.0, 0.0, 1.0)
		sample["background"] = Color("9a746f").lerp(Color("09111e"), t)
		sample["ambient_color"] = Color("d6b1a0").lerp(Color("647aa3"), t)
		sample["ambient_energy"] = lerpf(0.68, 0.24, t)
		sample["key_color"] = Color("ffc07f").lerp(Color("8ea9d6"), t)
		sample["key_energy"] = lerpf(0.78, 0.18, t)
		sample["fill_energy"] = lerpf(0.26, 0.10, t)
		sample["indoor_energy"] = lerpf(0.40, 1.30, t)
		sample["sun_pitch"] = lerpf(-35.0, -18.0, t)
		sample["sun_yaw"] = lerpf(50.0, 135.0, t)
		return sample

	return sample

func _apply_hour(hour: float) -> void:
	var sample := sample_for_hour(hour)

	if is_instance_valid(world_environment):
		var environment := world_environment.environment
		if environment != null:
			environment.background_color = sample["background"]
			environment.ambient_light_color = sample["ambient_color"]
			environment.ambient_light_energy = sample["ambient_energy"]

	if is_instance_valid(key_light):
		key_light.light_color = sample["key_color"]
		key_light.light_energy = sample["key_energy"]
		key_light.rotation_degrees = Vector3(
			sample["sun_pitch"],
			sample["sun_yaw"],
			0.0
		)

	if is_instance_valid(fill_light):
		fill_light.light_energy = sample["fill_energy"]

	for light in indoor_lights:
		if is_instance_valid(light):
			light.light_energy = sample["indoor_energy"]

func current_phase() -> StringName:
	if _world == null:
		return &"night"
	var hour := fmod(_world.clock.get_simulation_seconds() / 3600.0, 24.0)
	return phase_for_hour(hour)
