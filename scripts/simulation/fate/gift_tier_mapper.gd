class_name GiftTierMapper
extends RefCounted

const TIER_MICRO: StringName = &"micro"
const TIER_SMALL: StringName = &"small"
const TIER_MEDIUM: StringName = &"medium"
const TIER_LARGE: StringName = &"large"
const TIER_LEGENDARY: StringName = &"legendary"

func effective_value(gift_value: int, repeat_count: int) -> int:
	if gift_value < 0 or repeat_count < 1:
		return -1
	var result := gift_value * repeat_count
	if result < 0:
		return -1
	return result

func tier_for(gift_value: int, repeat_count: int = 1) -> StringName:
	var value := effective_value(gift_value, repeat_count)
	if value < 0:
		return &""
	if value < 10:
		return TIER_MICRO
	if value < 50:
		return TIER_SMALL
	if value < 200:
		return TIER_MEDIUM
	if value < 1000:
		return TIER_LARGE
	return TIER_LEGENDARY
