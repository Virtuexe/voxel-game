package voxel_game

import ui "raylib-ui"

Item_Type :: enum {
    Dirt, Stone, Cobblestone, Glass, Planks,
    Redstone, Slab, Stairs, Piston,
    Wire
}

Item_Info :: struct {
    block: Maybe(Block_Type),
    texture: Texture_Type,
    on_right_click: proc(),
}
items := [Item_Type]Item_Info{
    .Dirt = {
        block = .Dirt,
        texture = .Dirt,
        on_right_click = block_place,
    },
    .Stone = {
        block = .Stone,
        texture = .Stone,
        on_right_click = block_place,
    },
    .Cobblestone = {
        block = .Cobblestone,
        texture = .Cobblestone,
        on_right_click = block_place,
    },
    .Glass = {
        block = .Glass,
        texture = .Glass,
        on_right_click = block_place,
    },
    .Planks = {
        block = .Planks,
        texture = .Planks,
        on_right_click = block_place,
    },
    .Redstone = {
        block = .Redstone,
        texture = .Wire,
        on_right_click = block_place,
    },
    .Slab = {
        block = .Slab,
        texture = .Slab_Top,
        on_right_click = block_place,
    },
    .Stairs = {
        block = .Stairs,
        texture = .Planks,
        on_right_click = block_place,
    },
    .Piston = {
        block = .Piston,
        texture = .Piston_Top,
        on_right_click = block_place,
    },
    .Wire = {
        texture = .Wire,
        on_right_click = wire_use,
    }
}