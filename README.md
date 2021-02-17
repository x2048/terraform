# Terraform 

A mod for [Minetest](https://www.minetest.net/).

## Description

This mod provides a toolbox for creating custom landscapes in Minetest worlds.
The project was initially inspired by [WorldEdit for Minecraft](https://enginehub.org/worldedit/)
and [WorldEdit for Minetest](https://github.com/Uberi/Minetest-WorldEdit), and has been
both exploration of Minetest mod API and user interface capabilities and an attempt to
create a simple and comfortable editing experience.

## Tools and features

The mod is implemented as a set of tool items that are added to your creative inventory.
Search for _"terraform"_ in the inventory to find all the tools.

### Brush `terraform:brush`

![(brush icon)](images/terraform_tool_brush_green.png "Brush tool icon") 

Paint the world with broad strokes. This is the primary tool of Terraform that
you can use to add, remove or reshape the terrain. The brush features:

* Basic shapes: **Sphere**, **Cube** and **Cylinder**.
* Advanced modes:
  * **Plateau** mode for building cliffs and cascades.
  * **Smooth** mode to remove small speckles, smoothen descends and add rounded corners.
  * **Trowel** mode to reshape material.
* Visual configuration dialog with ability to search or browse for blocks.
* Painting with random patterns using multiple block types.
* Mask support for conditional painting and replacing.
* Multilevel undo (see below)
* Drrawing modifiers:
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

Turns on the light to work comfortably both during night and deep in the caves.

"Place" (Right click) to toggle.

### Light fixer `terraform:fixlight`

![(light fixer icon)](textures/terraform_tool_fix_light.png "Light fixer tool icon") 

This is a tiny helper tool to correct light and shadow problems in the world, which may happen when painting the world with Terraform Brush.

"Place" (Right click) to recalculate light in a cuboid within 100 blocks from the target.

