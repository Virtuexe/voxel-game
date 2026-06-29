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
block_shader: rl.Shader

init_shaders :: proc() {
    vs := `
    #version 330
    in vec3 vertexPosition;
    in vec2 vertexTexCoord;
    in vec3 vertexNormal;
    in vec4 vertexColor;
    out vec2 fragTexCoord;
    out vec4 fragColor;
    out vec3 fragNormal;
    uniform mat4 mvp;
    uniform mat4 matModel;
    void main() {
        fragTexCoord = vertexTexCoord;
        fragColor = vertexColor;
        fragNormal = normalize(vec3(matModel * vec4(vertexNormal, 0.0)));
        gl_Position = mvp * vec4(vertexPosition, 1.0);
    }`
    fs := `
    #version 330
    in vec2 fragTexCoord;
    in vec4 fragColor;
    in vec3 fragNormal;
    out vec4 finalColor;
    uniform sampler2D texture0;
    uniform vec4 colDiffuse;
    void main() {
        vec4 texelColor = texture(texture0, fragTexCoord);
        if (texelColor.a == 0.0) discard;
        
        float light = 1.0;
        vec3 n = normalize(fragNormal);
        if (n.y > 0.5) light = 1.0;
        else if (n.y < -0.5) light = 0.5;
        else if (abs(n.x) > 0.5) light = 0.6;
        else if (abs(n.z) > 0.5) light = 0.8;
        
        finalColor = texelColor * colDiffuse * fragColor * vec4(light, light, light, 1.0);
    }`
    
    // We can directly cast Odin raw string literals to cstring for raylib
    block_shader = rl.LoadShaderFromMemory(cstring(raw_data(vs)), cstring(raw_data(fs)))
}

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
    model.materials[0].shader = block_shader
    model.materials[1].shader = block_shader
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
    block_model_bbox = rl.GetModelBoundingBox(block_model)
}

init_slab_model :: proc() {
    slab_model = make_multi_material_model(true)
    for i in 0..<slab_model.meshCount {
        mesh := &slab_model.meshes[i]
        vertices := cast([^]f32)mesh.vertices
        for v in 0..<mesh.vertexCount {
            vertices[v * 3 + 1] -= 0.25
        }
        rl.UpdateMeshBuffer(mesh^, 0, mesh.vertices, mesh.vertexCount * 3 * size_of(f32), 0)
    }
    slab_model_bbox = rl.GetModelBoundingBox(slab_model)
}

init_decal_model :: proc() {
    decal_model = rl.LoadModelFromMesh(rl.GenMeshPlane(1, 1, 1, 1))
    decal_model.materials[0].shader = block_shader
    for i in 0..<decal_model.meshCount {
        mesh := &decal_model.meshes[i]
        vertices := cast([^]f32)mesh.vertices
        for v in 0..<mesh.vertexCount {
            vertices[v * 3 + 1] -= 0.499
        }
        rl.UpdateMeshBuffer(mesh^, 0, mesh.vertices, mesh.vertexCount * 3 * size_of(f32), 0)
    }
    decal_model_bbox = rl.GetModelBoundingBox(decal_model)
    
    img := rl.GenImageColor(1, 1, rl.WHITE)
    white_texture = rl.LoadTextureFromImage(img)
    rl.UnloadImage(img)
}

// Stair faces south (+Z) by default; HAS_CARDINAL rotates at draw time.
// Single mesh, 10 visible outer faces only — no internal shared faces (no z-fighting).
// UVs are proportional to face size (half-unit faces use 0..0.5 range).
init_stairs_model :: proc() {
    NFACES :: 10
    VCOUNT :: NFACES * 4    // 4 verts per quad
    TCOUNT :: NFACES * 2    // 2 triangles per quad

    mesh: rl.Mesh
    mesh.vertexCount   = VCOUNT
    mesh.triangleCount = TCOUNT
    mesh.vertices  = cast([^]f32)rl.MemAlloc(u32(VCOUNT * 3 * size_of(f32)))
    mesh.normals   = cast([^]f32)rl.MemAlloc(u32(VCOUNT * 3 * size_of(f32)))
    mesh.texcoords = cast([^]f32)rl.MemAlloc(u32(VCOUNT * 2 * size_of(f32)))
    mesh.indices   = cast([^]u16)rl.MemAlloc(u32(TCOUNT * 3 * size_of(u16)))

    vi, ni, ti, ii := 0, 0, 0, 0
    // Append one quad (4 verts CCW-from-outside) with per-vertex UVs
    quad :: proc(m: ^rl.Mesh, vi, ni, ti, ii: ^int,
                 p: [4][3]f32, norm: [3]f32, uv: [4][2]f32) {
        vb := cast([^]f32)m.vertices; nb := cast([^]f32)m.normals
        tb := cast([^]f32)m.texcoords; ib := cast([^]u16)m.indices
        base := u16(vi^ / 3)
        for k in 0..<4 {
            vb[vi^  ]=p[k][0]; vb[vi^+1]=p[k][1]; vb[vi^+2]=p[k][2]; vi^+=3
            nb[ni^  ]=norm[0]; nb[ni^+1]=norm[1]; nb[ni^+2]=norm[2]; ni^+=3
            tb[ti^  ]=uv[k][0]; tb[ti^+1]=uv[k][1]; ti^+=2
        }
        ib[ii^]=base; ib[ii^+1]=base+1; ib[ii^+2]=base+2
        ib[ii^+3]=base; ib[ii^+4]=base+2; ib[ii^+5]=base+3
        ii^+=6
    }

    // ------- Bottom face (y=-0.5, full 1×1) normal -Y -------
    {
        p  := [4][3]f32{{-0.5,-0.5,-0.5},{0.5,-0.5,-0.5},{0.5,-0.5,0.5},{-0.5,-0.5,0.5}}
        uv := [4][2]f32{{0,0},{1,0},{1,1},{0,1}}
        quad(&mesh,&vi,&ni,&ti,&ii, p, {0,-1,0}, uv)
    }
    // ------- Back face (z=-0.5, full 1×1) normal -Z -------
    {
        p  := [4][3]f32{{0.5,-0.5,-0.5},{-0.5,-0.5,-0.5},{-0.5,0.5,-0.5},{0.5,0.5,-0.5}}
        uv := [4][2]f32{{0,1},{1,1},{1,0},{0,0}}
        quad(&mesh,&vi,&ni,&ti,&ii, p, {0,0,-1}, uv)
    }
    // ------- Front lower (z=0.5, y=-0.5..0, 1×0.5) normal +Z -------
    {
        p  := [4][3]f32{{-0.5,-0.5,0.5},{0.5,-0.5,0.5},{0.5,0.0,0.5},{-0.5,0.0,0.5}}
        uv := [4][2]f32{{0,0.5},{1,0.5},{1,0},{0,0}}
        quad(&mesh,&vi,&ni,&ti,&ii, p, {0,0,1}, uv)
    }
    // ------- Step riser (z=0, y=0..0.5, 1×0.5) normal +Z -------
    {
        p  := [4][3]f32{{-0.5,0.0,0.0},{0.5,0.0,0.0},{0.5,0.5,0.0},{-0.5,0.5,0.0}}
        uv := [4][2]f32{{0,0.5},{1,0.5},{1,0},{0,0}}
        quad(&mesh,&vi,&ni,&ti,&ii, p, {0,0,1}, uv)
    }
    // ------- Tread top (y=0, z=0..0.5, 1×0.5 depth) normal +Y -------
    // edge1=(1,0,0) x edge2=(1,0,-0.5) → (0,+0.5,0) ✓
    {
        p  := [4][3]f32{{-0.5,0.0,0.5},{0.5,0.0,0.5},{0.5,0.0,0.0},{-0.5,0.0,0.0}}
        uv := [4][2]f32{{0,0},{1,0},{1,0.5},{0,0.5}}
        quad(&mesh,&vi,&ni,&ti,&ii, p, {0,1,0}, uv)
    }
    // ------- Cap top (y=0.5, z=-0.5..0, 1×0.5 depth) normal +Y -------
    // edge1=(1,0,0) x edge2=(1,0,-0.5) → (0,+0.5,0) ✓
    {
        p  := [4][3]f32{{-0.5,0.5,0.0},{0.5,0.5,0.0},{0.5,0.5,-0.5},{-0.5,0.5,-0.5}}
        uv := [4][2]f32{{0,0},{1,0},{1,0.5},{0,0.5}}
        quad(&mesh,&vi,&ni,&ti,&ii, p, {0,1,0}, uv)
    }
    // ------- Left lower (x=-0.5, y=-0.5..0, z full, 1×0.5) normal -X -------
    // edge1=(0,0,-1) x edge2=(0,-0.5,-1) → (-0.5,0,0) ✓
    {
        p  := [4][3]f32{{-0.5,0.0,0.5},{-0.5,0.0,-0.5},{-0.5,-0.5,-0.5},{-0.5,-0.5,0.5}}
        uv := [4][2]f32{{0,0},{1,0},{1,0.5},{0,0.5}}
        quad(&mesh,&vi,&ni,&ti,&ii, p, {-1,0,0}, uv)
    }
    // ------- Left upper (x=-0.5, y=0..0.5, z=-0.5..0, 0.5×0.5) normal -X -------
    // edge1=(0,0,-0.5) x edge2=(0,-0.5,-0.5) → (-0.25,0,0) ✓
    {
        p  := [4][3]f32{{-0.5,0.5,0.0},{-0.5,0.5,-0.5},{-0.5,0.0,-0.5},{-0.5,0.0,0.0}}
        uv := [4][2]f32{{0,0},{0.5,0},{0.5,0.5},{0,0.5}}
        quad(&mesh,&vi,&ni,&ti,&ii, p, {-1,0,0}, uv)
    }
    // ------- Right lower (x=0.5, y=-0.5..0, z full, 1×0.5) normal +X -------
    // edge1=(0,0,1) x edge2=(0,-0.5,1) → (+0.5,0,0) ✓
    {
        p  := [4][3]f32{{0.5,0.0,-0.5},{0.5,0.0,0.5},{0.5,-0.5,0.5},{0.5,-0.5,-0.5}}
        uv := [4][2]f32{{0,0},{1,0},{1,0.5},{0,0.5}}
        quad(&mesh,&vi,&ni,&ti,&ii, p, {1,0,0}, uv)
    }
    // ------- Right upper (x=0.5, y=0..0.5, z=-0.5..0, 0.5×0.5) normal +X -------
    // edge1=(0,0,0.5) x edge2=(0,-0.5,0.5) → (+0.25,0,0) ✓
    {
        p  := [4][3]f32{{0.5,0.5,-0.5},{0.5,0.5,0.0},{0.5,0.0,0.0},{0.5,0.0,-0.5}}
        uv := [4][2]f32{{0,0},{0.5,0},{0.5,0.5},{0,0.5}}
        quad(&mesh,&vi,&ni,&ti,&ii, p, {1,0,0}, uv)
    }

    rl.UploadMesh(&mesh, false)

    stairs_model.transform     = rl.Matrix(1)
    stairs_model.meshCount     = 1
    stairs_model.materialCount = 1
    stairs_model.meshes       = cast(^rl.Mesh)    rl.MemAlloc(u32(size_of(rl.Mesh)))
    stairs_model.materials    = cast(^rl.Material)rl.MemAlloc(u32(size_of(rl.Material)))
    stairs_model.meshMaterial = cast(^i32)        rl.MemAlloc(u32(size_of(i32)))
    stairs_model.meshes[0]    = mesh
    stairs_model.materials[0] = rl.LoadMaterialDefault()
    stairs_model.materials[0].shader = block_shader
    stairs_model.meshMaterial[0] = 0
    stairs_model_bbox = rl.GetModelBoundingBox(stairs_model)
}

gen_redstone_textures :: proc() {
    for &texture, state in redstone_render_texture {
        is_on := (state & (1 << len(Cardinal))) != 0
        connections: [Cardinal]bool
        for _, dir_index in Cardinal {
            has_dir := (state & (1 << uint(dir_index))) != 0
            connections[Cardinal(dir_index)] = has_dir
        }
        texture = gen_redstone_texture(is_on, connections)
    }
}

gen_redstone_texture :: proc(on: bool, connections: [Cardinal]bool) -> rl.RenderTexture2D {
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
        case .North: rot = 180
        case .South: rot = 0
        case .East: rot = 90
        case .West: rot = 270
        }
        rl.DrawTexturePro(wire, rec, {8,8,16,16}, {8, 8}, rot, rl.WHITE)
    }
    rl.EndTextureMode()
    rl.UnloadTexture(dot)
    rl.UnloadTexture(wire)
    return result
}

get_redstone_texture :: proc(on: bool, connections: [Cardinal]bool) -> rl.RenderTexture2D {
    state := int(on) * (1 << len(Cardinal))
    
    for connected, dir in connections {
        if connected {
            state |= (1 << uint(dir))
        }
    }
    
    return redstone_render_texture[state]
}
