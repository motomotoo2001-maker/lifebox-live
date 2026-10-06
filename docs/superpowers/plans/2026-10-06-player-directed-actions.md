# Player Directed Actions Implementation Plan

1. Add SimulationWorld.request_smart_object_action().
2. Validate requested resident/object/interaction and preserve ActionExecutor ownership.
3. Add player_action to ReplayLog and ReplayPlayer.
4. Author a six-button DIRECT ACTION HUD bar.
5. Map commands in VisualSimulationShell and target the selected resident.
6. Add authoritative integration, HUD, shell and replay contracts.
7. Run full Godot CI/headless tests.
8. Capture a real 9:16 playable screenshot.
