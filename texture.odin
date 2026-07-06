package voxel_game
import rl "vendor:raylib"

Texture_Type :: enum {
    //Blocks
    Dirt, Stone, Cobblestone, Glass, Planks,
    Slab_Side, Slab_Top,
    Piston_Side, Piston_Top, Piston_Bottom, Piston_Inner,
    //Items
    Wire, Copper_Wire,
}

texture_paths := [Texture_Type]cstring {
    .Dirt = "assets/dirt.png",
    .Stone = "assets/stone.png",
    .Cobblestone = "assets/cobblestone.png",
    .Glass = "assets/glass.png",
    .Planks = "assets/planks.png",
    .Slab_Side = "assets/slab_side.png",
    .Slab_Top = "assets/slab_top.png",
    .Piston_Side = "assets/piston_side.png",
    .Piston_Top = "assets/piston_top.png",
    .Piston_Bottom = "assets/piston_bottom.png",
    .Piston_Inner = "assets/piston_inner.png",
    .Wire = "assets/wire.png",
    .Copper_Wire = "assets/copper_wire.png",
}

textures: [Texture_Type]rl.Texture2D

init_textures :: proc() {
    for type in Texture_Type {
        path := texture_paths[type]
        textures[type] = rl.LoadTexture(path)
    }
}