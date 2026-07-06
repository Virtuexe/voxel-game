package voxel_game

import ui "raylib-ui"

Item_Type :: enum {
    Dirt, Stone, Cobblestone, Glass, Planks,
    Redstone, Slab, Stairs, Piston,
    Wire
}

Item_Info :: struct {
    block: Maybe(Block_Type),
    texture: ui.Texture,
    on_right_click: proc(),
}
items := [Item_Type]Item_Info{
    .Dirt = {
        block = .Dirt,
        on_right_click = block_place,
    },
    .Stone = {
        block = .Stone,
        on_right_click = block_place,
    },
    .Cobblestone = {
        block = .Cobblestone,
        on_right_click = block_place,
    },
    .Glass = {
        block = .Glass,
        on_right_click = block_place,
    },
    .Planks = {
        block = .Planks,
        on_right_click = block_place,
    },
    .Redstone = {
        block = .Redstone,
        on_right_click = block_place,
    },
    .Slab = {
        block = .Slab,
        on_right_click = block_place,
    },
    .Stairs = {
        block = .Stairs,
        on_right_click = block_place,
    },
    .Piston = {
        block = .Piston,
        on_right_click = block_place,
    },
    .Wire = {
        on_right_click = wire_use,
    }
}