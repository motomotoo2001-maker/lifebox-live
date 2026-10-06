# Action-specific Resident Animation Props Implementation Plan

1. Add authored Book, MealTray, Food and SleepBubble props to ResidentActor3D.
2. Add action_visual_id presentation state.
3. Reset props every animation frame and enable only during interaction.
4. Add action-specific hand/head/arm poses for read, eat, hygiene, TV, relax and sleep.
5. Synchronize current_action_id from VisualSimulationShell.
6. Extend ResidentActor3D runtime contract.
7. Run full Godot CI/headless tests and capture a viewport checkpoint.
