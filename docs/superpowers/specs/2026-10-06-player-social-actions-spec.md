# LIFEBOX LIVE — Player Directed Social Actions Specification

## Goal

Let the player explicitly choose who the selected resident talks to and what kind of social interaction they attempt, while keeping SocialSystem authoritative over reservations and outcomes.

## UI

A SOCIAL bar contains:
- a target selector listing all residents except the currently selected resident;
- CHAT;
- COMPLIMENT;
- ARGUE.

The selected resident is always the initiator.

## Authority

- VisualHUD emits target_id + action_id only.
- VisualSimulationShell routes that request to SimulationWorld.
- SimulationWorld validates resident IDs, target difference, action registration and existing social reservations.
- A deliberate player social command may cancel both participants' active SmartObject actions before the SocialSession starts.
- Existing active social sessions cannot be stacked or stolen.
- SocialSystem.request_session() owns the authoritative session reservation and current_action_id update.
- SocialSystem completion remains the only place that mutates relationships, memories and social-goal completion.

## Persistence / replay

Active SocialSessions already persist through SocialSystem state.
Replay adds player_social_action with:
- initiator_id;
- target_id;
- action_id.

ReplayPlayer routes the event through the same SimulationWorld API.

## Presentation

Existing Plan 16 social staging automatically moves the two authoritative session participants toward a face-to-face midpoint. HUD action text continues to show the partner.

## Definition of Done

- target selector excludes selected resident;
- chat/compliment/argue buttons emit stable IDs;
- valid request starts exactly one SocialSession;
- SmartObject actions are cleanly cancelled for both participants;
- active social reservations block stacking;
- relationship/memory outcome still occurs only on completion;
- replay produces the same snapshot;
- regression and visual capture are green.
