# Player Activity Commands Implementation Plan

1. Add SimulationWorld.request_interaction() using ActionExecutor/SmartObject authority.
2. Add integration tests for valid, invalid, non-interrupting and interrupting requests.
3. Author six direct-action HUD buttons.
4. Route activity_requested through VisualSimulationShell for the selected resident.
5. Keep movement/effects/reservations on existing authoritative paths.
6. Run full Godot tests and capture a vertical checkpoint.
