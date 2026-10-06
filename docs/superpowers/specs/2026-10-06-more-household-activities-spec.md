# LIFEBOX LIVE — More Household Activities Specification

## Goal

Increase autonomous variety so six residents visibly spread through the home and choose more believable leisure and hygiene activities.

## New SmartObjects

- TV: watch_tv, improves mood and comfort.
- Bathroom sink: wash_up, improves hygiene and a little comfort.
- Bookshelf: read, improves mood and comfort.

All actions remain data-driven SmartObject interactions selected by the existing UtilityAI. Presentation does not directly change needs.

## Visual feedback

- watch_tv and read display FUN.
- wash_up/shower display CARE.
- existing action labels and camera direction continue to reflect authoritative resident state.

## Definition of Done

- three new destination markers exist;
- showcase registers three new SmartObjects;
- UtilityAI can select them through normal scoring;
- badges classify their actions;
- runtime contracts cover the new destinations;
- full Godot test suite remains green;
- real 9:16 viewport capture shows broader household activity.
