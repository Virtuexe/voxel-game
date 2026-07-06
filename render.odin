package voxel_game

import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"
import "core:math/linalg"
import "core:slice"
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

init_block_model :: proc() {
    b := builder_init()
    defer builder_destroy(&b)
    builder_add_box(&b, {0, 0, 0}, {1, 1, 1})
    m := builder_build(&b)
    block_models[.Cube] = {
        model = m,
        visual_bbox = builder_get_visual_bbox(&b),
        collision_bboxes = slice.clone(b.collision_bboxes[:]),
    }
}

init_slab_model :: proc() {
    b := builder_init()
    defer builder_destroy(&b)
    builder_add_box(&b, {0, 0, 0}, {1, 0.5, 1})
    m := builder_build(&b)
    block_models[.Slab] = {
        model = m,
        visual_bbox = builder_get_visual_bbox(&b),
        collision_bboxes = slice.clone(b.collision_bboxes[:]),
    }
}

init_decal_model :: proc() {
    b := builder_init()
    defer builder_destroy(&b)
    // Decal sits slightly above y=0 to prevent z-fighting
    builder_add_quad(&b, .Top, {0, 0.001, 0}, {1, 0.001, 1})
    builder_add_collision_box(&b, {0, 0, 0}, {1, 0.01, 1})
    m := builder_build(&b)
    block_models[.Decal] = {
        model = m,
        visual_bbox = builder_get_visual_bbox(&b),
        collision_bboxes = slice.clone(b.collision_bboxes[:]),
    }
    
    img := rl.GenImageColor(1, 1, rl.WHITE)
    white_texture = rl.LoadTextureFromImage(img)
    rl.UnloadImage(img)
}

init_stairs_model :: proc() {
    b := builder_init()
    defer builder_destroy(&b)

    // ------- Bottom face (y=0, full 1×1) normal -Y -------
    builder_add_quad(&b, .Bottom, {0, 0, 0}, {1, 0, 1})
    
    // ------- Back face (z=0, full 1×1) normal -Z -------
    builder_add_quad(&b, .North, {0, 0, 0}, {1, 1, 0})
    
    // ------- Front lower (z=1, y=0..0.5, 1×0.5) normal +Z -------
    builder_add_quad(&b, .South, {0, 0, 1}, {1, 0.5, 1})
    
    // ------- Step riser (z=0.5, y=0.5..1, 1×0.5) normal +Z -------
    builder_add_quad(&b, .South, {0, 0.5, 0.5}, {1, 1, 0.5})
    
    // ------- Tread top (y=0.5, z=0.5..1, 1×0.5 depth) normal +Y -------
    builder_add_quad(&b, .Top, {0, 0.5, 0.5}, {1, 0.5, 1})
    
    // ------- Cap top (y=1, z=0..0.5, 1×0.5 depth) normal +Y -------
    builder_add_quad(&b, .Top, {0, 1, 0}, {1, 1, 0.5})
    
    // ------- Left lower (x=0, y=0..0.5, z full, 1×0.5) normal -X -------
    builder_add_quad(&b, .West, {0, 0, 0}, {0, 0.5, 1})
    
    // ------- Left upper (x=0, y=0.5..1, z=0..0.5, 0.5×0.5) normal -X -------
    builder_add_quad(&b, .West, {0, 0.5, 0}, {0, 1, 0.5})
    
    // ------- Right lower (x=1, y=0..0.5, z full, 1×0.5) normal +X -------
    builder_add_quad(&b, .East, {1, 0, 0}, {1, 0.5, 1})
    
    // ------- Right upper (x=1, y=0.5..1, z=0..0.5, 0.5×0.5) normal +X -------
    builder_add_quad(&b, .East, {1, 0.5, 0}, {1, 1, 0.5})
    
    builder_add_collision_box(&b, {0, 0, 0}, {1, 0.5, 1})
    builder_add_collision_box(&b, {0, 0.5, 0}, {1, 1, 0.5})
    
    m := builder_build(&b)
    block_models[.Stairs] = {
        model = m,
        visual_bbox = builder_get_visual_bbox(&b),
        collision_bboxes = slice.clone(b.collision_bboxes[:]),
    }
}

init_piston_head_model :: proc() {
    b := builder_init()
    defer builder_destroy(&b)
    
    // The pushing face/base (y=0 to y=0.25)
    builder_add_box(&b, {0, 0, 0}, {1, 0.25, 1})
    // The arm (y=0.25 to y=1.0)
    builder_add_box(&b, {0.375, 0.25, 0.375}, {0.625, 1.25, 0.625})
    
    m := builder_build(&b)
    block_models[.PistonHead] = {
        model = m,
        visual_bbox = builder_get_visual_bbox(&b),
        collision_bboxes = slice.clone(b.collision_bboxes[:]),
    }
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

draw_world_chunks :: proc(state: ^State) {
    for do_transparent in ([]bool{false, true}) {
        for c_pos, chunk in state.world.chunks {
            for block_key, i in chunk.block_keys {
                if block_key == 0 do continue
                block := chunk.palette[block_key]
                info := block_infos[block.type]
                if do_transparent != (.TEXTURE_TRANSPARENT in info.flags) do continue

                l_pos := unflatten(i)
                global_pos := get_global_pos(c_pos, l_pos)
                p := to_vec3(global_pos)
                model_to_draw := get_block_model(block)
                
                if block.type == .Redstone {
                    redstone := block.data.redstone
                    redstone_tex := get_redstone_texture(redstone.on, redstone.connections).texture
                    for i in 0..<6 {
                        rl.SetMaterialTexture(&model_to_draw.materials[i], .ALBEDO, redstone_tex)
                    }
                } else {
                    for face in Block_Face {
                        t := block_textures[info.textures[face]]
                        rl.SetMaterialTexture(&model_to_draw.materials[int(face)], .ALBEDO, t)
                    }
                }
                
                rl.DrawModel(model_to_draw, p, 1, rl.WHITE)

                //Arrow
                if arrow, ok := block.data.arrow.(Arrow); ok {
                    from_center := p
                    to_center   := to_vec3(arrow.to)
                    diff        := to_center - from_center
                    total_dist  := linalg.length(diff)
                    if total_dist > 0.001 {
                        dir       := diff / total_dist
                        tile_size : f32 = 0.5
                        num_tiles := int(total_dist / tile_size)
                        step      := total_dist / f32(max(num_tiles, 1))
                        half      := tile_size * 0.5
                        // Pick a reference vector not parallel to dir to build stable quad axes
                        ref       := Vec3{0, 1, 0} if abs(dir.y) < 0.99 else Vec3{0, 0, 1}
                        right     := linalg.normalize(linalg.cross(dir, ref))
                        up        := linalg.normalize(linalg.cross(right, dir))

                        rlgl.DisableBackfaceCulling()
                        rlgl.SetTexture(arrow_texture.id)
                        rlgl.Begin(rlgl.QUADS)
                        rlgl.Color4ub(255, 255, 255, 255)
                        for t in 0..=num_tiles {
                            c := from_center + dir * (f32(t) * step + step * 0.5)
                            // Quad corners: U axis = dir, V axis = up (perpendicular to dir)
                            bl := c - dir*half - up*half
                            br := c + dir*half - up*half
                            tr := c + dir*half + up*half
                            tl := c - dir*half + up*half
                            // Front face
                            rlgl.TexCoord2f(0, 1); rlgl.Vertex3f(bl.x, bl.y, bl.z)
                            rlgl.TexCoord2f(1, 1); rlgl.Vertex3f(br.x, br.y, br.z)
                            rlgl.TexCoord2f(1, 0); rlgl.Vertex3f(tr.x, tr.y, tr.z)
                            rlgl.TexCoord2f(0, 0); rlgl.Vertex3f(tl.x, tl.y, tl.z)
                            // Back face (mirrored U so texture reads correctly from behind)
                            rlgl.TexCoord2f(1, 1); rlgl.Vertex3f(br.x, br.y, br.z)
                            rlgl.TexCoord2f(0, 1); rlgl.Vertex3f(bl.x, bl.y, bl.z)
                            rlgl.TexCoord2f(0, 0); rlgl.Vertex3f(tl.x, tl.y, tl.z)
                            rlgl.TexCoord2f(1, 0); rlgl.Vertex3f(tr.x, tr.y, tr.z)
                        }
                        rlgl.End()
                        rlgl.SetTexture(0)
                        rlgl.EnableBackfaceCulling()
                    }
                }
            }
        }
    }
}
