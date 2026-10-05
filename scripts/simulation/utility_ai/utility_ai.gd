class_name UtilityAI
extends RefCounted

func choose(
	character: CharacterState,
	candidates: Array[ActionCandidate],
	rng: RandomNumberGenerator
) -> ActionCandidate:
	var valid: Array[ActionCandidate] = []
	var best_score := -INF

	for candidate in candidates:
		if candidate == null or not candidate.is_valid_for(character):
			continue

		if candidate.score > best_score:
			best_score = candidate.score
			valid = [candidate]
		elif is_equal_approx(candidate.score, best_score):
			valid.append(candidate)

	if valid.is_empty():
		return ActionCandidate.new(&"idle", 0.0)

	if valid.size() == 1:
		return valid[0]

	if rng == null:
		return valid[0]

	return valid[rng.randi_range(0, valid.size() - 1)]
