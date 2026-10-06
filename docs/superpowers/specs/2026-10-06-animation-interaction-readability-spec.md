# LIFEBOX LIVE — Animation & Interaction Readability Specification

## Goal

Make the six-resident dollhouse visibly feel alive. Residents must have distinct presentation states for idle, walking, interacting and social activity, plus short event/emote feedback, without changing simulation authority.

## Presentation states

ResidentActor3D presentation state:
- idle
- walk
- interact
- social

The visual shell derives this state from authoritative simulation data.

## Animation behavior

Idle:
- restrained breathing/bob;
- subtle head sway.

Walk:
- stronger body bob;
- alternating arm and leg swing;
- face movement direction.

Interact:
- reduced locomotion;
- forward lean/pulse;
- small two-arm interaction gesture.

Social:
- conversational side sway;
- alternating hand gesture;
- subtle head tilt.

## Emote feedback

Residents can display a short presentation-only badge above the name label:
- work
- meal
- social
- fun
- alert

The badge is derived from current action/social state and can time out. It cannot mutate simulation state.

## Simulation authority

Presentation must never:
- change resident needs;
- set goals;
- create/cancel actions;
- alter relationships;
- alter RNG state.

Movement feedback signals remain the only presentation→simulation bridge already present.

## Determinism

Given the same authoritative state and actor profile, presentation-state selection must be deterministic.

## Definition of Done

- all four visual states have visibly different poses/motion;
- movement continues to use NavigationAgent3D;
- visual shell maps authoritative state to presentation state;
- social residents display social visual state;
- active non-movement actions display interact state;
- idle residents return to neutral idle state;
- event/emote badge can be set/cleared without gameplay mutation;
- existing visual checkpoint remains 9:16 and deterministic;
- all existing tests stay green.
