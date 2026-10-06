# LIFEBOX LIVE — Action-specific Resident Animation Props Specification

## Goal

Make household actions visually legible from the dollhouse view instead of relying only on tiny text labels.

## Resident props and poses

Presentation-only resident visuals gain:
- READ: held book plus forward reading pose.
- EAT: meal tray/food prop plus eating hand motion.
- SHOWER / WASH UP: hands raised toward face/head.
- WATCH TV: relaxed forward-facing pose.
- RELAX: lower relaxed idle.
- SLEEP: floating Zzz indicator while interacting.

Props appear only while the resident is in the interaction presentation state. They stay hidden while walking to a target.

## Authority

ResidentActor3D receives the authoritative current_action_id from VisualSimulationShell. The props and transforms never change simulation state, interaction duration, movement intent, needs, money, goals, or reservations.

## Definition of Done

- authored action prop nodes exist on ResidentActor3D;
- actor exposes set_action_visual/action_visual_id;
- shell synchronizes current_action_id every visual refresh;
- read/eat/sleep have distinct visible props;
- hygiene, TV and relax have distinct poses;
- existing movement/social/selection animation contracts remain intact;
- regression suite and 9:16 visual capture pass.
