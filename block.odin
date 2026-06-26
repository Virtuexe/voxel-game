package voxel_game
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

//RENDER
block_model: rl.Model
slab_model: rl.Model
decal_model: rl.Model
redstone_render_texture: [(1<<len(Direction))*2]rl.RenderTexture2D

Block_Type :: enum {
    Air, Dirt, Stone, Cobblestone, Glass, Planks,
    Redstone,
}

Block_Info :: struct {
    flags: bit_set[Block_Flag],
    texture: Block_Texture,
}
Block_Flag :: enum {
    TEXTURE_CUBE,
    TEXTURE_DECAL,
    TEXTURE_TRANSPARENT,
    STATEFUL,
}
Block_Texture :: union {BlockT_Cube, BlockT_Double}
BlockT_Cube :: struct {
    path: cstring,
    tex: rl.Texture2D,
}
BlockT_Double :: struct {
    path_side, path_cap: cstring,
    side, cap: rl.Texture2D,
}
block_infos := [Block_Type]Block_Info {
    .Air = {
        flags = {},
    },
    .Dirt = {
        flags = {.TEXTURE_CUBE},
        texture = BlockT_Cube{path="assets/dirt.png"},
    },
    .Stone = {
        flags = {.TEXTURE_CUBE},
        texture = BlockT_Cube{path="assets/stone.png"},
    },
    .Cobblestone = {
        flags = {.TEXTURE_CUBE},
        texture = BlockT_Cube{path="assets/cobblestone.png"},
    },
    .Glass = {
        flags = {.TEXTURE_CUBE, .TEXTURE_TRANSPARENT},
        texture = BlockT_Cube{path="assets/glass.png"}
    },
    .Planks = {
        flags = {.TEXTURE_CUBE},
        texture = BlockT_Cube{path="assets/planks.png"}
    },
    .Redstone = {
        flags = {.TEXTURE_DECAL, .TEXTURE_TRANSPARENT, .STATEFUL}
    }
}

block_init :: proc() {
    init_block_model()
    init_slab_model()
    init_decal_model()
    for &info in block_infos {
        if texture, ok := &info.texture.(BlockT_Cube); ok {
            texture.tex = rl.LoadTexture(texture.path)
        }
    }
}
//TODO unload textures

//GAMEPLAY
Block :: struct {
    type: Block_Type,
    data: Block_Data,
}
Block_Data :: struct #raw_union {
    redstone: Redstone,
}
Redstone :: struct {
    on: bool,
    rotation: Face,
    connections: [Direction]bool,
}

block_place :: proc() {
    block := state.block_in_hand
    if is_overlapping(state.cam.position, state.place_block_index, block) {
        return
    }
    #partial switch block.type {
    case .Redstone:
        place_redstone()
    case:
        place_base_block(block)
    }
    raycast()
}
place_base_block :: proc(block: Block) {
    world_set_block(state.place_block_index, palette_provide_block_key(block))
}
place_redstone :: proc() {
    pos1 := state.place_block
    pos2 := pos1 + state.place_block_direction_normal
    pos1_i := state.place_block_index
    pos2_i := from_vec3(pos2)
    dir1 := state.place_block_direction
    dir2 := normal_to_direction(-state.place_block_direction_normal_2d)

    redstone := Block{.Redstone, {redstone={true, state.place_block_face, {}}}}
    redstone.data.redstone.connections[dir1] = true
    world_set_block(pos1_i, palette_provide_block_key(redstone))

    redstone2 := Block{.Redstone, {redstone={true, state.place_block_face, {}}}}
    redstone2.data.redstone.connections[dir2] = true
    world_set_block(pos2_i, palette_provide_block_key(redstone2))
}