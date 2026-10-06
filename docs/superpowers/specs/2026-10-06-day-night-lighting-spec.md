# LIFEBOX LIVE — Dynamic Day/Night Lighting Specification

## Goal

Tie the dollhouse lighting to the authoritative simulation clock so the apartment visibly changes through night, dawn, day and dusk.

## Presentation rules

- SimulationWorld remains the only time authority.
- DayNightController reads SimulationClock and never mutates it.
- Four presentation phases are used: night, dawn, day, dusk.
- Outdoor/background ambient light, directional key light and fill light interpolate by time.
- Interior lamps become strong at night and subdued during the day.
- HUD shows the current visual phase beside RUN/PAUSED and simulation speed.

## Visual direction

- Night: deep blue ambient, low moon-like key light, strong warm indoor pools.
- Dawn: warm peach transition with slowly fading interior lights.
- Day: bright soft-blue environment with warm-neutral sun.
- Dusk: orange key light falling into blue night.

## Definition of Done

- DayNightController exists in the playable showcase.
- It binds to SimulationWorld and derives lighting only from SimulationClock.
- 00:00, 06:00, 12:00, 19:00 and 23:00 classify deterministically.
- Day is brighter than night.
- Indoor light is stronger at night than at noon.
- HUD shows NIGHT/DAWN/DAY/DUSK.
- Runtime tests and real 9:16 capture pass.
