package voxel_game
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"
import "core:fmt"

//RENDER
block_model: rl.Model
slab_model: rl.Model
decal_model: rl.Model
stairs_model: rl.Model
block_model_bbox: rl.BoundingBox
slab_model_bbox: rl.BoundingBox
decal_model_bbox: rl.BoundingBox
stairs_model_bbox: rl.BoundingBox
redstone_render_texture: [(1<<len(Cardinal))*2]rl.RenderTexture2D

Block_Type :: enum {
    Air, Dirt, Stone, Cobblestone, Glass, Planks,
    Redstone, Slab, Stairs,
}

Block_Info :: struct {
    flags: bit_set[Block_Flag],
    textures: [Block_Face]Block_Texture_Type,
    model: Block_Model
}
Block_Flag :: enum {
    TEXTURE_TRANSPARENT,
    STATEFUL,
    NO_COLLISION,
    HAS_CARDINAL,
    HAS_BLOCK_FACE,
}
Block_Model :: enum {Cube, Slab, Decal, Stairs}
block_infos := [Block_Type]Block_Info {
    .Air = {
        flags = {},
    },
    .Dirt = {
        flags = {},
        model = .Cube,
    },
    .Stone = {
        flags = {},
        model = .Cube,
    },
    .Cobblestone = {
        flags = {},
        model = .Cube,
    },
    .Glass = {
        flags = {.TEXTURE_TRANSPARENT},
        model = .Cube,
    },
    .Planks = {
        flags = {},
        model = .Cube,
    },
    .Redstone = {
        flags = {.TEXTURE_TRANSPARENT, .STATEFUL, .NO_COLLISION},
        model = .Decal,
    },
    .Slab = {
        flags = {.HAS_BLOCK_FACE},
        model = .Slab,
    },
    .Stairs = {
        flags = {.HAS_BLOCK_FACE, .HAS_CARDINAL},
        model = .Stairs,
    },
}

fill_textures :: proc(tex: Block_Texture_Type) -> [Block_Face]Block_Texture_Type {
    return {.Top = tex, .Bottom = tex, .North = tex, .South = tex, .East = tex, .West = tex}
}

init_block_infos :: proc() {
    block_infos[.Dirt].textures = fill_textures(.Dirt)
    
    block_infos[.Stone].textures = fill_textures(.Stone)
    block_infos[.Stone].textures[.Bottom] = .Dirt
    
    block_infos[.Cobblestone].textures = fill_textures(.Cobblestone)
    
    block_infos[.Glass].textures = fill_textures(.Glass)
    
    block_infos[.Planks].textures = fill_textures(.Planks)
    
    block_infos[.Slab].textures = fill_textures(.Slab_Side)
    block_infos[.Slab].textures[.Top] = .Slab_Top
    block_infos[.Slab].textures[.Bottom] = .Slab_Top
    
    block_infos[.Stairs].textures = fill_textures(.Planks)
}

block_init :: proc() {
    init_shaders()
    init_block_infos()
    init_block_model()
    init_slab_model()
    init_decal_model()
    init_stairs_model()
    init_textures()
}
//TODO unload textures

// Returns the base model for a block type (no transform applied)
get_base_model :: proc(block: Block) -> rl.Model {
    info := block_infos[block.type]
    switch info.model {
    case .Slab:   return slab_model
    case .Decal:  return decal_model
    case .Cube:   return block_model
    case .Stairs: return stairs_model
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
    case .Stairs: return stairs_model_bbox
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

// Rotates a local-space AABB through a matrix and returns the new AABB.
rotate_bbox :: proc(base: rl.BoundingBox, rot: rl.Matrix) -> rl.BoundingBox {
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
    new_min := rl.Vector3Transform(corners[0], rot)
    new_max := new_min
    for i in 1..<8 {
        t := rl.Vector3Transform(corners[i], rot)
        new_min.x = min(new_min.x, t.x); new_max.x = max(new_max.x, t.x)
        new_min.y = min(new_min.y, t.y); new_max.y = max(new_max.y, t.y)
        new_min.z = min(new_min.z, t.z); new_max.z = max(new_max.z, t.z)
    }
    return rl.BoundingBox{new_min, new_max}
}

// Returns 1 or 2 bboxes for a block in local space (relative to block origin).
// Caller must pass a buffer of at least 2 to hold results.
// Returns the slice of filled bboxes.
get_block_bboxes :: proc(block: Block, buf: ^[2]rl.BoundingBox) -> []rl.BoundingBox {
    if block.type == .Stairs {
        rot := get_block_transform(block)
        // Bottom step: full width/depth, lower half
        bottom := rl.BoundingBox{min={-0.5,-0.5,-0.5}, max={0.5, 0.0, 0.5}}
        // Top step: full width, back half, upper half (south-facing default)
        top    := rl.BoundingBox{min={-0.5, 0.0,-0.5}, max={0.5, 0.5, 0.0}}
        buf[0] = rotate_bbox(bottom, rot)
        buf[1] = rotate_bbox(top, rot)
        return buf[:]
    }
    buf[0] = get_block_bbox(block)
    return buf[:1]
}

//GAMEPLAY
Block :: struct {
    type: Block_Type,
    data: Block_Data,
}
Block_Data :: struct {
    direction: Cardinal,
    facing: Block_Face,
    arrow: Maybe(Arrow),
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
Arrow :: struct {
    to: [3]i32
}

block_place :: proc() {
    block := state.held_block
    fmt.println(state.place_dir)
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
    }
    if .HAS_BLOCK_FACE in info.flags {
        block.data.facing = state.hit_face
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