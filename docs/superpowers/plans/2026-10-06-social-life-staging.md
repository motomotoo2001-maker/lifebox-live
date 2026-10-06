# Social Life & Conversation Staging Implementation Plan

1. Split fixed-step resident processing into needs update, social scheduling, and SmartObject action selection.
2. Add a regression test proving social residents get a fair scheduling window even when a useful SmartObject exists.
3. Track presentation-only social session targets in VisualSimulationShell.
4. Move both social partners toward a deterministic face-to-face midpoint.
5. Show the partner name in the HUD action line.
6. Extend visual validation and runtime contracts.
7. Run the full Godot regression suite and capture a live 9:16 conversation checkpoint.
