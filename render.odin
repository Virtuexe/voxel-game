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

init_block_model :: proc() {
    mesh := rl.GenMeshCube(1, 1, 1)
    coords := cast([^]f32)mesh.texcoords

    set_face_uvs(coords, 0, UV_ROT_90)  
    set_face_uvs(coords, 1, UV_ROT_180) 
    set_face_uvs(coords, 2, UV_NORMAL) 
    set_face_uvs(coords, 3, UV_ROT_90)  
    set_face_uvs(coords, 4, UV_ROT_180)  
    set_face_uvs(coords, 5, UV_ROT_90) 
    
    rl.UpdateMeshBuffer(mesh, 1, mesh.texcoords, mesh.vertexCount * 2 * size_of(f32), 0)
    block_model = rl.LoadModelFromMesh(mesh)
}

UV_HALF_ROT_90  :: [8]f32{ 0,1, 1,1, 1,0.5, 0,0.5 }
UV_HALF_ROT_180 :: [8]f32{ 1,1, 1,0.5, 0,0.5, 0,1 }

init_slab_model :: proc() {
    mesh := rl.GenMeshCube(1, 0.5, 1)

    verts := cast([^]f32)mesh.vertices
    for i in 0..<mesh.vertexCount {
        verts[i * 3 + 1] -= 0.25 
    }
    rl.UpdateMeshBuffer(mesh, 0, mesh.vertices, mesh.vertexCount * 3 * size_of(f32), 0)

    coords := cast([^]f32)mesh.texcoords

    set_face_uvs(coords, 0, UV_HALF_ROT_90)  
    set_face_uvs(coords, 1, UV_HALF_ROT_180) 
    set_face_uvs(coords, 2, UV_NORMAL) 
    set_face_uvs(coords, 3, UV_ROT_90)  
    set_face_uvs(coords, 4, UV_HALF_ROT_180)  
    set_face_uvs(coords, 5, UV_HALF_ROT_90) 
    
    rl.UpdateMeshBuffer(mesh, 1, mesh.texcoords, mesh.vertexCount * 2 * size_of(f32), 0)
    slab_model = rl.LoadModelFromMesh(mesh) 
}

init_decal_model :: proc() {
    decal_model = rl.LoadModelFromMesh(rl.GenMeshPlane(1, 1, 1, 1))
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
