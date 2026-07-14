package voxel_game

import rl "vendor:raylib"
import "core:slice"

Block_Geometry :: struct {
    positions: [MAX_TEXTURE_GROUPS * 6][]Vec3,
    normals:   [MAX_TEXTURE_GROUPS * 6][]Vec3,
    texcoords: [MAX_TEXTURE_GROUPS * 6][]Vec2,
    indices:   [MAX_TEXTURE_GROUPS * 6][]u16,
}

Block_Part :: struct {
    group_id: int,
    collision_bboxes: []rl.BoundingBox,
    visual_bbox: rl.BoundingBox,
}

Block_Model_Data :: struct {
    models: [2]rl.Model, // [0 = is_on=false, 1 = is_on=true]
    parts: [2][]Block_Part, // [0 = is_on=false, 1 = is_on=true]
    center: Vec3,
    base_facing: Block_Face,
    geometries: [2][64]Block_Geometry,
    t_types: [2][MAX_TEXTURE_GROUPS * 6]Texture_Type,
}
block_models: [Block_Type]Block_Model_Data

Block_Model :: enum {Cube, Slab, Decal, Stairs, Piston, Button, Torch, Lever,}

init_models :: proc() {
    img := rl.GenImageColor(1, 1, rl.WHITE)
    white_texture = rl.LoadTextureFromImage(img)
    rl.UnloadImage(img)

    for type in Block_Type {
        if type == .Air do continue
        
        info := block_infos[type]
        tex_info := block_infos[type].texture
        
        data: Block_Model_Data
        
        for is_on_idx in 0..<2 {
            is_on := is_on_idx == 1
            block := Block{type = type, is_on = is_on}
            
            // Build base visual model for this state
            b := builder_init()
            facing := build_block_geometry(&b, block)
            model := builder_build(&b, facing)
            
            if is_on_idx == 0 {
                data.center = b.center
                data.base_facing = facing
            }
            
            // Resolve texture types for this state and apply textures
            for group in 0..<MAX_TEXTURE_GROUPS {
                for face in Block_Face {
                    idx := group * 6 + int(face)
                    t_type := tex_info.textures[group][face]
                    if block.type == .Torch && t_type == .Torch_On && !block.is_on {
                        t_type = .Torch_Off
                    }
                    data.t_types[is_on_idx][idx] = t_type
                    
                    t := textures[t_type]
                    rl.SetMaterialTexture(&model.materials[idx], .ALBEDO, t)
                }
            }
            
            data.models[is_on_idx] = model
            builder_destroy(&b)
            
            // Build parts (collision and visual hitboxes)
            b_parts := builder_init()
            build_block_geometry(&b_parts, block)
            
            parts: [dynamic]Block_Part
            for i in 0..<MAX_TEXTURE_GROUPS {
                if len(b_parts.collision_bboxes[i]) > 0 || len(b_parts.positions[i*6]) > 0 {
                    v_bbox := builder_get_visual_bbox(&b_parts, i)
                    append(&parts, Block_Part{
                        group_id = i,
                        collision_bboxes = slice.clone(b_parts.collision_bboxes[i][:]),
                        visual_bbox = v_bbox,
                    })
                }
            }
            data.parts[is_on_idx] = parts[:]
            builder_destroy(&b_parts)
            
            // Build and cache all 64 chunk meshing combinations
            for mask in 0..<64 {
                exc_faces := transmute(bit_set[Block_Face])u8(mask)
                b_geom := builder_init()
                build_block_geometry(&b_geom, block, exc_faces)
                
                geom: Block_Geometry
                for group_face in 0..<MAX_TEXTURE_GROUPS * 6 {
                    if len(b_geom.positions[group_face]) > 0 {
                        geom.positions[group_face] = slice.clone(b_geom.positions[group_face][:])
                        geom.normals[group_face] = slice.clone(b_geom.normals[group_face][:])
                        geom.texcoords[group_face] = slice.clone(b_geom.texcoords[group_face][:])
                        geom.indices[group_face] = slice.clone(b_geom.indices[group_face][:])
                    }
                }
                data.geometries[is_on_idx][mask] = geom
                builder_destroy(&b_geom)
            }
        }
        
        block_models[type] = data
    }
}

// Returns the base model for a block type (no transform applied)
get_base_model :: proc(block: Block) -> rl.Model {
    return block_models[block.type].models[block.is_on ? 1 : 0]
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
// accounting for rotation and part animations.
get_block_bbox :: proc(block: Block, pos: Vec3I) -> rl.BoundingBox {
    model_data := block_models[block.type]
    rot_mat := get_block_transform(block)
    
    animator := animator_init()
    if id, ok := world_get_tracker_id(pos); ok {
        if anims, ok := state.world.animations[id]; ok {
            for i in 0..<anims.count {
                anim := anims.list[i]
                info := animation_infos[anim.type]
                info.proc_(anim, &animator)
            }
        }
    }
    new_min := rl.Vector3{99999, 99999, 99999}
    new_max := rl.Vector3{-99999, -99999, -99999}
    has_parts := false

    for part in model_data.parts[block.is_on ? 1 : 0] {
        has_parts = true
        local_trans := animator.local_transforms[part.group_id]
        global_trans := animator.global_transforms[part.group_id]
        final_mat := global_trans * rot_mat * local_trans
        t_box := rotate_bbox(part.visual_bbox, final_mat)
        
        new_min.x = min(new_min.x, t_box.min.x)
        new_min.y = min(new_min.y, t_box.min.y)
        new_min.z = min(new_min.z, t_box.min.z)
        new_max.x = max(new_max.x, t_box.max.x)
        new_max.y = max(new_max.y, t_box.max.y)
        new_max.z = max(new_max.z, t_box.max.z)
    }
    
    if !has_parts do return rl.BoundingBox{}
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
get_block_bboxes :: proc(block: Block, buf: ^[8]rl.BoundingBox, pos: Vec3I) -> []rl.BoundingBox {
    model_data := block_models[block.type]
    rot := get_block_transform(block)
    
    animator := animator_init()
    if id, ok := world_get_tracker_id(pos); ok {
        if anims, ok := state.world.animations[id]; ok {
            for i in 0..<anims.count {
                anim := anims.list[i]
                info := animation_infos[anim.type]
                info.proc_(anim, &animator)
            }
        }
    }
    count := 0
    for part in model_data.parts[block.is_on ? 1 : 0] {
        local_trans := animator.local_transforms[part.group_id]
        global_trans := animator.global_transforms[part.group_id]
        final_mat := global_trans * rot * local_trans
        
        for bbox in part.collision_bboxes {
            if count >= len(buf) do break
            buf[count] = rotate_bbox(bbox, final_mat)
            count += 1
        }
    }
    return buf[:count]
}
