package voxel_game

import rl "vendor:raylib"

Block_Model_Builder :: struct {
    positions: [MAX_TEXTURE_GROUPS * 6][dynamic][3]f32,
    normals:   [MAX_TEXTURE_GROUPS * 6][dynamic][3]f32,
    texcoords: [MAX_TEXTURE_GROUPS * 6][dynamic][2]f32,
    indices:   [MAX_TEXTURE_GROUPS * 6][dynamic]u16,
    collision_bboxes: [MAX_TEXTURE_GROUPS][dynamic]rl.BoundingBox,
    center: Vec3,
}

builder_init :: proc() -> Block_Model_Builder {
    b: Block_Model_Builder
    b.center = {0.5, 0.5, 0.5}
    return b
}

builder_set_center :: proc(b: ^Block_Model_Builder, center: Vec3) {
    b.center = center
}

px_vec :: proc(v: Vec3) -> Vec3 {
    return v / 16.0
}

builder_destroy :: proc(b: ^Block_Model_Builder) {
    for i in 0..<MAX_TEXTURE_GROUPS * 6 {
        delete(b.positions[i])
        delete(b.normals[i])
        delete(b.texcoords[i])
        delete(b.indices[i])
    }
    for i in 0..<MAX_TEXTURE_GROUPS {
        delete(b.collision_bboxes[i])
    }
}

builder_add_collision_box :: proc(b: ^Block_Model_Builder, group: int, min_p, max_p: [3]f32) {
    append(&b.collision_bboxes[group], rl.BoundingBox{min_p, max_p})
}

// Accurately calculates bounding box from only the generated vertices
// (Fixes rl.GetModelBoundingBox returning origin {0,0,0} for empty meshes)
builder_get_visual_bbox :: proc(b: ^Block_Model_Builder, group: int) -> rl.BoundingBox {
    has_verts := false
    min_p := [3]f32{99999, 99999, 99999}
    max_p := [3]f32{-99999, -99999, -99999}
    
    start_idx := group * 6
    end_idx := start_idx + 6
    
    for i in start_idx..<end_idx {
        for p in b.positions[i] {
            has_verts = true
            min_p.x = min(min_p.x, p.x)
            min_p.y = min(min_p.y, p.y)
            min_p.z = min(min_p.z, p.z)
            max_p.x = max(max_p.x, p.x)
            max_p.y = max(max_p.y, p.y)
            max_p.z = max(max_p.z, p.z)
        }
    }
    
    if !has_verts do return rl.BoundingBox{}
    return rl.BoundingBox{min_p, max_p}
}

// Builds and uploads a multi-material model (one mesh per face material).
builder_build :: proc(b: ^Block_Model_Builder, facing := Block_Face.North) -> rl.Model {
    model: rl.Model
    model.transform = rl.Matrix(1)
    
    active_mesh_count := 0
    for i in 0..<MAX_TEXTURE_GROUPS * 6 {
        if len(b.positions[i]) > 0 do active_mesh_count += 1
    }
    
    model.meshCount = i32(active_mesh_count)
    model.materialCount = MAX_TEXTURE_GROUPS * 6
    if active_mesh_count > 0 {
        model.meshes = cast(^rl.Mesh)rl.MemAlloc(u32(size_of(rl.Mesh) * active_mesh_count))
        model.meshMaterial = cast(^i32)rl.MemAlloc(u32(size_of(i32) * active_mesh_count))
    }
    model.materials = cast(^rl.Material)rl.MemAlloc(u32(size_of(rl.Material) * MAX_TEXTURE_GROUPS * 6))
    
    for i in 0..<MAX_TEXTURE_GROUPS * 6 {
        model.materials[i] = rl.LoadMaterialDefault()
        model.materials[i].shader = block_shader
    }
    
    m_idx := 0
    for i in 0..<MAX_TEXTURE_GROUPS * 6 {
        vcount := len(b.positions[i])
        if vcount == 0 do continue
        
        model.meshMaterial[m_idx] = i32(i)
        
        mesh := &model.meshes[m_idx]
        tcount := len(b.indices[i]) / 3
        mesh.vertexCount = i32(vcount)
        mesh.triangleCount = i32(tcount)
        
        mesh.vertices = cast([^]f32)rl.MemAlloc(u32(vcount * 3 * size_of(f32)))
        mesh.normals = cast([^]f32)rl.MemAlloc(u32(vcount * 3 * size_of(f32)))
        mesh.texcoords = cast([^]f32)rl.MemAlloc(u32(vcount * 2 * size_of(f32)))
        mesh.indices = cast([^]u16)rl.MemAlloc(u32(tcount * 3 * size_of(u16)))
        
        for v, j in b.positions[i] {
            (cast([^]f32)mesh.vertices)[j * 3 + 0] = v.x
            (cast([^]f32)mesh.vertices)[j * 3 + 1] = v.y
            (cast([^]f32)mesh.vertices)[j * 3 + 2] = v.z
        }
        for n, j in b.normals[i] {
            (cast([^]f32)mesh.normals)[j * 3 + 0] = n.x
            (cast([^]f32)mesh.normals)[j * 3 + 1] = n.y
            (cast([^]f32)mesh.normals)[j * 3 + 2] = n.z
        }
        for t, j in b.texcoords[i] {
            (cast([^]f32)mesh.texcoords)[j * 2 + 0] = t.x
            (cast([^]f32)mesh.texcoords)[j * 2 + 1] = t.y
        }
        for idx, j in b.indices[i] {
            (cast([^]u16)mesh.indices)[j] = idx
        }
        
        rl.UploadMesh(mesh, false)
        m_idx += 1
    }
    
    return model
}

// Adds a single rectangular quad for a specific face.
// `min_p` and `max_p` should describe a 2D bounds (i.e. one dimension is the same in both).
builder_add_quad :: proc(b: ^Block_Model_Builder, face: Block_Face, min_p, max_p: [3]f32, group: int = 0, uv_rot: UV_Rotation = .Deg_0, uv_rect: UV_Rect = {}) {
    p: [4][3]f32
    uv: [4][2]f32
    norm: [3]f32
    
    switch face {
    case .Top:
        norm = {0, 1, 0}
        p[0] = {min_p.x, max_p.y, min_p.z}
        p[1] = {min_p.x, max_p.y, max_p.z}
        p[2] = {max_p.x, max_p.y, max_p.z}
        p[3] = {max_p.x, max_p.y, min_p.z}
        for i in 0..<4 do uv[i] = {p[i].x, p[i].z}

    case .Bottom:
        norm = {0, -1, 0}
        p[0] = {min_p.x, min_p.y, max_p.z}
        p[1] = {min_p.x, min_p.y, min_p.z}
        p[2] = {max_p.x, min_p.y, min_p.z}
        p[3] = {max_p.x, min_p.y, max_p.z}
        for i in 0..<4 do uv[i] = {p[i].x, p[i].z}

    case .South: // +Z
        norm = {0, 0, 1}
        p[0] = {min_p.x, max_p.y, max_p.z}
        p[1] = {min_p.x, min_p.y, max_p.z}
        p[2] = {max_p.x, min_p.y, max_p.z}
        p[3] = {max_p.x, max_p.y, max_p.z}
        for i in 0..<4 do uv[i] = {p[i].x, 1.0 - p[i].y}

    case .North: // -Z
        norm = {0, 0, -1}
        p[0] = {max_p.x, max_p.y, min_p.z}
        p[1] = {max_p.x, min_p.y, min_p.z}
        p[2] = {min_p.x, min_p.y, min_p.z}
        p[3] = {min_p.x, max_p.y, min_p.z}
        for i in 0..<4 do uv[i] = {1.0 - p[i].x, 1.0 - p[i].y}

    case .East: // +X
        norm = {1, 0, 0}
        p[0] = {max_p.x, max_p.y, max_p.z}
        p[1] = {max_p.x, min_p.y, max_p.z}
        p[2] = {max_p.x, min_p.y, min_p.z}
        p[3] = {max_p.x, max_p.y, min_p.z}
        for i in 0..<4 do uv[i] = {1.0 - p[i].z, 1.0 - p[i].y}

    case .West: // -X
        norm = {-1, 0, 0}
        p[0] = {min_p.x, max_p.y, min_p.z}
        p[1] = {min_p.x, min_p.y, min_p.z}
        p[2] = {min_p.x, min_p.y, max_p.z}
        p[3] = {min_p.x, max_p.y, max_p.z}
        for i in 0..<4 do uv[i] = {p[i].z, 1.0 - p[i].y}
    }
    
    fi := group * 6 + int(face)
    base := u16(len(b.positions[fi]))
    
    if uv_rect.size.x != 0 || uv_rect.size.y != 0 {
        uv[0] = {uv_rect.pos.x, uv_rect.pos.y}
        uv[1] = {uv_rect.pos.x, uv_rect.pos.y + uv_rect.size.y}
        uv[2] = {uv_rect.pos.x + uv_rect.size.x, uv_rect.pos.y + uv_rect.size.y}
        uv[3] = {uv_rect.pos.x + uv_rect.size.x, uv_rect.pos.y}
    }
    
    for i in 0..<4 {
        append(&b.positions[fi], p[i])
        append(&b.normals[fi], norm)
        append(&b.texcoords[fi], uv[(i + int(uv_rot)) % 4])
    }
    // Quad triangles: 0,1,2 and 0,2,3
    append(&b.indices[fi], base, base+1, base+2)
    append(&b.indices[fi], base, base+2, base+3)
}

// Automatically builds a box adding 6 outer quads (unless faces are excluded)
builder_add_box :: proc(b: ^Block_Model_Builder, min_p, max_p: [3]f32, excluded_faces: bit_set[Block_Face] = {}, group: int = 0, uv_rotations: [Block_Face]UV_Rotation = {}, uv_rects: [Block_Face]UV_Rect = {}) {
    if .Top not_in excluded_faces    do builder_add_quad(b, .Top,    {min_p.x, max_p.y, min_p.z}, {max_p.x, max_p.y, max_p.z}, group, uv_rotations[.Top], uv_rects[.Top])
    if .Bottom not_in excluded_faces do builder_add_quad(b, .Bottom, {min_p.x, min_p.y, min_p.z}, {max_p.x, min_p.y, max_p.z}, group, uv_rotations[.Bottom], uv_rects[.Bottom])
    if .North not_in excluded_faces  do builder_add_quad(b, .North,  {min_p.x, min_p.y, min_p.z}, {max_p.x, max_p.y, min_p.z}, group, uv_rotations[.North], uv_rects[.North])
    if .South not_in excluded_faces  do builder_add_quad(b, .South,  {min_p.x, min_p.y, max_p.z}, {max_p.x, max_p.y, max_p.z}, group, uv_rotations[.South], uv_rects[.South])
    if .East not_in excluded_faces   do builder_add_quad(b, .East,   {max_p.x, min_p.y, min_p.z}, {max_p.x, max_p.y, max_p.z}, group, uv_rotations[.East], uv_rects[.East])
    if .West not_in excluded_faces   do builder_add_quad(b, .West,   {min_p.x, min_p.y, min_p.z}, {min_p.x, max_p.y, max_p.z}, group, uv_rotations[.West], uv_rects[.West])
    builder_add_collision_box(b, group, min_p, max_p)
}

builder_add_inverted_quad :: proc(b: ^Block_Model_Builder, face: Block_Face, min_p, max_p: [3]f32, group: int = 0, uv_rot: UV_Rotation = .Deg_0, uv_rect: UV_Rect = {}) {
    p: [4][3]f32
    uv: [4][2]f32
    norm: [3]f32
    
    switch face {
    case .Top:
        norm = {0, -1, 0}
        p[0] = {min_p.x, max_p.y, min_p.z}
        p[1] = {min_p.x, max_p.y, max_p.z}
        p[2] = {max_p.x, max_p.y, max_p.z}
        p[3] = {max_p.x, max_p.y, min_p.z}
        for i in 0..<4 do uv[i] = {p[i].x, p[i].z}

    case .Bottom:
        norm = {0, 1, 0}
        p[0] = {min_p.x, min_p.y, max_p.z}
        p[1] = {min_p.x, min_p.y, min_p.z}
        p[2] = {max_p.x, min_p.y, min_p.z}
        p[3] = {max_p.x, min_p.y, max_p.z}
        for i in 0..<4 do uv[i] = {p[i].x, p[i].z}

    case .South: // +Z
        norm = {0, 0, -1}
        p[0] = {min_p.x, max_p.y, max_p.z}
        p[1] = {min_p.x, min_p.y, max_p.z}
        p[2] = {max_p.x, min_p.y, max_p.z}
        p[3] = {max_p.x, max_p.y, max_p.z}
        for i in 0..<4 do uv[i] = {p[i].x, 1.0 - p[i].y}

    case .North: // -Z
        norm = {0, 0, 1}
        p[0] = {max_p.x, max_p.y, min_p.z}
        p[1] = {max_p.x, min_p.y, min_p.z}
        p[2] = {min_p.x, min_p.y, min_p.z}
        p[3] = {min_p.x, max_p.y, min_p.z}
        for i in 0..<4 do uv[i] = {1.0 - p[i].x, 1.0 - p[i].y}

    case .East: // +X
        norm = {-1, 0, 0}
        p[0] = {max_p.x, max_p.y, max_p.z}
        p[1] = {max_p.x, min_p.y, max_p.z}
        p[2] = {max_p.x, min_p.y, min_p.z}
        p[3] = {max_p.x, max_p.y, min_p.z}
        for i in 0..<4 do uv[i] = {1.0 - p[i].z, 1.0 - p[i].y}

    case .West: // -X
        norm = {1, 0, 0}
        p[0] = {min_p.x, max_p.y, min_p.z}
        p[1] = {min_p.x, min_p.y, min_p.z}
        p[2] = {min_p.x, min_p.y, max_p.z}
        p[3] = {min_p.x, max_p.y, max_p.z}
        for i in 0..<4 do uv[i] = {p[i].z, 1.0 - p[i].y}
    }
    
    fi := group * 6 + int(face)
    base := u16(len(b.positions[fi]))
    
    if uv_rect.size.x != 0 || uv_rect.size.y != 0 {
        uv[3] = {uv_rect.pos.x, uv_rect.pos.y}
        uv[2] = {uv_rect.pos.x, uv_rect.pos.y + uv_rect.size.y}
        uv[1] = {uv_rect.pos.x + uv_rect.size.x, uv_rect.pos.y + uv_rect.size.y}
        uv[0] = {uv_rect.pos.x + uv_rect.size.x, uv_rect.pos.y}
    }
    
    for i in 0..<4 {
        append(&b.positions[fi], p[i])
        append(&b.normals[fi], norm)
        append(&b.texcoords[fi], uv[(i + int(uv_rot)) % 4])
    }
    
    // Inverted Quad triangles: 0,2,1 and 0,3,2
    append(&b.indices[fi], base, base+2, base+1)
    append(&b.indices[fi], base, base+3, base+2)
}

builder_add_inverted_box :: proc(b: ^Block_Model_Builder, min_p, max_p: [3]f32, excluded_faces: bit_set[Block_Face] = {}, group: int = 0, uv_rotations: [Block_Face]UV_Rotation = {}, uv_rects: [Block_Face]UV_Rect = {}) {
    if .Top not_in excluded_faces    do builder_add_inverted_quad(b, .Top,    {min_p.x, max_p.y, min_p.z}, {max_p.x, max_p.y, max_p.z}, group, uv_rotations[.Top], uv_rects[.Top])
    if .Bottom not_in excluded_faces do builder_add_inverted_quad(b, .Bottom, {min_p.x, min_p.y, min_p.z}, {max_p.x, min_p.y, max_p.z}, group, uv_rotations[.Bottom], uv_rects[.Bottom])
    if .North not_in excluded_faces  do builder_add_inverted_quad(b, .North,  {min_p.x, min_p.y, min_p.z}, {max_p.x, max_p.y, min_p.z}, group, uv_rotations[.North], uv_rects[.North])
    if .South not_in excluded_faces  do builder_add_inverted_quad(b, .South,  {min_p.x, min_p.y, max_p.z}, {max_p.x, max_p.y, max_p.z}, group, uv_rotations[.South], uv_rects[.South])
    if .East not_in excluded_faces   do builder_add_inverted_quad(b, .East,   {max_p.x, min_p.y, min_p.z}, {max_p.x, max_p.y, max_p.z}, group, uv_rotations[.East], uv_rects[.East])
    if .West not_in excluded_faces   do builder_add_inverted_quad(b, .West,   {min_p.x, min_p.y, min_p.z}, {min_p.x, max_p.y, max_p.z}, group, uv_rotations[.West], uv_rects[.West])
    builder_add_collision_box(b, group, min_p, max_p)
}
