package voxel_game
import rl "vendor:raylib"
import "core:fmt"

//RENDER
Block_Model_Data :: struct {
    model: rl.Model,
    visual_bbox: rl.BoundingBox,
    collision_bboxes: []rl.BoundingBox,
    center: Vec3,
}
block_models: [Block_Type]Block_Model_Data
redstone_render_texture: [(1<<len(Cardinal))*2]rl.RenderTexture2D

Block_Type :: enum {
    Air, Dirt, Stone, Cobblestone, Glass, Planks,
    Redstone, Slab, Stairs, Piston
}

Block_Info :: struct {
    flags: bit_set[Block_Flag],
    item: Maybe(Item_Type),
    textures: [MAX_TEXTURE_GROUPS][Block_Face]Texture_Type,
    uv_rotations: [MAX_TEXTURE_GROUPS][Block_Face]UV_Rotation,
    uv_rects: [MAX_TEXTURE_GROUPS][Block_Face]UV_Rect,
    model: Block_Model,
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
Block_Flag :: enum {
    TEXTURE_TRANSPARENT,
    STATEFUL,
    NO_COLLISION,
    HAS_CARDINAL,
    HAS_BLOCK_FACE,
}
MAX_TEXTURE_GROUPS :: 4
Block_Model :: enum {Cube, Slab, Decal, Stairs, Piston}
block_infos := [Block_Type]Block_Info {
    .Air = {
        flags = {},
    },
    .Dirt = {
        flags = {},
        item = .Dirt,
        model = .Cube,
    },
    .Stone = {
        flags = {},
        item = .Stone,
        model = .Cube,
    },
    .Cobblestone = {
        flags = {},
        item = .Cobblestone,
        model = .Cube,
    },
    .Glass = {
        flags = {.TEXTURE_TRANSPARENT},
        item = .Glass,
        model = .Cube,
    },
    .Planks = {
        flags = {},
        item = .Planks,
        model = .Cube,
    },
    .Redstone = {
        flags = {.TEXTURE_TRANSPARENT, .STATEFUL, .NO_COLLISION},
        item = .Redstone,
        model = .Decal,
    },
    .Slab = {
        flags = {.HAS_BLOCK_FACE},
        item = .Slab,
        model = .Slab,
    },
    .Stairs = {
        flags = {.HAS_BLOCK_FACE, .HAS_CARDINAL},
        item = .Stairs,
        model = .Stairs,
    },
    .Piston = {
        flags = {.HAS_BLOCK_FACE},
        item = .Piston,
        model = .Piston,
    }
}

fill_textures :: proc(tex: Texture_Type) -> [Block_Face]Texture_Type {
    return {.Top = tex, .Bottom = tex, .North = tex, .South = tex, .East = tex, .West = tex}
}

fill_uv_rects :: proc(rect: UV_Rect) -> [Block_Face]UV_Rect {
    return {.Top = rect, .Bottom = rect, .North = rect, .South = rect, .East = rect, .West = rect}
}

fill_uv_rotations :: proc(rot: UV_Rotation) -> [Block_Face]UV_Rotation {
    return {.Top = rot, .Bottom = rot, .North = rot, .South = rot, .East = rot, .West = rot}
}

// Converts a pixel region (0-16) to normalized 0.0-1.0 UV mapping coordinates.
// Perfect for accurately mapping subsets of textures to block geometry!
pixel_uv :: proc(x, y, w, h: f32) -> UV_Rect {
    return {{x / 16.0, y / 16.0}, {w / 16.0, h / 16.0}}
}

init_block_infos :: proc() {
    block_infos[.Dirt].textures[0] = fill_textures(.Dirt)
    
    block_infos[.Stone].textures[0] = fill_textures(.Stone)
    
    block_infos[.Cobblestone].textures[0] = fill_textures(.Cobblestone)
    
    block_infos[.Glass].textures[0] = fill_textures(.Glass)
    
    block_infos[.Planks].textures[0] = fill_textures(.Planks)
    
    block_infos[.Slab].textures[0] = fill_textures(.Slab_Side)
    block_infos[.Slab].textures[0][.Top] = .Slab_Top
    block_infos[.Slab].textures[0][.Bottom] = .Slab_Top
    
    block_infos[.Stairs].textures[0] = fill_textures(.Planks)
    
    block_infos[.Piston].textures[0] = fill_textures(.Piston_Side)
    block_infos[.Piston].textures[0][.Top] = .Piston_Inner
    block_infos[.Piston].textures[0][.Bottom] = .Piston_Bottom
    
    block_infos[.Piston].textures[1] = fill_textures(.Piston_Side)
    block_infos[.Piston].uv_rects[1] = fill_uv_rects(pixel_uv(0, 0, 16, 4))
    block_infos[.Piston].uv_rotations[1] = fill_uv_rotations(.Deg_90_CCW)

    block_infos[.Piston].textures[2] = fill_textures(.Piston_Side)
    block_infos[.Piston].textures[2][.Top] = .Piston_Top
    block_infos[.Piston].textures[2][.Bottom] = .Piston_Top
}

block_init :: proc() {
    init_block_infos()
    init_models()
}
//TODO unload textures

// Returns the base model for a block type (no transform applied)
get_base_model :: proc(block: Block) -> rl.Model {
    return block_models[block.type].model
}

// Returns the base bounding box for a block type (unrotated, local space)
get_base_bbox :: proc(block: Block) -> rl.BoundingBox {
    return block_models[block.type].visual_bbox
}

// Returns the model with the correct rotation transform applied.
// Caller should restore model.transform after drawing if needed.
get_block_model :: proc(block: Block) -> rl.Model {
    model := get_base_model(block)
    rot_mat := get_block_transform(block)
    model.transform = model.transform * rot_mat
    return model
}

// Returns the visual center of the block in local space (accounting for rotation)
get_block_center :: proc(block: Block) -> rl.Vector3 {
    if block.type == .Air do return {0.5, 0.5, 0.5}
    base_center := block_models[block.type].center
    rot_mat := get_block_transform(block)
    return rl.Vector3Transform(base_center, rot_mat)
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

// Returns 1 or more bboxes for a block in local space (relative to block origin).
// Caller must pass a buffer of at least max_collisions to hold results.
// Returns the slice of filled bboxes.
get_block_bboxes :: proc(block: Block, buf: ^[8]rl.BoundingBox) -> []rl.BoundingBox {
    model_data := block_models[block.type]
    rot := get_block_transform(block)
    for bbox, i in model_data.collision_bboxes {
        buf[i] = rotate_bbox(bbox, rot)
    }
    return buf[:len(model_data.collision_bboxes)]
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

wire_use :: proc() {
    if !state.looking_at_block do return
    if pos, ok := state.select_block_pos.([3]i32); ok {
        block := world_get_block(pos)
        block.data.arrow = Arrow{state.look_target}
        world_set_block(pos, block)
        state.select_block_pos = nil
    }
    else {
        state.select_block_pos = state.look_target
    }
}

block_place :: proc() {
    if state.held_item == nil do return
    block_type, ok := items[state.held_item.?].block.?
    if !ok do return
    block := Block{type=block_type}
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