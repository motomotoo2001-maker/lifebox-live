# Player Interaction Commands Implementation Plan

1. Add SimulationWorld.request_interaction() with strict idle/reservation/money validation.
2. Add interaction_request support to ReplayLog and ReplayPlayer.
3. Add a six-button command strip to VisualHUD.
4. Route command_requested through VisualSimulationShell.
5. Resolve SLEEP to the selected resident's own bed deterministically.
6. Show command accepted/rejected feedback in the event panel.
7. Add integration coverage for valid, busy and invalid manual interaction requests.
8. Run full Godot regression and capture a 9:16 playable checkpoint.
