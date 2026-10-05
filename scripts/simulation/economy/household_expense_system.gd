class_name HouseholdExpenseSystem
extends RefCounted

const DAY_SECONDS := 86400.0

var daily_amount: float
var arrears: float = 0.0
var processed_days: int = 0

func _init(new_daily_amount: float = 0.0) -> void:
	if is_nan(new_daily_amount) or is_inf(new_daily_amount):
		daily_amount = 0.0
	else:
		daily_amount = maxf(new_daily_amount, 0.0)

func advance(
	residents: Array,
	simulation_seconds: float,
	economy: EconomySystem
) -> void:
	if economy == null:
		return
	if is_nan(simulation_seconds) or is_inf(simulation_seconds) or simulation_seconds < 0.0:
		return

	var completed_days := int(floor(simulation_seconds / DAY_SECONDS))
	while processed_days < completed_days:
		_charge_day(residents, economy, float(processed_days + 1) * DAY_SECONDS)
		processed_days += 1

func _charge_day(
	residents: Array,
	economy: EconomySystem,
	simulation_seconds: float
) -> void:
	if daily_amount <= 0.0:
		return

	var valid_residents: Array[CharacterState] = []
	for resident in residents:
		if resident == null:
			continue
		if not resident is CharacterState:
			continue
		if resident.id == &"":
			continue
		valid_residents.append(resident)

	if valid_residents.is_empty():
		arrears += daily_amount
		return

	var share := daily_amount / float(valid_residents.size())
	for resident in valid_residents:
		var paid := 0.0
		if not is_nan(resident.money) and not is_inf(resident.money) and resident.money > 0.0:
			var requested_payment := minf(resident.money, share)
			if requested_payment > 0.0:
				var transaction := economy.spend(
					resident,
					requested_payment,
					simulation_seconds
				)
				if transaction != null:
					paid = requested_payment

		arrears += share - paid
