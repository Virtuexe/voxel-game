package voxel_game

import ui "raylib-ui"

Item_Type :: enum {
    Dirt, Stone, Cobblestone, Glass, Planks,
    Redstone, Slab, Stairs, Piston,
    Wire, Button,
}

Item_Info :: struct {
    block: Maybe(Block_Type),
    name: string,
    texture: Texture_Type,
    on_right_click: Maybe(proc()),
}
items := [Item_Type]Item_Info{
    .Dirt = {
        block = .Dirt,
        name = "Dirt",
        texture = .Dirt,
        on_right_click = block_place,
    },
    .Stone = {
        block = .Stone,
        name = "Stone",
        texture = .Stone,
        on_right_click = block_place,
    },
    .Cobblestone = {
        block = .Cobblestone,
        name = "Cobblestone",
        texture = .Cobblestone,
        on_right_click = block_place,
    },
    .Glass = {
        block = .Glass,
        name = "Glass",
        texture = .Glass,
        on_right_click = block_place,
    },
    .Planks = {
        block = .Planks,
        name = "Planks",
        texture = .Planks,
        on_right_click = block_place,
    },
    .Redstone = {
        block = .Redstone,
        name = "Redstone",
        texture = .Wire,
        on_right_click = block_place,
    },
    .Slab = {
        block = .Slab,
        name = "Slab",
        texture = .Slab_Top,
        on_right_click = block_place,
    },
    .Stairs = {
        block = .Stairs,
        name = "Stairs",
        texture = .Planks,
        on_right_click = block_place,
    },
    .Piston = {
        block = .Piston,
        name = "Piston",
        texture = .Piston_Top,
        on_right_click = block_place,
    },
    .Wire = {
        name = "Wire",
        texture = .Wire,
        on_right_click = wire_use,
    },
    .Button = {
        block = .Button,
        name = "Button",
        texture = .Stone,
        on_right_click = block_place,
    }
}