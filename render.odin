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
lock_uv_loc: i32

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
    out vec3 fragWorldPos;
    uniform mat4 mvp;
    uniform mat4 matModel;
    void main() {
        fragTexCoord = vertexTexCoord;
        fragColor = vertexColor;
        fragNormal = normalize(vec3(matModel * vec4(vertexNormal, 0.0)));
        fragWorldPos = vec3(matModel * vec4(vertexPosition, 1.0));
        gl_Position = mvp * vec4(vertexPosition, 1.0);
    }`
    fs := `
    #version 330
    in vec2 fragTexCoord;
    in vec4 fragColor;
    in vec3 fragNormal;
    in vec3 fragWorldPos;
    out vec4 finalColor;
    uniform sampler2D texture0;
    uniform vec4 colDiffuse;
    uniform float lockUV;
    void main() {
        vec2 uv = fragTexCoord;
        if (lockUV > 0.5 && abs(fragNormal.y) > 0.5) {
            uv = fragWorldPos.xz;
        }
        vec4 texelColor = texture(texture0, uv);
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
    lock_uv_loc = rl.GetShaderLocation(block_shader, "lockUV")
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

draw_world_chunks :: proc() {
    show_wires := false
    if state.held_item != nil {
        if .WIRES_VISIBLE in items[state.held_item.?].flags {
            show_wires = true
        }
    }

    for do_transparent in ([]bool{false, true}) {
        for c_pos, chunk in state.world.chunks {
            for block_key, i in chunk.block_keys {
                if block_key == 0 do continue
                block := chunk.palette[block_key]
                info := block_infos[block.type]
                tex_info := block_infos[block.type].texture
                
                if do_transparent != (.TEXTURE_TRANSPARENT in info.flags) do continue

                l_pos := unflatten(i)
                global_pos := get_global_pos(c_pos, l_pos)
                p := to_vec3(global_pos)
                model_to_draw := get_block_model(block)
                
                if block.type == .Redstone {
                    redstone := block.data.redstone
                    redstone_tex := get_redstone_texture(redstone.on, redstone.connections).texture
                    for i in 0..<MAX_TEXTURE_GROUPS * 6 {
                        rl.SetMaterialTexture(&model_to_draw.materials[i], .ALBEDO, redstone_tex)
                    }
                } else {
                    for i in 0..<MAX_TEXTURE_GROUPS * 6 {
                        group := i / 6
                        face := Block_Face(i % 6)
                        t_type := tex_info.textures[group][face]
                        
                        if block.type == .Torch && t_type == .Torch_On && !block.data.torch.on {
                            t_type = .Torch_Off
                        }
                        
                        t := textures[t_type]
                        // We only have active meshes mapped properly if their material matches
                        rl.SetMaterialTexture(&model_to_draw.materials[i], .ALBEDO, t)
                    }
                }
                
                offset := get_pending_move_offset(global_pos)
                mat_transform := rl.MatrixTranslate(p.x + offset.x, p.y + offset.y, p.z + offset.z) * model_to_draw.transform
                for m_idx in 0..<model_to_draw.meshCount {
                    if model_to_draw.meshes[m_idx].vertexCount == 0 do continue
                    
                    mat_idx := model_to_draw.meshMaterial[m_idx]
                    group := int(mat_idx) / 6
                    face := Block_Face(int(mat_idx) % 6)
                    
                    lock_uv: f32 = tex_info.lock_uv_y[group][face] ? 1.0 : 0.0
                    rl.SetShaderValue(block_shader, lock_uv_loc, &lock_uv, .FLOAT)
                    
                    animator := animator_init()
                    if block_infos[block.type].animate != .None {
                        block_animate_procs[block_infos[block.type].animate](block, &animator)
                    }
                    mesh_transform := mat_transform * animator.transforms[group]
                    
                    rl.DrawMesh(model_to_draw.meshes[m_idx], model_to_draw.materials[mat_idx], mesh_transform)
                }

                //Wire
                if show_wires && block.data.has_wires {
                    if wires, ok := state.world.wires[global_pos]; ok {
                        for wire in wires {
                            from_center := p + get_block_center(block)
                            target_block := world_get_block(wire.to)
                            to_center   := to_vec3(wire.to) + get_block_center(target_block)
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
                                rlgl.SetTexture(wire_model_texture.id)
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
    }
}
