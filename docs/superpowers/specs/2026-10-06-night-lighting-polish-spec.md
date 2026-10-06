# LIFEBOX LIVE — Night Lighting Polish Specification

## Goal

Keep the new simulation-driven night phase atmospheric without losing resident, furniture or room readability in the 9:16 dollhouse view.

## Changes

- Each of the three bedrooms receives its own warm OmniLight3D.
- The hallway receives a soft shared warm light.
- Night ambient and moon/fill intensity increase slightly.
- Kitchen, living room, bathroom and all new room lights remain controlled by DayNightController.
- Dawn and dusk interpolate from/to the new readable night baseline.

## Visual target

Night should remain visibly darker than day, but:
- skin/clothes must remain distinguishable;
- beds and room boundaries must remain readable;
- the center hallway must not collapse into black;
- warm interior pools should communicate an inhabited home.

## Definition of Done

- three bedroom lights and one hall light are authored;
- DayNightController owns all seven indoor lights;
- night ambient stays above the readability floor;
- day remains brighter than night and interior lights still dim at noon;
- tests and real midnight viewport capture pass.
