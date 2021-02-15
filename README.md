# Terraform 

A mod for [Minetest](https://www.minetest.net/).

## Description

Toolbox for creating custom landscapes in Minetest worlds.
Initially inspired by [WorldEdit for Minecraft](https://worldedit.enginehub.org/en/latest/) and
[WorldEdit for Minetest](https://github.com/Uberi/Minetest-WorldEdit), the goal is to create a comfortable 
editing environment that can also be used by children.

## Tools and features

The mod is implemented as a set of items that are added to your creative inventory. Search for _"terraform"_ in the inventory to find all the tools.

### Brush `terraform:brush`

![(brush icon)](images/terraform_tool_brush_green.png "Brush tool icon") 

Paint the world with broad strokes. Use the brush to add, remove or reshape the terrain. Features:

* Basic shapes: **Sphere**, **Cube** and **Cylinder**.
* Advanced modes:
  * **Plateau** mode for building cliffs and cascades up to 100 blocks high.
  * **Smooth** mode to remove small speckles, smoothen descends and add rounded corners.
  * **Trowel** mode to reshape material.
* Visual configuration dialog with ability to search or browse for blocks.
* Mask support for conditional painting and replacing.
* Integration with Undo engine (see below)
* A number of drawing modifiers:
  * **Scatter** - randomly fill 5% of the paintable blocks.
  * **Surface** - only change blocks under air.
  * **Decorate** - only place new blocks on top of surface blocks.

How to use:

* "Punch" (Left click) - reconfigure the brush you hold
* "Place" (Right click) - use the brush.
* "Use" + "Place" (E + Right click) - undo.

### Undo `terraform:undo`

![(undo icon)](textures/terraform_tool_undo.png "Undo tool icon") 

The name speaks for itself. The tool adds an in-memory undo engine that captures edits of each player and allows them to undo their changes to the world.

"Place" (Right click) to undo one change, hold to undo many changes (fun to watch).

### Light `terraform:light`

![(light icon)](textures/terraform_tool_light.png "Light tool icon") 

Turns on light to work comfortably both during night and deep in the caves.

"Place" (Right click) to toggle.

### Light fixer `terraform:fixlight`

![(light fixer icon)](textures/terraform_tool_fix_light.png "Light fixer tool icon") 

This is a tiny helper tool to correct light and shadow problems in the world, which may happen when painting the world with Terraform Brush.

"Place" (Right click) to recalculate light within 100 blocks manhattan distance from the target.

