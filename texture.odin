package voxel_game
import rl "vendor:raylib"

Texture_Type :: enum {
    //Blocks
    Dirt, Stone, Cobblestone, Glass, Planks,
    Slab_Side, Slab_Top,
    Piston_Side, Piston_Top, Piston_Bottom, Piston_Inner,
    Torch_On, Torch_Off, Lever,
    //Items
    Wire, Copper_Wire
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
    .Torch_On = "assets/torch.png",
    .Torch_Off = "assets/torch_off.png",
    .Lever = "assets/lever.png",
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
pixel_uv :: proc(rect: UV_Rect) -> UV_Rect {
    return {{rect.pos.x / 16.0, rect.pos.y / 16.0}, {rect.size.x / 16.0, rect.size.y / 16.0}}
}

init_block_textures :: proc() {
    for &info, block in block_infos {
        texture := &info.texture
        switch block {
        case .Air:
        case .Dirt:
            texture.textures[0] = fill_textures(.Dirt)
        case .Stone:
            texture.textures[0] = fill_textures(.Stone)
        case .Cobblestone:
            texture.textures[0] = fill_textures(.Cobblestone)
        case .Glass:
            texture.textures[0] = fill_textures(.Glass)
        case .Planks:
            texture.textures[0] = fill_textures(.Planks)
        case .Slab:
            texture.textures[0] = fill_textures(.Slab_Side)
            texture.textures[0][.Top] = .Slab_Top
            texture.textures[0][.Bottom] = .Slab_Top
        case .Stairs:
            texture.textures[0] = fill_textures(.Planks)
            texture.lock_uv_y[0] = fill_lock_uv_y(true)
        case .Piston:
            texture.textures[0] = fill_textures(.Piston_Side)
            texture.textures[0][.Top] = .Piston_Inner
            texture.textures[0][.Bottom] = .Piston_Bottom
            
            texture.textures[1] = fill_textures(.Piston_Side)
            texture.uv_rects[1] = fill_uv_rects(pixel_uv({{0, 0}, {16, 4}}))
            texture.uv_rotations[1] = fill_uv_rotations(.Deg_90_CCW)

            texture.textures[2] = fill_textures(.Piston_Side)
            texture.textures[2][.Top] = .Piston_Top
            texture.textures[2][.Bottom] = .Piston_Top
        case .Button:
            texture.textures[0] = fill_textures(.Stone)
            texture.lock_uv_y[0] = fill_lock_uv_y(true)

        case .Torch:
            // Group 0: Main Stick
            texture.textures[0] = fill_textures(.Torch_On)
            texture.uv_rects[0] = fill_uv_rects(pixel_uv({{7, 6}, {2, 10}}))
            texture.uv_rects[0][.Top] = pixel_uv({{7, 6}, {2, 2}})
            texture.uv_rects[0][.Bottom] = pixel_uv({{7, 14}, {2, 2}})
            
            // Group 1: Inverted Flame Head
            texture.textures[1] = fill_textures(.Torch_On)
            texture.uv_rects[1] = fill_uv_rects(pixel_uv({{6, 5}, {1, 1}}))
        case .Lever:
            // Group 0: Cobblestone base
            texture.textures[0] = fill_textures(.Cobblestone)
            //texture.lock_uv_y[0] = fill_lock_uv_y(true)
            // Group 1: Lever Stick
            texture.textures[1] = fill_textures(.Lever)
            texture.uv_rects[1] = fill_uv_rects(pixel_uv({{7, 6}, {2, 10}}))
            texture.uv_rects[1][.Top] = pixel_uv({{7, 6}, {2, 2}})
        }
    }
}