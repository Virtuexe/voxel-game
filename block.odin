package voxel_game
import rl "vendor:raylib"
import "core:fmt"

//RENDER
Block_Model_Data :: struct {
    model: rl.Model,
    visual_bbox: rl.BoundingBox,
    collision_bboxes: []rl.BoundingBox,
    center: Vec3,
    base_facing: Block_Face,
}
block_models: [Block_Type]Block_Model_Data
redstone_render_texture: [(1<<len(Cardinal))*2]rl.RenderTexture2D

Block_Type :: enum {
    Air, Dirt, Stone, Cobblestone, Glass, Planks,
    Redstone, Slab, Stairs, Piston, Button,
}

Block_Info :: struct {
    flags: bit_set[Block_Flag],
    item: Maybe(Item_Type),
    model: Block_Model,
    texture: Block_Texture,
    on_right_click: Maybe(proc(pos: [3]i32)),
    on_activate: Maybe(proc(pos: [3]i32))
}
Block_Flag :: enum {
    TEXTURE_TRANSPARENT,
    STATEFUL,
    NO_COLLISION,
    HAS_CARDINAL,
    HAS_BLOCK_FACE,
    WIRE_INPUT,
    WIRE_OUTPUT,
}
Block_Model :: enum {Cube, Slab, Decal, Stairs, Piston, Button}
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
        flags = {.TEXTURE_TRANSPARENT, .WIRE_INPUT, .WIRE_OUTPUT},
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
        flags = {.HAS_BLOCK_FACE, .WIRE_OUTPUT},
        item = .Piston,
        model = .Piston,
        on_activate = piston_activate
    },
    .Button = {
        flags = {.HAS_BLOCK_FACE, .WIRE_INPUT},
        item = .Button,
        model = .Button,
        on_right_click = activate_wired_blocks
    }
}



block_init :: proc() {
    init_block_textures()
    init_models()
}
//TODO unload textures

//runs activate function of all block
activate_wired_blocks :: proc(pos: [3]i32) {
    block := world_get_block(pos)
    if !block.data.has_wires do return
    
    if wires, ok := state.world.wires[pos]; ok {
        for wire in wires {
            target_pos := wire.to
            target_block := world_get_block(target_pos)
            info := block_infos[target_block.type]
            if info.on_activate != nil {
                info.on_activate.?(target_pos)
            }
        }
    }
}
//will push block that is facing to, if Air will instead pull block to piston if also Air do nothing
piston_activate :: proc(pos: [3]i32) {
    piston_block := world_get_block(pos)
    if piston_block.type != .Piston do return
    
    normal := face_to_normal(piston_block.data.facing)
    dir := [3]i32{i32(normal.x), i32(normal.y), i32(normal.z)}
    
    target_pos := pos + dir
    target_block := world_get_block(target_pos)
    
    if target_block.type != .Air {
        next_pos := target_pos + dir
        next_block := world_get_block(next_pos)
        if next_block.type == .Air {
            world_set_block(next_pos, target_block)
            world_set_block(target_pos, Block{.Air, {}})
        }
    } else {
        next_pos := target_pos + dir
        next_block := world_get_block(next_pos)
        if next_block.type != .Air {
            world_set_block(target_pos, next_block)
            world_set_block(next_pos, Block{.Air, {}})
        }
    }
}

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
    has_wires: bool,
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
Wire :: struct {
    to: [3]i32
}

//rework, should be in item.odin
place_base_block :: proc(block: Block) {
    block := block
    info := block_infos[block.type]
    has_cardinal := .HAS_CARDINAL in info.flags
    has_block_face := .HAS_BLOCK_FACE in info.flags

    if has_cardinal && has_block_face {
        block.data.direction = state.place_yaw_dir
        block.data.facing = state.place_half
    } else if has_cardinal {
        block.data.direction = state.place_yaw_dir
    } else if has_block_face {
        block.data.facing = state.place_pitch_face
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