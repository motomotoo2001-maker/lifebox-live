# LIFEBOX LIVE — Camera Modes & Vertical Composition Specification

## Goal

Give the player predictable camera control and improve portrait framing so focused residents do not push most of the house out of view.

## Camera rig

The rig translates part-way toward the requested focus target while it rotates and zooms:
- establishing view keeps its authored position;
- focused views shift the rig on the house plane by a bounded strength;
- translation uses the same exponential smoothing as target and zoom.

## Camera modes

- AUTO: Story/Camera Director chooses interesting residents.
- FOLLOW: camera continuously follows the selected resident.
- OVERVIEW: camera stays on the full-house establishing composition.
- C cycles modes.
- Escape switches directly to OVERVIEW.
- Selecting a resident still works in every mode.

## HUD

The top status displays camera mode and the controls hint includes C CAMERA.

## Definition of Done

- camera rig smoothly translates toward focus;
- auto/follow/overview modes are selectable;
- HUD reports current camera mode;
- existing simulation authority remains unchanged;
- camera/runtime tests pass;
- real 9:16 capture has improved composition.
