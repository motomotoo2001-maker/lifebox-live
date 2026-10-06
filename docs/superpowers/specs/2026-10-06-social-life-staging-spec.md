# LIFEBOX LIVE — Social Life & Conversation Staging Specification

## Goal

Make social behavior occur naturally in the normal six-resident household and make active conversations visually understandable.

## Simulation scheduling

- Needs update first.
- SocialSystem then receives one deterministic scheduling window.
- Residents reserved into a social session are skipped by SmartObject action selection.
- Remaining residents continue normal utility/action selection.
- Social sessions remain simulation-authoritative; presentation does not create or complete them.

This fixes the previous ordering where idle residents commonly committed to furniture interactions before SocialSystem could reserve them.

## Presentation staging

- Active social partners receive presentation-only navigation targets.
- Both residents move toward a shared midpoint and stop roughly face-to-face.
- These targets are tracked separately from authoritative SmartObject movement.
- Arrival from staging never calls SimulationWorld.report_arrival because it has no authoritative target ownership.
- When the session ends, presentation-only movement is cleared.

## HUD

The selected resident action line includes the social partner, for example:
- chat with Leo
- compliment with Mira
- argue with Ivan

## Definition of Done

- SocialSystem runs before SmartObject selection each fixed simulation step.
- Existing social reservations still block SmartObject execution.
- Active social partners visibly converge.
- Social staging cannot mutate needs, relationships, RNG, or movement intent.
- Visual validation detects stale social presentation ownership.
- Regression/soak suites remain green.
