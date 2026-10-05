class_name NeedSystem
extends RefCounted

func advance_character(character: CharacterState, sim_delta_seconds: float) -> void:
	if character == null:
		return
	if is_nan(sim_delta_seconds) or sim_delta_seconds <= 0.0:
		return

	var sim_hours := sim_delta_seconds / 3600.0
	var profile = character.needs
	var need_states := [
		profile.hunger,
		profile.energy,
		profile.hygiene,
		profile.comfort,
		profile.social,
		profile.mood,
	]

	for need_state in need_states:
		need_state.apply_delta(-need_state.decay_per_sim_hour * sim_hours)
