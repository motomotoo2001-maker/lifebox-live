# Player Directed Social Actions Implementation Plan

1. Add SocialSystem.has_action() and request_session().
2. Add SimulationWorld.request_social_action() with deliberate SmartObject interruption.
3. Add player_social_action to ReplayLog / ReplayPlayer.
4. Author SOCIAL target selector + Chat / Compliment / Argue controls.
5. Route HUD social commands through VisualSimulationShell.
6. Reuse existing face-to-face social staging and partner action text.
7. Add authoritative social/replay integration coverage.
8. Run full Godot regression suite and capture a 9:16 checkpoint.
