package voxel_game

Item_Type :: enum {
    Dirt, Stone, Cobblestone, Glass, Planks,
    Redstone, Slab, Stairs,
}

Item_Info :: struct {
    block: Maybe(Block_Type)
}
items := [Item_Type]Item_Info{
    .Dirt = {
        block = .Dirt,
    },
    .Stone = {
        block = .Stone,
    },
    .Cobblestone = {
        block = .Cobblestone,
    },
    .Glass = {
        block = .Glass,
    },
    .Planks = {
        block = .Planks,
    },
    .Redstone = {
        block = .Redstone,
    },
    .Slab = {
        block = .Slab,
    },
    .Stairs = {
        block = .Stairs,
    }
}