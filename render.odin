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
    model.meshCount = 6
    model.materialCount = 6
    model.meshes = cast(^rl.Mesh)rl.MemAlloc(u32(size_of(rl.Mesh) * 6))
    model.materials = cast(^rl.Material)rl.MemAlloc(u32(size_of(rl.Material) * 6))
    model.meshMaterial = cast(^i32)rl.MemAlloc(u32(size_of(i32) * 6))
    
    for i in 0..<6 {
        model.materials[i] = rl.LoadMaterialDefault()
        model.materials[i].shader = block_shader
        model.meshMaterial[i] = i32(i)
    }
    
    for i in 0..<6 {
        face_enum := Block_Face(i)
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
        
        face_idx: int
        switch face_enum {
        case .Top: face_idx = 2
        case .Bottom: face_idx = 3
        case .North: face_idx = 1
        case .South: face_idx = 0
        case .East: face_idx = 4
        case .West: face_idx = 5
        }

        faces := []int{face_idx}
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
    stairs_model.transform     = rl.Matrix(1)
    stairs_model.meshCount     = 6
    stairs_model.materialCount = 6
    stairs_model.meshes       = cast(^rl.Mesh)    rl.MemAlloc(u32(size_of(rl.Mesh) * 6))
    stairs_model.materials    = cast(^rl.Material)rl.MemAlloc(u32(size_of(rl.Material) * 6))
    stairs_model.meshMaterial = cast(^i32)        rl.MemAlloc(u32(size_of(i32) * 6))

    for i in 0..<6 {
        stairs_model.materials[i] = rl.LoadMaterialDefault()
        stairs_model.materials[i].shader = block_shader
        stairs_model.meshMaterial[i] = i32(i)
    }

    allocate_mesh :: proc(num_quads: int) -> rl.Mesh {
        mesh: rl.Mesh
        vcount := num_quads * 4
        tcount := num_quads * 2
        mesh.vertexCount = i32(vcount)
        mesh.triangleCount = i32(tcount)
        if vcount > 0 {
            mesh.vertices  = cast([^]f32)rl.MemAlloc(u32(vcount * 3 * size_of(f32)))
            mesh.normals   = cast([^]f32)rl.MemAlloc(u32(vcount * 3 * size_of(f32)))
            mesh.texcoords = cast([^]f32)rl.MemAlloc(u32(vcount * 2 * size_of(f32)))
            mesh.indices   = cast([^]u16)rl.MemAlloc(u32(tcount * 3 * size_of(u16)))
        }
        return mesh
    }

    stairs_model.meshes[int(Block_Face.Top)]    = allocate_mesh(2)
    stairs_model.meshes[int(Block_Face.Bottom)] = allocate_mesh(1)
    stairs_model.meshes[int(Block_Face.North)]  = allocate_mesh(1)
    stairs_model.meshes[int(Block_Face.South)]  = allocate_mesh(2)
    stairs_model.meshes[int(Block_Face.East)]   = allocate_mesh(2)
    stairs_model.meshes[int(Block_Face.West)]   = allocate_mesh(2)

    vis := [6]int{}
    nis := [6]int{}
    tis := [6]int{}
    iis := [6]int{}

    quad :: proc(m: []rl.Mesh, face: Block_Face, vis, nis, tis, iis: ^[6]int,
                 p: [4][3]f32, norm: [3]f32, uv: [4][2]f32) {
        fi := int(face)
        mesh := &m[fi]
        vb := cast([^]f32)mesh.vertices; nb := cast([^]f32)mesh.normals
        tb := cast([^]f32)mesh.texcoords; ib := cast([^]u16)mesh.indices
        base := u16(vis[fi] / 3)
        for k in 0..<4 {
            vb[vis[fi]  ]=p[k][0]; vb[vis[fi]+1]=p[k][1]; vb[vis[fi]+2]=p[k][2]; vis[fi]+=3
            nb[nis[fi]  ]=norm[0]; nb[nis[fi]+1]=norm[1]; nb[nis[fi]+2]=norm[2]; nis[fi]+=3
            tb[tis[fi]  ]=uv[k][0]; tb[tis[fi]+1]=uv[k][1]; tis[fi]+=2
        }
        ib[iis[fi]]=base; ib[iis[fi]+1]=base+1; ib[iis[fi]+2]=base+2
        ib[iis[fi]+3]=base; ib[iis[fi]+4]=base+2; ib[iis[fi]+5]=base+3
        iis[fi]+=6
    }

    meshes := stairs_model.meshes[:6]

    // ------- Bottom face (y=-0.5, full 1×1) normal -Y -------
    {
        p  := [4][3]f32{{-0.5,-0.5,-0.5},{0.5,-0.5,-0.5},{0.5,-0.5,0.5},{-0.5,-0.5,0.5}}
        uv := [4][2]f32{{0,0},{1,0},{1,1},{0,1}}
        quad(meshes, .Bottom, &vis, &nis, &tis, &iis, p, {0,-1,0}, uv)
    }
    // ------- Back face (z=-0.5, full 1×1) normal -Z -------
    {
        p  := [4][3]f32{{0.5,-0.5,-0.5},{-0.5,-0.5,-0.5},{-0.5,0.5,-0.5},{0.5,0.5,-0.5}}
        uv := [4][2]f32{{0,1},{1,1},{1,0},{0,0}}
        quad(meshes, .North, &vis, &nis, &tis, &iis, p, {0,0,-1}, uv)
    }
    // ------- Front lower (z=0.5, y=-0.5..0, 1×0.5) normal +Z -------
    {
        p  := [4][3]f32{{-0.5,-0.5,0.5},{0.5,-0.5,0.5},{0.5,0.0,0.5},{-0.5,0.0,0.5}}
        uv := [4][2]f32{{0,0.5},{1,0.5},{1,0},{0,0}}
        quad(meshes, .South, &vis, &nis, &tis, &iis, p, {0,0,1}, uv)
    }
    // ------- Step riser (z=0, y=0..0.5, 1×0.5) normal +Z -------
    {
        p  := [4][3]f32{{-0.5,0.0,0.0},{0.5,0.0,0.0},{0.5,0.5,0.0},{-0.5,0.5,0.0}}
        uv := [4][2]f32{{0,0.5},{1,0.5},{1,0},{0,0}}
        quad(meshes, .South, &vis, &nis, &tis, &iis, p, {0,0,1}, uv)
    }
    // ------- Tread top (y=0, z=0..0.5, 1×0.5 depth) normal +Y -------
    {
        p  := [4][3]f32{{-0.5,0.0,0.5},{0.5,0.0,0.5},{0.5,0.0,0.0},{-0.5,0.0,0.0}}
        uv := [4][2]f32{{0,0},{1,0},{1,0.5},{0,0.5}}
        quad(meshes, .Top, &vis, &nis, &tis, &iis, p, {0,1,0}, uv)
    }
    // ------- Cap top (y=0.5, z=-0.5..0, 1×0.5 depth) normal +Y -------
    {
        p  := [4][3]f32{{-0.5,0.5,0.0},{0.5,0.5,0.0},{0.5,0.5,-0.5},{-0.5,0.5,-0.5}}
        uv := [4][2]f32{{0,0},{1,0},{1,0.5},{0,0.5}}
        quad(meshes, .Top, &vis, &nis, &tis, &iis, p, {0,1,0}, uv)
    }
    // ------- Left lower (x=-0.5, y=-0.5..0, z full, 1×0.5) normal -X -------
    {
        p  := [4][3]f32{{-0.5,0.0,0.5},{-0.5,0.0,-0.5},{-0.5,-0.5,-0.5},{-0.5,-0.5,0.5}}
        uv := [4][2]f32{{0,0},{1,0},{1,0.5},{0,0.5}}
        quad(meshes, .West, &vis, &nis, &tis, &iis, p, {-1,0,0}, uv)
    }
    // ------- Left upper (x=-0.5, y=0..0.5, z=-0.5..0, 0.5×0.5) normal -X -------
    {
        p  := [4][3]f32{{-0.5,0.5,0.0},{-0.5,0.5,-0.5},{-0.5,0.0,-0.5},{-0.5,0.0,0.0}}
        uv := [4][2]f32{{0,0},{0.5,0},{0.5,0.5},{0,0.5}}
        quad(meshes, .West, &vis, &nis, &tis, &iis, p, {-1,0,0}, uv)
    }
    // ------- Right lower (x=0.5, y=-0.5..0, z full, 1×0.5) normal +X -------
    {
        p  := [4][3]f32{{0.5,0.0,-0.5},{0.5,0.0,0.5},{0.5,-0.5,0.5},{0.5,-0.5,-0.5}}
        uv := [4][2]f32{{0,0},{1,0},{1,0.5},{0,0.5}}
        quad(meshes, .East, &vis, &nis, &tis, &iis, p, {1,0,0}, uv)
    }
    // ------- Right upper (x=0.5, y=0..0.5, z=-0.5..0, 0.5×0.5) normal +X -------
    {
        p  := [4][3]f32{{0.5,0.5,-0.5},{0.5,0.5,0.0},{0.5,0.0,0.0},{0.5,0.0,-0.5}}
        uv := [4][2]f32{{0,0},{0.5,0},{0.5,0.5},{0,0.5}}
        quad(meshes, .East, &vis, &nis, &tis, &iis, p, {1,0,0}, uv)
    }

    for i in 0..<6 {
        rl.UploadMesh(&stairs_model.meshes[i], false)
    }

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
