package voxel_game
import rl "vendor:raylib"

Block_Texture_Type :: enum {
    Dirt, Stone, Cobblestone, Glass, Planks,
    Slab_Side, Slab_Top,
}

block_textures_paths := [Block_Texture_Type]cstring {
    .Dirt = "assets/dirt.png",
    .Stone = "assets/stone.png",
    .Cobblestone = "assets/cobblestone.png",
    .Glass = "assets/glass.png",
    .Planks = "assets/planks.png",
    .Slab_Side = "assets/slab_side.png",
    .Slab_Top = "assets/slab_top.png",
}

Block_Texture :: struct {
    texture: rl.Texture2D,
}

block_textures: [Block_Texture_Type]Block_Texture

init_block_textures :: proc() {
    for type in Block_Texture_Type {
        path := block_textures_paths[type]
        block_textures[type].texture = rl.LoadTexture(path)
    }
}

init_textures :: proc() {
    init_block_textures()
}