package voxel_game

import rl "vendor:raylib"

UV_NORMAL :: [8]f32{ 0,0, 0,1, 1,1, 1,0 }
UV_ROT_90 :: [8]f32{ 0,1, 1,1, 1,0, 0,0 }
UV_ROT_180:: [8]f32{ 1,1, 1,0, 0,0, 0,1 }
UV_ROT_270:: [8]f32{ 1,0, 0,0, 0,1, 1,1 }

set_face_uvs :: proc(c: [^]f32, face_idx: int, uv_data: [8]f32) {
    for val, i in uv_data {
        c[face_idx * 8 + i] = val
    }
}

white_texture: rl.Texture2D

UV_HALF_ROT_90  :: [8]f32{ 0,1, 1,1, 1,0.5, 0,0.5 }
UV_HALF_ROT_180 :: [8]f32{ 1,1, 1,0.5, 0,0.5, 0,1 }

make_multi_material_model :: proc(is_slab: bool) -> rl.Model {
    model: rl.Model
    model.transform = rl.Matrix(1)
    model.meshCount = 2
    model.materialCount = 2
    model.meshes = cast(^rl.Mesh)rl.MemAlloc(u32(size_of(rl.Mesh) * 2))
    model.materials = cast(^rl.Material)rl.MemAlloc(u32(size_of(rl.Material) * 2))
    model.meshMaterial = cast(^i32)rl.MemAlloc(u32(size_of(i32) * 2))
    
    model.materials[0] = rl.LoadMaterialDefault()
    model.materials[1] = rl.LoadMaterialDefault()
    model.meshMaterial[0] = 0 // Sides use material 0
    model.meshMaterial[1] = 1 // Top/bottom use material 1
    
    for i in 0..<2 {
        mesh := rl.GenMeshCube(1, is_slab ? 0.5 : 1, 1)
        
        coords := cast([^]f32)mesh.texcoords
        if is_slab {
            set_face_uvs(coords, 0, UV_HALF_ROT_90)  
            set_face_uvs(coords, 1, UV_HALF_ROT_180) 
            set_face_uvs(coords, 2, UV_NORMAL) 
            set_face_uvs(coords, 3, UV_ROT_90)  
            set_face_uvs(coords, 4, UV_HALF_ROT_180)  
            set_face_uvs(coords, 5, UV_HALF_ROT_90) 
        } else {
            set_face_uvs(coords, 0, UV_ROT_90)  
            set_face_uvs(coords, 1, UV_ROT_180) 
            set_face_uvs(coords, 2, UV_NORMAL) 
            set_face_uvs(coords, 3, UV_ROT_90)  
            set_face_uvs(coords, 4, UV_ROT_180)  
            set_face_uvs(coords, 5, UV_ROT_90) 
        }
        rl.UpdateMeshBuffer(mesh, 1, mesh.texcoords, mesh.vertexCount * 2 * size_of(f32), 0)
        
        faces := i == 0 ? []int{0, 1, 4, 5} : []int{2, 3}
        indices := cast([^]u16)mesh.indices
        
        temp_indices: [36]u16
        for j in 0..<36 { temp_indices[j] = indices[j] }
        
        idx := 0
        for face in faces {
            for j in 0..<6 {
                indices[idx] = temp_indices[face * 6 + j]
                idx += 1
            }
        }
        
        mesh.triangleCount = i32(len(faces) * 2)
        
        // Update GPU index buffer (index 6 is INDEX_BUFFER)
        rl.UpdateMeshBuffer(mesh, 6, mesh.indices, mesh.triangleCount * 3 * size_of(u16), 0)
        
        model.meshes[i] = mesh
    }
    
    return model
}

init_block_model :: proc() {
    block_model = make_multi_material_model(false)
}

init_slab_model :: proc() {
    slab_model = make_multi_material_model(true)
}

init_decal_model :: proc() {
    decal_model = rl.LoadModelFromMesh(rl.GenMeshPlane(1, 1, 1, 1))
    
    img := rl.GenImageColor(1, 1, rl.WHITE)
    white_texture = rl.LoadTextureFromImage(img)
    rl.UnloadImage(img)
}

gen_redstone_textures :: proc() {
    for &texture, state in redstone_render_texture {
        is_on := (state & (1 << len(Direction))) != 0
        connections: [Direction]bool
        for dir, dir_index in Direction {
            dir_index := uint(dir_index)
            has_dir := (state & (1 << dir_index)) != 0
            connections[dir] = has_dir
        }
        texture = gen_redstone_texture(is_on, connections)
    }
}

gen_redstone_texture :: proc(on: bool, connections: [Direction]bool) -> rl.RenderTexture2D {
    dot: rl.Texture2D
    wire: rl.Texture2D
    if on {
        dot = rl.LoadTexture("assets/redstone_dot_on.png")
        wire = rl.LoadTexture("assets/redstone_wire_on.png")
    }
    else {
        dot = rl.LoadTexture("assets/redstone_dot_off.png")
        wire = rl.LoadTexture("assets/redstone_dot_off.png")
    }
    result := rl.LoadRenderTexture(16, 16)
    rec := rl.Rectangle{0,0,16,16}
    rl.BeginTextureMode(result)
    rl.DrawTextureRec(dot, rec, {0,0}, rl.WHITE)
    for connection, dir in connections {
        if connection == false do continue
        rot: f32
        switch dir {
        case .Up: rot = 180
        case .Down: rot = 0
        case .Right: rot = 90
        case .Left: rot = 270
        }
        rl.DrawTexturePro(wire, rec, {8,8,16,16}, {8, 8}, rot, rl.WHITE)
    }
    rl.EndTextureMode()
    rl.UnloadTexture(dot)
    rl.UnloadTexture(wire)
    return result
}

get_redstone_texture :: proc(on: bool, connections: [Direction]bool) -> rl.RenderTexture2D {
    state := int(on) * (1 << len(Direction))
    
    for connected, dir in connections {
        if connected {
            state |= (1 << uint(dir))
        }
    }
    
    return redstone_render_texture[state]
}
