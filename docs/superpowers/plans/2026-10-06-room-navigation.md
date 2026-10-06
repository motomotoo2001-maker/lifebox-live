# Room-aware Navigation Implementation Plan

1. Add an authored NavigationRegion3D reference to HouseholdBlockout.
2. Generate a deterministic grid NavigationMesh for six rooms + central hall.
3. Exclude vertical divider strips in room bands.
4. Connect rooms to the hall only through three doorway spans per side.
5. Keep all existing destination markers and SmartObject movement intents unchanged.
6. Extend the household runtime contract to verify mesh density, wall exclusion, and doorway inclusion.
7. Run Godot CI/headless tests and a long-enough visual checkpoint to verify live movement.
