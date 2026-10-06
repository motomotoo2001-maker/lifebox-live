# LIFEBOX LIVE — Manual Camera Controls Specification

## Goal

Give the player practical camera control for inspecting a multi-room household while retaining the autonomous camera director as an optional default.

## Controls

- W/A/S/D or arrow keys: pan the orthographic view across the house.
- Mouse wheel: zoom in/out.
- Any pan/zoom enters manual camera mode.
- Selecting a resident or issuing a direct action exits free-camera mode and performs the existing resident focus.
- Escape exits manual/focus mode and returns to the establishing autonomous camera.

## Camera bounds

- Orthographic size is clamped to an authored minimum/maximum.
- Camera target X/Z is clamped around the household footprint so the player cannot lose the house in empty space.
- Y target remains presentation-owned and is not changed by pan input.

## Architecture

- VerticalCameraRig owns desired target, zoom and bounds.
- VisualSimulationShell owns input and whether manual camera mode is active.
- CameraDirector is simply suspended while manual camera mode is active.
- No camera state changes simulation authority or persistence.

## Definition of Done

- continuous keyboard pan works;
- wheel zoom works;
- pan/zoom is bounded;
- autonomous director does not fight manual input;
- resident focus intentionally exits manual mode;
- Escape restores autonomous establishing view;
- runtime contracts and visual checkpoint remain green.
