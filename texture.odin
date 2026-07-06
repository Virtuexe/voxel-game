package voxel_game
import rl "vendor:raylib"

Block_Texture_Type :: enum {
    Dirt, Stone, Cobblestone, Glass, Planks,
    Slab_Side, Slab_Top,
    Piston_Side, Piston_Top, Piston_Bottom, Piston_Inner
}

block_textures_paths := [Block_Texture_Type]cstring {
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
}

block_textures: [Block_Texture_Type]rl.Texture2D

init_block_textures :: proc() {
    for type in Block_Texture_Type {
        path := block_textures_paths[type]
        block_textures[type] = rl.LoadTexture(path)
    }
}

init_textures :: proc() {
    init_block_textures()
}