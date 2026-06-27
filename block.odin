package voxel_game
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"
import "core:fmt"

//RENDER
block_model: rl.Model
slab_model: rl.Model
decal_model: rl.Model
block_model_bbox: rl.BoundingBox
slab_model_bbox: rl.BoundingBox
decal_model_bbox: rl.BoundingBox
redstone_render_texture: [(1<<len(Cardinal))*2]rl.RenderTexture2D

Block_Type :: enum {
    Air, Dirt, Stone, Cobblestone, Glass, Planks,
    Redstone, Slab,
}

Block_Info :: struct {
    flags: bit_set[Block_Flag],
    texture: Block_Texture,
    model: Block_Model
}
Block_Flag :: enum {
    TEXTURE_TRANSPARENT,
    STATEFUL,
    NO_COLLISION,
    HAS_CARDINAL,
    HAS_BLOCK_FACE,
}
Block_Texture :: union {BlockT_Cube, BlockT_Double}
BlockT_Cube :: struct {
    path: cstring,
    tex: rl.Texture2D,
}
BlockT_Double :: struct {
    path_side, path_cap: cstring,
    side, top: rl.Texture2D,
}
Block_Model :: enum {Cube, Slab, Decal}
block_infos := [Block_Type]Block_Info {
    .Air = {
        flags = {},
    },
    .Dirt = {
        flags = {.HAS_CARDINAL, .HAS_BLOCK_FACE},
        texture = BlockT_Cube{path="assets/test.png"},
        model = .Cube,
    },
    .Stone = {
        flags = {},
        texture = BlockT_Cube{path="assets/stone.png"},
        model = .Cube,
    },
    .Cobblestone = {
        flags = {},
        texture = BlockT_Cube{path="assets/cobblestone.png"},
        model = .Cube,
    },
    .Glass = {
        flags = {.TEXTURE_TRANSPARENT},
        texture = BlockT_Cube{path="assets/glass.png"},
        model = .Cube,
    },
    .Planks = {
        flags = {},
        texture = BlockT_Cube{path="assets/planks.png"},
        model = .Cube,
    },
    .Redstone = {
        flags = {.TEXTURE_TRANSPARENT, .STATEFUL, .NO_COLLISION},
        model = .Decal,
    },
    .Slab = {
        flags = {.HAS_BLOCK_FACE, .HAS_CARDINAL},
        texture = BlockT_Double{path_side="assets/slab_side.png", path_cap="assets/slab_top.png"},
        model = .Slab,
    }
}

block_init :: proc() {
    init_block_model()
    init_slab_model()
    init_decal_model()
    for &info in block_infos {
        if texture, ok := &info.texture.(BlockT_Cube); ok {
            texture.tex = rl.LoadTexture(texture.path)
        } else if texture, ok := &info.texture.(BlockT_Double); ok {
            texture.side = rl.LoadTexture(texture.path_side)
            texture.top = rl.LoadTexture(texture.path_cap)
        }
    }
}
//TODO unload textures

//GAMEPLAY
Block :: struct {
    type: Block_Type,
    data: Block_Data,
}
Block_Data :: struct {
    direction: Cardinal,
    facing: Block_Face,
    using uniqe: Block_Data_Uniqe,
}
Block_Data_Uniqe :: struct #raw_union {
    redstone: Redstone,
}
Redstone :: struct {
    on: bool,
    rotation: Block_Face,
    connections: [Cardinal]bool,
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
    block := block
    info := block_infos[block.type]
    if .HAS_CARDINAL in info.flags {
        block.data.direction = state.place_block_direction
        fmt.println("direction:", block.data.direction)
    }
    if .HAS_BLOCK_FACE in info.flags {
        block.data.facing = state.place_block_face
        fmt.println("facing:", block.data.facing)
    }
    world_set_block(state.place_block_index, block)
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
    world_set_block(pos1_i, redstone)

    redstone2 := Block{.Redstone, {redstone={true, state.place_block_face, {}}}}
    redstone2.data.redstone.connections[dir2] = true
    world_set_block(pos2_i, redstone2)
}