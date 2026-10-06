# LIFEBOX LIVE — Social Conversation Staging Specification

## Goal

Make simulation-authoritative social sessions visually understandable without changing the established action-priority rules.

## Simulation contract

- Existing SmartObject action priority is preserved.
- SocialSystem continues to reserve only residents that are idle and not already moving or executing another action.
- Active SmartObject actions cannot be displaced by presentation logic.
- Relationships, memories and social outcomes remain owned by SocialSystem.

## Presentation staging

- When an authoritative SocialSession exists, its two resident actors receive presentation-only navigation targets.
- Partners move toward a deterministic shared midpoint and stop roughly face-to-face.
- Social staging ownership is tracked separately from authoritative SmartObject movement ownership.
- A staging arrival never calls SimulationWorld.report_arrival because there is no SmartObject movement intent to acknowledge.
- Ending the SocialSession clears any remaining presentation-only movement.

## HUD

The selected resident action line identifies the partner for an active social session, e.g. `chat with Leo`.

## Definition of Done

- existing SmartObject-over-social priority tests remain unchanged and green;
- active social partners can visually converge;
- social staging does not mutate simulation needs, actions, reservations, relationships or RNG;
- stale presentation-session ownership is detected;
- regression and soak suites pass.
