package voxel_game

import rl "vendor:raylib"
import "core:slice"
import "core:math/linalg"

Chunk_Mesher :: struct {
    positions: [Texture_Type][dynamic][3]f32,
    normals:   [Texture_Type][dynamic][3]f32,
    texcoords: [Texture_Type][dynamic][2]f32,
    indices:   [Texture_Type][dynamic]u16,
}

chunk_mesher_init :: proc() -> Chunk_Mesher {
    return Chunk_Mesher{}
}

chunk_mesher_destroy :: proc(m: ^Chunk_Mesher) {
    for t in Texture_Type {
        delete(m.positions[t])
        delete(m.normals[t])
        delete(m.texcoords[t])
        delete(m.indices[t])
    }
}

// Copy a mesh from block builder to the chunk builder, applying translation.
// It applies the vertices to the specified texture type.
chunk_mesher_add_model_parts :: proc(m: ^Chunk_Mesher, b: ^Block_Model_Builder, offset: [3]f32, transform: rl.Matrix, t_types: [MAX_TEXTURE_GROUPS * 6]Texture_Type, lock_uv: [MAX_TEXTURE_GROUPS][Block_Face]bool) {
    for group_face in 0..<MAX_TEXTURE_GROUPS * 6 {
        vcount := len(b.positions[group_face])
        if vcount == 0 do continue
        
        t_type := t_types[group_face]
        
        base_index := u16(len(m.positions[t_type]))
        
        for p in b.positions[group_face] {
            p_trans := rl.Vector3Transform(p, transform)
            append(&m.positions[t_type], p_trans + offset)
        }
        for n in b.normals[group_face] {
            // Apply rotation to normal
            p_trans := rl.Vector3Transform(n, transform)
            p_zero := rl.Vector3Transform({0, 0, 0}, transform)
            n_trans := p_trans - p_zero
            append(&m.normals[t_type], linalg.normalize0(n_trans))
        }
        for uv, j in b.texcoords[group_face] {
            group := group_face / 6
            face := Block_Face(group_face % 6)
            final_uv := uv
            
            if lock_uv[group][face] && (face == .Top || face == .Bottom) {
                p_trans := rl.Vector3Transform(b.positions[group_face][j], transform)
                world_p := p_trans + offset
                final_uv = {world_p.x, world_p.z}
            }
            append(&m.texcoords[t_type], final_uv)
        }
        for idx in b.indices[group_face] {
            append(&m.indices[t_type], base_index + idx)
        }
    }
}

chunk_build_mesh :: proc(chunk: ^Chunk, c_pos: Vec3I) {
    if chunk.has_model {
        rl.UnloadModel(chunk.model)
        chunk.has_model = false
    }
    
    m := chunk_mesher_init()
    defer chunk_mesher_destroy(&m)
    
    b := builder_init()
    defer builder_destroy(&b)
    
    clear(&chunk.dynamic_blocks)
    
    for block_key, i in chunk.block_keys {
        if block_key == 0 do continue
        block := chunk.palette[block_key]
        
        l_pos := unflatten(i)
        global_pos := get_global_pos(c_pos, l_pos)
        
        info := block_infos[block.type]
        tex_info := info.texture
        
        is_dynamic := false
        if .STATEFUL in info.flags do is_dynamic = true
        
        id, ok := world_get_tracker_id(global_pos)
        if ok && id in state.world.animations do is_dynamic = true
        
        if is_dynamic {
            append(&chunk.dynamic_blocks, i)
            continue
        }
        
        // Face Culling Check
        excluded_faces: bit_set[Block_Face] = {}
        if block.type == .Air do continue // Should not happen based on block_key
        
        if info.model == .Cube {
            neighbors := [Block_Face]Vec3I{
                .Top = {0, 1, 0},
                .Bottom = {0, -1, 0},
                .South = {0, 0, 1},
                .North = {0, 0, -1},
                .East = {1, 0, 0},
                .West = {-1, 0, 0},
            }
            
            for offset, face in neighbors {
                n_pos := global_pos + offset
                n_block := world_get_block(n_pos)
                if n_block.type != .Air {
                    n_info := block_infos[n_block.type]
                    if !(.TEXTURE_TRANSPARENT in n_info.flags) && n_info.model == .Cube {
                        excluded_faces += {Block_Face(face)}
                    }
                }
            }
        }
        
        // Generate geometry in the generic builder
        builder_clear(&b)
        build_block_geometry(&b, block, excluded_faces)
        
        // Resolve Texture Types for each material group/face
        t_types: [MAX_TEXTURE_GROUPS * 6]Texture_Type
        for group in 0..<MAX_TEXTURE_GROUPS {
            for face in Block_Face {
                idx := group * 6 + int(face)
                t_types[idx] = tex_info.textures[group][face]
            }
        }
        
        rot_mat := get_block_transform(block)
        
        // Append generated geometry to the chunk mesher grouped by Texture_Type
        chunk_mesher_add_model_parts(&m, &b, to_vec3(l_pos), rot_mat, t_types, tex_info.lock_uv_y)
    }
    
    active_mesh_count := 0
    for t in Texture_Type {
        if len(m.positions[t]) > 0 do active_mesh_count += 1
    }
    
    if active_mesh_count == 0 {
        chunk.is_dirty = false
        return
    }
    
    model: rl.Model
    model.meshCount = i32(active_mesh_count)
    model.materialCount = i32(active_mesh_count)
    model.meshes = cast([^]rl.Mesh)rl.MemAlloc(u32(active_mesh_count) * size_of(rl.Mesh))
    model.materials = cast([^]rl.Material)rl.MemAlloc(u32(active_mesh_count) * size_of(rl.Material))
    model.meshMaterial = cast([^]i32)rl.MemAlloc(u32(active_mesh_count) * size_of(i32))
    
    model.transform = rl.Matrix(1)
    
    m_idx := 0
    for t in Texture_Type {
        vcount := len(m.positions[t])
        if vcount == 0 do continue
        
        mesh := &model.meshes[m_idx]
        tcount := len(m.indices[t]) / 3
        mesh.vertexCount = i32(vcount)
        mesh.triangleCount = i32(tcount)
        
        mesh.vertices = cast([^]f32)rl.MemAlloc(u32(vcount * 3 * size_of(f32)))
        mesh.normals = cast([^]f32)rl.MemAlloc(u32(vcount * 3 * size_of(f32)))
        mesh.texcoords = cast([^]f32)rl.MemAlloc(u32(vcount * 2 * size_of(f32)))
        mesh.indices = cast([^]u16)rl.MemAlloc(u32(tcount * 3 * size_of(u16)))
        
        for v, j in m.positions[t] {
            (cast([^]f32)mesh.vertices)[j * 3 + 0] = v.x
            (cast([^]f32)mesh.vertices)[j * 3 + 1] = v.y
            (cast([^]f32)mesh.vertices)[j * 3 + 2] = v.z
        }
        for n, j in m.normals[t] {
            (cast([^]f32)mesh.normals)[j * 3 + 0] = n.x
            (cast([^]f32)mesh.normals)[j * 3 + 1] = n.y
            (cast([^]f32)mesh.normals)[j * 3 + 2] = n.z
        }
        for uv, j in m.texcoords[t] {
            (cast([^]f32)mesh.texcoords)[j * 2 + 0] = uv.x
            (cast([^]f32)mesh.texcoords)[j * 2 + 1] = uv.y
        }
        for idx, j in m.indices[t] {
            (cast([^]u16)mesh.indices)[j] = idx
        }
        
        rl.UploadMesh(mesh, false)
        
        model.materials[m_idx] = rl.LoadMaterialDefault()
        model.materials[m_idx].shader = block_shader
        rl.SetMaterialTexture(&model.materials[m_idx], .ALBEDO, textures[t])
        model.meshMaterial[m_idx] = i32(m_idx)
        
        m_idx += 1
    }
    
    chunk.model = model
    chunk.has_model = true
    chunk.is_dirty = false
}
