# Manual Camera Controls Implementation Plan

1. Extend VerticalCameraRig with bounded pan and zoom APIs.
2. Track manual camera mode in VisualSimulationShell.
3. Read WASD/arrows continuously and wheel input through _unhandled_input.
4. Suspend CameraDirector while manual mode is active.
5. Exit manual mode on resident/direct-action focus or Escape.
6. Update HUD control hint.
7. Extend camera/shell runtime contracts.
8. Run Godot CI/headless tests and capture a viewport checkpoint.
