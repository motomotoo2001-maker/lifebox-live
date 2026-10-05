class_name PersonalityState
extends RefCounted

const DEFAULT_TRAIT := 0.5
const MIN_TRAIT := 0.0
const MAX_TRAIT := 1.0

var _sociability: float = DEFAULT_TRAIT
var _neatness: float = DEFAULT_TRAIT
var _ambition: float = DEFAULT_TRAIT
var _kindness: float = DEFAULT_TRAIT
var _impulsiveness: float = DEFAULT_TRAIT
var _confidence: float = DEFAULT_TRAIT
var _humor: float = DEFAULT_TRAIT
var _jealousy: float = DEFAULT_TRAIT

var sociability: float:
	get:
		return _sociability
	set(new_value):
		_sociability = _sanitize_trait(new_value)

var neatness: float:
	get:
		return _neatness
	set(new_value):
		_neatness = _sanitize_trait(new_value)

var ambition: float:
	get:
		return _ambition
	set(new_value):
		_ambition = _sanitize_trait(new_value)

var kindness: float:
	get:
		return _kindness
	set(new_value):
		_kindness = _sanitize_trait(new_value)

var impulsiveness: float:
	get:
		return _impulsiveness
	set(new_value):
		_impulsiveness = _sanitize_trait(new_value)

var confidence: float:
	get:
		return _confidence
	set(new_value):
		_confidence = _sanitize_trait(new_value)

var humor: float:
	get:
		return _humor
	set(new_value):
		_humor = _sanitize_trait(new_value)

var jealousy: float:
	get:
		return _jealousy
	set(new_value):
		_jealousy = _sanitize_trait(new_value)

func _sanitize_trait(raw_value: float) -> float:
	if is_nan(raw_value):
		return DEFAULT_TRAIT
	return clampf(raw_value, MIN_TRAIT, MAX_TRAIT)
