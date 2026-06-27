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
        flags = {},
        texture = BlockT_Cube{path="assets/dirt.png"},
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
        flags = {.HAS_BLOCK_FACE},
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

// Returns the base model for a block type (no transform applied)
get_base_model :: proc(block: Block) -> rl.Model {
    info := block_infos[block.type]
    switch info.model {
    case .Slab:   return slab_model
    case .Decal:  return decal_model
    case .Cube:   return block_model
    }
    return block_model
}

// Returns the base bounding box for a block type (unrotated, local space)
get_base_bbox :: proc(block: Block) -> rl.BoundingBox {
    info := block_infos[block.type]
    switch info.model {
    case .Slab:   return slab_model_bbox
    case .Decal:  return decal_model_bbox
    case .Cube:   return block_model_bbox
    }
    return block_model_bbox
}

// Returns the model with the correct rotation transform applied.
// Caller should restore model.transform after drawing if needed.
get_block_model :: proc(block: Block) -> rl.Model {
    model := get_base_model(block)
    rot_mat := get_block_transform(block)
    model.transform = model.transform * rot_mat
    return model
}

// Returns an axis-aligned bounding box for the block in local space,
// accounting for rotation. Safe to add block_pos to get world-space AABB.
get_block_bbox :: proc(block: Block) -> rl.BoundingBox {
    base := get_base_bbox(block)
    rot_mat := get_block_transform(block)

    // Transform all 8 corners of the base AABB through the rotation matrix
    // and compute a new AABB that encloses all of them.
    corners := [8]Vec3{
        {base.min.x, base.min.y, base.min.z},
        {base.max.x, base.min.y, base.min.z},
        {base.min.x, base.max.y, base.min.z},
        {base.max.x, base.max.y, base.min.z},
        {base.min.x, base.min.y, base.max.z},
        {base.max.x, base.min.y, base.max.z},
        {base.min.x, base.max.y, base.max.z},
        {base.max.x, base.max.y, base.max.z},
    }

    new_min := rl.Vector3Transform(corners[0], rot_mat)
    new_max := new_min
    for i in 1..<8 {
        t := rl.Vector3Transform(corners[i], rot_mat)
        new_min.x = min(new_min.x, t.x)
        new_min.y = min(new_min.y, t.y)
        new_min.z = min(new_min.z, t.z)
        new_max.x = max(new_max.x, t.x)
        new_max.y = max(new_max.y, t.y)
        new_max.z = max(new_max.z, t.z)
    }
    return rl.BoundingBox{new_min, new_max}
}

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
    block := state.held_block
    if is_overlapping(state.cam.position, state.place_target, block) do return
    if world_get_block(state.place_target).type != .Air do return
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
        block.data.direction = state.place_dir
        fmt.println("direction:", block.data.direction)
    }
    if .HAS_BLOCK_FACE in info.flags {
        block.data.facing = state.hit_face
        fmt.println("facing:", block.data.facing)
    }
    world_set_block(state.place_target, block)
}
place_redstone :: proc() {
    pos1 := state.place_pos
    pos2 := pos1 + state.place_dir_normal
    pos1_i := state.place_target
    pos2_i := from_vec3(pos2)
    dir1 := state.place_dir
    dir2 := normal_to_direction(-state.place_dir_normal_2d)

    redstone := Block{.Redstone, {redstone={true, state.hit_face, {}}}}
    redstone.data.redstone.connections[dir1] = true
    world_set_block(pos1_i, redstone)

    redstone2 := Block{.Redstone, {redstone={true, state.hit_face, {}}}}
    redstone2.data.redstone.connections[dir2] = true
    world_set_block(pos2_i, redstone2)
}