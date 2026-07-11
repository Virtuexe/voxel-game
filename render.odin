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






draw_world_chunks :: proc() {
    show_wires := false
    if state.held_item != nil {
        if .WIRES_VISIBLE in items[state.held_item.?.type].flags {
            show_wires = true
        }
    }

    player_chunk := get_chunk_pos(to_vec3i(state.cam.position))
    r_dist := state.render_distance

    for dx in -r_dist..=r_dist {
        for dy in -r_dist..=r_dist {
            for dz in -r_dist..=r_dist {
                c_pos := player_chunk + {dx, dy, dz}
                if chunk, ok := state.world.chunks[c_pos]; ok {

        if chunk.is_dirty {
            chunk_build_mesh(chunk, c_pos)
        }
        
        if chunk.has_model {
            lock_uv: f32 = 0.0
            rl.SetShaderValue(block_shader, lock_uv_loc, &lock_uv, .FLOAT)
            chunk_transform := rl.MatrixTranslate(f32(c_pos.x * 16), f32(c_pos.y * 16), f32(c_pos.z * 16))
            for m_idx in 0..<chunk.model.meshCount {
                if chunk.model.meshes[m_idx].vertexCount == 0 do continue
                mat_idx := chunk.model.meshMaterial[m_idx]
                rl.DrawMesh(chunk.model.meshes[m_idx], chunk.model.materials[mat_idx], chunk_transform)
            }
        }
        
        // Also draw any dynamic tracked/animating blocks and redstone manually
        for i in chunk.dynamic_blocks {
            block_key := chunk.block_keys[i]
            block := chunk.palette[block_key]
            info := block_infos[block.type]
            tex_info := block_infos[block.type].texture

            l_pos := unflatten(i)
            global_pos := get_global_pos(c_pos, l_pos)
            p := to_vec3(global_pos)
            model_to_draw := get_block_model(block)
            
            for i in 0..<MAX_TEXTURE_GROUPS * 6 {
                group := i / 6
                face := Block_Face(i % 6)
                t_type := tex_info.textures[group][face]
                
                if block.type == .Torch && t_type == .Torch_On && !block.is_on {
                    t_type = .Torch_Off
                }
                
                t := textures[t_type]
                // We only have active meshes mapped properly if their material matches
                rl.SetMaterialTexture(&model_to_draw.materials[i], .ALBEDO, t)
            }
            animator := animator_init()
            if id, ok := world_get_tracker_id(global_pos); ok {
                if anims, ok := state.world.animations[id]; ok {
                    for i in 0..<anims.count {
                        anim := anims.list[i]
                        info := animation_infos[anim.type]
                        info.proc_(anim, &animator)
                    }
                }
            }
            
            for m_idx in 0..<model_to_draw.meshCount {
                if model_to_draw.meshes[m_idx].vertexCount == 0 do continue
                
                mat_idx := model_to_draw.meshMaterial[m_idx]
                group := int(mat_idx) / 6
                face := Block_Face(int(mat_idx) % 6)
                
                lock_uv: f32 = tex_info.lock_uv_y[group][face] ? 1.0 : 0.0
                rl.SetShaderValue(block_shader, lock_uv_loc, &lock_uv, .FLOAT)
                
                mat_transform := rl.MatrixTranslate(p.x, p.y, p.z) * animator.global_transforms[group] * model_to_draw.transform
                mesh_transform := mat_transform * animator.local_transforms[group]
                
                rl.DrawMesh(model_to_draw.meshes[m_idx], model_to_draw.materials[mat_idx], mesh_transform)
            }

            //Wire
            if show_wires && block.has_wires {
                if wires, ok := state.world.wires[global_pos]; ok {
                    for wire in wires {
                        from_center := p + get_block_center(block)
                        if tracker, exists := state.world.traked_blocks[wire.to]; exists {
                            target_pos := tracker.pos
                            target_block := world_get_block(target_pos)
                            to_center   := to_vec3(target_pos) + get_block_center(target_block)
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
                            rlgl.EnableBackfaceCulling()
                            }
                        }
                    }
                }
            }
        }
    }
    }
    }
}
}
