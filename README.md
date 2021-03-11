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
* Painting with random weighted patterns of materials. Use stacks to specify probabilities of materials in the pattern.
* Mask support for conditional painting and replacing.
* Multilevel undo (see below)
* Drawing modifiers:
  * **Scatter** - randomly fill 5% of the paintable blocks.
  * **Surface** - only change blocks under air.
  * **Decorate** - only place new blocks on top of surface blocks.
  * **Landslide** - simulate falling of the nodes on the ground.
  * **Flat** - make the shape one node high.

How to use:

* "Punch" (Left click) - reconfigure the brush you hold
* "Place" (Right click) - use the brush.
* "Use" + "Place" (E + Right click) - undo.

### Undo `terraform:undo`

![(undo icon)](textures/terraform_tool_undo.png "Undo tool icon") 

The tool adds an in-memory undo engine that captures both edits with the Brush tool and
usual 'digs' and 'places'.

"Place" (Right click) to undo one change, hold to undo many changes (fun to watch).

### Light `terraform:light`

![(light icon)](textures/terraform_tool_light.png "Light tool icon") 

Turns on the light to work comfortably both during night and deep in the caves.

"Place" (Right click) to toggle.

### Light fixer `terraform:fixlight`

![(light fixer icon)](textures/terraform_tool_fix_light.png "Light fixer tool icon") 

This is a tiny helper tool to correct light and shadow problems in the world, which may happen when painting the world with Terraform Brush.

"Place" (Right click) to recalculate light in a cuboid within 100 blocks from the target.

### Teleport `terraform:teleport`

![(teleport icon)](textures/terraform_tool_teleport.png "Teleport tool icon") 

This tool teleports you to the position above the pointed block, preserving your elevation above the ground,
similar to flying with a helicopter. Click and hold to travel large distances.

"Place" (Right click) to use the teleport.

## Before you start

Here are important notes to know before you enable the mod on your server:

* You need "terraform" privilege to be able to use the tools. As server owner, grant
  terraform privilege only to trusted users.
* Several players using undo very close to each other may cause unexpected results.
* Current implementation of the undo engine consumes server memory and will lead
  to server crash if used for a very long time or by many players at once.
* Light recalculation, flow of liquids and falling of physical blocks (e.g. sand) are
  not triggered by the mod's tools and are not supported by the undo engine.
	You can fix the light with the Light fixer tool, trigger water flow by placing a water
	source and cause blocks to fall by digging one of them.

## Installation

Unpack the release package into `mods/terraform` folder of your Minetest installation and enable
`terraform` mod in the world properties.

Read more about installing mods in Minetest [here](https://wiki.minetest.net/Installing_Mods).

## Licenses

Code copyright (c) 2021 Dmitry Kostenko <codeforsmile@gmail.com>.

The code is licensed under AGPL-3.0 license, see the full license text in LICENSE.txt.

Images are licensed under CC0 1.0 Universal license https://creativecommons.org/publicdomain/zero/1.0/.
