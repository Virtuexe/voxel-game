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

Block_Texture :: struct {
    textures: [MAX_TEXTURE_GROUPS][Block_Face]Texture_Type,
    uv_rotations: [MAX_TEXTURE_GROUPS][Block_Face]UV_Rotation,
    uv_rects: [MAX_TEXTURE_GROUPS][Block_Face]UV_Rect,
    lock_uv_y: [MAX_TEXTURE_GROUPS][Block_Face]bool,
}

block_textures: [Block_Type]Block_Texture

UV_Rotation :: enum {
    Deg_0 = 0,
    Deg_90_CW = 1,
    Deg_180 = 2,
    Deg_90_CCW = 3,
}

UV_Rect :: struct {
    pos: [2]f32,
    size: [2]f32,
}

MAX_TEXTURE_GROUPS :: 4

fill_textures :: proc(tex: Texture_Type) -> [Block_Face]Texture_Type {
    return {.Top = tex, .Bottom = tex, .North = tex, .South = tex, .East = tex, .West = tex}
}

fill_uv_rects :: proc(rect: UV_Rect) -> [Block_Face]UV_Rect {
    return {.Top = rect, .Bottom = rect, .North = rect, .South = rect, .East = rect, .West = rect}
}

fill_uv_rotations :: proc(rot: UV_Rotation) -> [Block_Face]UV_Rotation {
    return {.Top = rot, .Bottom = rot, .North = rot, .South = rot, .East = rot, .West = rot}
}

fill_lock_uv_y :: proc(lock: bool) -> [Block_Face]bool {
    return {.Top = lock, .Bottom = lock, .North = lock, .South = lock, .East = lock, .West = lock}
}

// Converts a pixel region (0-16) to normalized 0.0-1.0 UV mapping coordinates.
// Perfect for accurately mapping subsets of textures to block geometry!
pixel_uv :: proc(x, y, w, h: f32) -> UV_Rect {
    return {{x / 16.0, y / 16.0}, {w / 16.0, h / 16.0}}
}

init_block_textures :: proc() {
    block_textures[.Dirt].textures[0] = fill_textures(.Dirt)
    
    block_textures[.Stone].textures[0] = fill_textures(.Stone)
    
    block_textures[.Cobblestone].textures[0] = fill_textures(.Cobblestone)
    
    block_textures[.Glass].textures[0] = fill_textures(.Glass)
    
    block_textures[.Planks].textures[0] = fill_textures(.Planks)
    
    block_textures[.Slab].textures[0] = fill_textures(.Slab_Side)
    block_textures[.Slab].textures[0][.Top] = .Slab_Top
    block_textures[.Slab].textures[0][.Bottom] = .Slab_Top
    
    block_textures[.Stairs].textures[0] = fill_textures(.Planks)
    block_textures[.Stairs].lock_uv_y[0] = fill_lock_uv_y(true)
    
    block_textures[.Piston].textures[0] = fill_textures(.Piston_Side)
    block_textures[.Piston].textures[0][.Top] = .Piston_Inner
    block_textures[.Piston].textures[0][.Bottom] = .Piston_Bottom
    
    block_textures[.Piston].textures[1] = fill_textures(.Piston_Side)
    block_textures[.Piston].uv_rects[1] = fill_uv_rects(pixel_uv(0, 0, 16, 4))
    block_textures[.Piston].uv_rotations[1] = fill_uv_rotations(.Deg_90_CCW)

    block_textures[.Piston].textures[2] = fill_textures(.Piston_Side)
    block_textures[.Piston].textures[2][.Top] = .Piston_Top
    block_textures[.Piston].textures[2][.Bottom] = .Piston_Top
}