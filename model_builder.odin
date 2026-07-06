package voxel_game

import rl "vendor:raylib"

Block_Model_Builder :: struct {
    positions: [6][dynamic][3]f32,
    normals:   [6][dynamic][3]f32,
    texcoords: [6][dynamic][2]f32,
    indices:   [6][dynamic]u16,
    collision_bboxes: [dynamic]rl.BoundingBox,
}

builder_init :: proc() -> Block_Model_Builder {
    return Block_Model_Builder{}
}

builder_destroy :: proc(b: ^Block_Model_Builder) {
    for i in 0..<6 {
        delete(b.positions[i])
        delete(b.normals[i])
        delete(b.texcoords[i])
        delete(b.indices[i])
    }
    delete(b.collision_bboxes)
}

builder_add_collision_box :: proc(b: ^Block_Model_Builder, min_p, max_p: [3]f32) {
    append(&b.collision_bboxes, rl.BoundingBox{min_p, max_p})
}

// Accurately calculates bounding box from only the generated vertices
// (Fixes rl.GetModelBoundingBox returning origin {0,0,0} for empty meshes)
builder_get_visual_bbox :: proc(b: ^Block_Model_Builder) -> rl.BoundingBox {
    has_verts := false
    min_p := [3]f32{99999, 99999, 99999}
    max_p := [3]f32{-99999, -99999, -99999}
    
    for i in 0..<6 {
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
builder_build :: proc(b: ^Block_Model_Builder) -> rl.Model {
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
        
        mesh := &model.meshes[i]
        vcount := len(b.positions[i])
        tcount := len(b.indices[i]) / 3
        mesh.vertexCount = i32(vcount)
        mesh.triangleCount = i32(tcount)
        
        if vcount > 0 {
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
        }
        rl.UploadMesh(mesh, false)
    }
    
    return model
}

// Adds a single rectangular quad for a specific face.
// `min_p` and `max_p` should describe a 2D bounds (i.e. one dimension is the same in both).
builder_add_quad :: proc(b: ^Block_Model_Builder, face: Block_Face, min_p, max_p: [3]f32) {
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
    
    fi := int(face)
    base := u16(len(b.positions[fi]))
    for i in 0..<4 {
        append(&b.positions[fi], p[i])
        append(&b.normals[fi], norm)
        append(&b.texcoords[fi], uv[i])
    }
    // Quad triangles: 0,1,2 and 0,2,3
    append(&b.indices[fi], base, base+1, base+2)
    append(&b.indices[fi], base, base+2, base+3)
}

// Automatically builds a box adding 6 outer quads (unless faces are excluded)
builder_add_box :: proc(b: ^Block_Model_Builder, min_p, max_p: [3]f32, visible_faces: bit_set[Block_Face] = {.Top, .Bottom, .North, .South, .East, .West}) {
    if .Top in visible_faces    do builder_add_quad(b, .Top,    {min_p.x, max_p.y, min_p.z}, {max_p.x, max_p.y, max_p.z})
    if .Bottom in visible_faces do builder_add_quad(b, .Bottom, {min_p.x, min_p.y, min_p.z}, {max_p.x, min_p.y, max_p.z})
    if .North in visible_faces  do builder_add_quad(b, .North,  {min_p.x, min_p.y, min_p.z}, {max_p.x, max_p.y, min_p.z})
    if .South in visible_faces  do builder_add_quad(b, .South,  {min_p.x, min_p.y, max_p.z}, {max_p.x, max_p.y, max_p.z})
    if .East in visible_faces   do builder_add_quad(b, .East,   {max_p.x, min_p.y, min_p.z}, {max_p.x, max_p.y, max_p.z})
    if .West in visible_faces   do builder_add_quad(b, .West,   {min_p.x, min_p.y, min_p.z}, {min_p.x, max_p.y, max_p.z})
    builder_add_collision_box(b, min_p, max_p)
}
