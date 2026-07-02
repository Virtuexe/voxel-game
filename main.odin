package voxel_game

import "core:strings"
import "core:fmt"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

import "core:math"
import "core:math/linalg"

import ui "./raylib-ui"

get_block_transform :: proc(block: Block) -> rl.Matrix {
    info := block_infos[block.type]
    rot_mat := rl.MatrixRotateX(0)
    
    if .HAS_CARDINAL in info.flags {
        angle: f32 = 0
        switch block.data.direction {
        case .North: angle = 0
        case .East: angle = -rl.PI/2
        case .South: angle = rl.PI
        case .West: angle = rl.PI/2
        }
        if angle != 0 do rot_mat = rl.MatrixRotateY(angle) * rot_mat
    }
    
    if .HAS_BLOCK_FACE in info.flags {
        angle: f32 = 0
        axis := Vec3{1,0,0}
        switch block.data.facing {
        case .Bottom: angle = 0; axis = {1,0,0}
        case .Top: angle = rl.PI; axis = {1,0,0}
        case .South: angle = -rl.PI/2; axis = {1,0,0}
        case .North: angle = rl.PI/2; axis = {1,0,0}
        case .East: angle = rl.PI/2; axis = {0,0,1}
        case .West: angle = -rl.PI/2; axis = {0,0,1}
        }
        if angle != 0 do rot_mat = rl.MatrixRotate(axis, angle) * rot_mat
    }
    
    return rot_mat
}

Vec2 :: rl.Vector2
Vec3 :: rl.Vector3

// Math functions moved to math.odin

screen: [2]f32
center: [2]f32

CHUNK :: [3]i32{16, 16, 16}

arrow_texture: rl.Texture2D
crosshair_texture: rl.Texture2D
// State structs moved to state.odin

main :: proc() {
    state.collider_offset = state.collider_size/2 + {0, state.collider_size.y/4, 0}
    state.last_position = state.cam.position
    //RAYLIB
    rl.SetTraceLogLevel(.WARNING)
    rl.SetWindowState({.WINDOW_RESIZABLE})
    rl.InitWindow(800, 500, "Game")
    rl.SetTargetFPS(120)
    rl.SetExitKey(rl.KeyboardKey.KEY_NULL)

    init()

    for !rl.WindowShouldClose() {        
        update()
        rl.BeginDrawing()
        draw()
        rl.EndDrawing()
    }

    rl.UnloadTexture(crosshair_texture)
    for texture in redstone_render_texture {
        rl.UnloadRenderTexture(texture)
    }
    rl.UnloadModel(block_model)
    rl.CloseWindow()
}

init :: proc() {
    calc_window()

    arrow_texture = rl.LoadTexture("assets/arrow.png")
    crosshair_texture = rl.LoadTexture("assets/crosshair.png")
    block_init()
    gen_redstone_textures()

    world_init()

    state.held_block = {.Dirt, {}}

    state.apply_gravity = true
    state.is_flying = false
    state.can_jump = true
    init_code()
}

is_player_colliding :: proc(pos: Vec3) -> bool {
    center := [3]i32{
        i32(math.floor(pos.x)), 
        i32(math.floor(pos.y - state.collider_offset.y)), 
        i32(math.floor(pos.z))
    }
    it := make_player_block_iterator(center)
    for block, global_pos in player_block_iterator_next(&it) {
        if is_overlapping(pos, global_pos, block) {
            return true
        }
    }
    return false
}

is_player_supported :: proc(pos: Vec3) -> bool {
    test_pos := pos
    test_pos.y -= 0.05
    return is_player_colliding(test_pos)
}

update :: proc() {
    calc_window()
    delta := get_delta()
    //ESC+
    state.mouse_lock = true
    state.use_key_input = true
    state.use_mouse_input = true
    if rl.IsKeyPressed(.ESCAPE) {
        state.in_menu = !state.in_menu
    }
    if state.in_menu || state.code.in_code {
        state.mouse_lock = false
        state.use_mouse_input = false
    }
    if rl.IsKeyPressed(.F3) {
        state.show_debug = !state.show_debug
    }
    //LOOK
    if state.mouse_lock {
        mouse_delta := rl.GetMouseDelta()
        state.yaw += mouse_delta.x * state.mouse_sensitivity
        state.pitch -= mouse_delta.y * state.mouse_sensitivity
        state.pitch = clamp(state.pitch, -89.9, 89.9)
    }
    yaw_rad := state.yaw * rl.DEG2RAD
    pitch_rad := state.pitch * rl.DEG2RAD
    up := Vec3{0,1,0}
    forward := Vec3 {
        math.cos_f32(pitch_rad) * math.cos_f32(yaw_rad),
        math.sin_f32(pitch_rad),
        math.cos_f32(pitch_rad) * math.sin_f32(yaw_rad),
    }
    forward_move := linalg.normalize0(Vec3{forward.x, 0, forward.z})
    right_move := linalg.normalize0(linalg.vector_cross3(forward_move, up))
    if state.mouse_lock {
        rl.HideCursor()
        rl.SetMousePosition(i32(screen.x/2), i32(screen.y/2))
    }
    else {
        rl.ShowCursor()
    }
    state.forward = forward
    //RAYCAST
    raycast()
    //INTERACTION
    if state.use_key_input {
        if rl.IsKeyDown(.ONE) {
            state.held_block = {.Dirt, {}}
        }
        if rl.IsKeyDown(.TWO) {
            state.held_block = {.Stone, {}}
        }
        if rl.IsKeyDown(.THREE) {
            state.held_block = {.Cobblestone, {}}
        }
        if rl.IsKeyDown(.FOUR) {
            state.held_block = {.Glass, {}}
        }
        if rl.IsKeyDown(.FIVE) {
            state.held_block = {.Planks, {}}
        }
        if rl.IsKeyDown(.SIX) {
            state.held_block = {.Redstone, {}}
        }
        if rl.IsKeyDown(.SEVEN) {
            state.held_block = {.Slab, {}}
        }
        if rl.IsKeyDown(.EIGHT) {
            state.held_block = {.Stairs, {}}
        }
    }

    if state.use_mouse_input {
        if rl.IsMouseButtonPressed(.LEFT) && state.looking_at_block {
            set_target_block(Block{.Air, {}})
            raycast()
        }
        if rl.IsMouseButtonPressed(.RIGHT) && state.looking_at_block {
            if state.is_shifting && state.looking_at_block {
                if pos, ok := state.select_block_pos.([3]i32); ok {
                    block := world_get_block(pos)
                    block.data.arrow = Arrow{state.look_target}
                    world_set_block(pos, block)
                    state.select_block_pos = nil
                }
                else {
                    state.select_block_pos = state.look_target
                }
            }
            else {
                block_place()
            }
        }
    }
    //MOVEMENT
    state.is_shifting = rl.IsKeyDown(.LEFT_SHIFT) && state.use_key_input
    move_speed := state.move_speed
    if state.is_shifting {
        move_speed *= 0.5
        state.collider_size.y = 1.5
    } else {
        if rl.IsKeyDown(.LEFT_CONTROL) {
            move_speed *= 1.5
        }
        state.collider_size.y = 2.0
    }
    wasd: Vec3
    if state.use_key_input do wasd = get_wasd_input(forward_move, right_move, up)
    movement := wasd * delta * move_speed
    if state.apply_gravity {
        state.velocity.y -= state.gravity * delta
    }
    if rl.IsKeyPressed(.SPACE) && state.is_grounded && state.can_jump && state.use_key_input {
        state.velocity.y = state.jump_strength
    }
    movement += state.velocity * delta
    //COLLISION
    was_grounded := state.is_grounded
    state.is_grounded = false
    for i in 0..<3 {
        if state.is_shifting && was_grounded && !state.is_flying && i != 1 {
            test_pos := state.cam.position
            test_pos[i] += movement[i]
            if !is_player_supported(test_pos) {
                movement[i] = 0
            }
        }
        state.cam.position[i] += movement[i]
        center := [3]i32{
            i32(math.floor(state.cam.position.x)), 
            i32(math.floor(state.cam.position.y - state.collider_offset.y)), 
            i32(math.floor(state.cam.position.z))
        }
        it := make_player_block_iterator(center)
        for block, global_pos in player_block_iterator_next(&it) {
            block_pos := to_vec3(global_pos)
            if !is_overlapping(state.cam.position, global_pos, block) do continue

            feet_y := state.cam.position.y - state.collider_offset.y
            bbox_buf: [2]rl.BoundingBox
            bboxes := get_block_bboxes(block, &bbox_buf)
            for model_bbox in bboxes {
                b_min := block_pos + model_bbox.min
                b_max := block_pos + model_bbox.max

                // Quick per-box overlap check
                p_min := state.cam.position - state.collider_offset
                p_max := p_min + state.collider_size
                if min(p_max.x,b_max.x)-max(p_min.x,b_min.x) <= 0.001 do continue
                if min(p_max.y,b_max.y)-max(p_min.y,b_min.y) <= 0.001 do continue
                if min(p_max.z,b_max.z)-max(p_min.z,b_min.z) <= 0.001 do continue

                if i != 1 && was_grounded && b_max.y - feet_y <= 0.6 && b_max.y > feet_y {
                    test_pos := state.cam.position
                    test_pos.y = b_max.y + state.collider_offset.y
                    if !is_player_colliding(test_pos) {
                        state.cam.position.y = test_pos.y
                        continue
                    }
                }

                if movement[i] < 0 {
                    state.cam.position[i] = b_max[i] + state.collider_offset[i]
                } else if movement[i] > 0 {
                    state.cam.position[i] = b_min[i] + state.collider_offset[i] - state.collider_size[i]
                }

                movement[i] = 0
                if i == 1 {
                    state.is_grounded = true
                    state.velocity.y = 0
                }
                break
            }
        }
    }
    state.last_position = state.cam.position
    state.cam.target = state.cam.position + forward

    update_code()
}
draw :: proc() {
    rl.ClearBackground(rl.BLACK)
    rl.BeginMode3D(state.cam)
    rl.BeginBlendMode(.ALPHA)

    //3D
    for do_transparent in ([]bool{false, true}) {
        for c_pos, chunk in world.chunks {
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
                    rl.SetMaterialTexture(&model_to_draw.materials[0], .ALBEDO, redstone_tex)
                    if info.model != .Decal && info.model != .Stairs do rl.SetMaterialTexture(&model_to_draw.materials[1], .ALBEDO, redstone_tex)
                } else {
                    if info.model == .Decal {
                        t := block_textures[info.textures[.Top]].texture
                        rl.SetMaterialTexture(&model_to_draw.materials[0], .ALBEDO, t)
                    } else {
                        for face in Block_Face {
                            t := block_textures[info.textures[face]].texture
                            rl.SetMaterialTexture(&model_to_draw.materials[int(face)], .ALBEDO, t)
                        }
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
    
    if state.looking_at_block {
        pos := to_vec3(state.look_target)
        block := get_target_block()
        
        bbox := get_block_bbox(block)
        
        // Expand slightly to prevent Z-fighting with the block itself, accounting for line thickness
        t: f32 = 0.01
        epsilon: f32 = 0//t / 2.0 + 0.001
        bbox.min += pos - epsilon
        bbox.max += pos + epsilon
        
        draw_bounding_box_thick(bbox, t, rl.Color{0, 0, 0, 150})
    }
    if state.show_debug {
        draw_xyz()
    }
    rl.EndMode3D()

    //UI
    rl.BeginMode2D(state.ui_cam)
    
    if !state.show_debug {
        crosshair := ui.Rec{{}, ui.vmin(screen)/15}
        crosshair.pos = center-crosshair.size/2
        ui.draw_rec_texture(crosshair, crosshair_texture)
    }
    else {
        text := fmt.aprint(
            "position: ", state.cam.position, "\n",
            allocator = context.temp_allocator
        )
        rl.DrawText(strings.clone_to_cstring(text, context.temp_allocator), 0, 0, i32(ui.vmin(screen)/30), rl.WHITE)
    }

    rl.EndMode2D()

    draw_code()
}

get_delta :: proc() -> f32 {
    return min(0.14, rl.GetFrameTime())
}
calc_window :: proc() {
    screen = Vec2{f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}
    center = screen/2
}

closest_hit: rl.RayCollision
raycast :: proc() {
    //TODO closest hit normal can hit face diagonally
    center := Vec2{f32(screen.x/2), f32(screen.y/2)}
    ray := rl.GetScreenToWorldRay(center, state.cam)

    closest_hit = rl.RayCollision{ distance = 5.0 }
    state.looking_at_block = false

    for c_pos, chunk in world.chunks {
        for block_key, i in chunk.block_keys {
            if block_key == 0 do continue
            l_pos := unflatten(i)
            global_pos := get_global_pos(c_pos, l_pos)
            block_pos := to_vec3(global_pos)
            
            block := chunk.palette[block_key]
            model_bbox := get_block_bbox(block)
            bbox := rl.BoundingBox{block_pos + model_bbox.min, block_pos + model_bbox.max}

            hit := rl.GetRayCollisionBox(ray, bbox)

            if hit.hit && hit.distance < closest_hit.distance {
                closest_hit = hit
                state.looking_at_block = true
                state.look_target = global_pos
                state.place_pos = block_pos + closest_hit.normal
                state.place_target = from_vec3(state.place_pos)
            }
        }
    }
    if state.looking_at_block {
        pos := to_vec3(state.look_target)
        normal := fix_normal(closest_hit.normal)
        local_hit := closest_hit.point - pos
        face_hit := local_hit - local_hit*normal*normal
        face_normal := fix_normal(face_hit)

        state.hit_normal = normal
        state.hit_face = normal_to_face(-normal)
        state.place_dir_normal = face_normal
        state.place_dir_normal_2d = ignore_normal(normal, face_normal)
        state.place_dir = normal_to_direction(state.place_dir_normal_2d)
    }
}

draw_bounding_box_thick :: proc(bbox: rl.BoundingBox, t: f32, color: rl.Color) {
    min := bbox.min
    max := bbox.max
    cx := (min.x + max.x) / 2.0
    cy := (min.y + max.y) / 2.0
    cz := (min.z + max.z) / 2.0
    
    wx := max.x - min.x + t
    wy := max.y - min.y + t
    wz := max.z - min.z + t
    
    // Bottom edges
    rl.DrawCubeV({cx, min.y, min.z}, {wx, t, t}, color)
    rl.DrawCubeV({cx, min.y, max.z}, {wx, t, t}, color)
    rl.DrawCubeV({min.x, min.y, cz}, {t, t, wz}, color)
    rl.DrawCubeV({max.x, min.y, cz}, {t, t, wz}, color)
    
    // Top edges
    rl.DrawCubeV({cx, max.y, min.z}, {wx, t, t}, color)
    rl.DrawCubeV({cx, max.y, max.z}, {wx, t, t}, color)
    rl.DrawCubeV({min.x, max.y, cz}, {t, t, wz}, color)
    rl.DrawCubeV({max.x, max.y, cz}, {t, t, wz}, color)
    
    // Vertical edges
    rl.DrawCubeV({min.x, cy, min.z}, {t, wy, t}, color)
    rl.DrawCubeV({max.x, cy, min.z}, {t, wy, t}, color)
    rl.DrawCubeV({min.x, cy, max.z}, {t, wy, t}, color)
    rl.DrawCubeV({max.x, cy, max.z}, {t, wy, t}, color)
}

draw_xyz :: proc() {
    position := state.cam.target - state.forward*0.9
    length: f32 = 0.02
    
    rl.DrawLine3D(position, position+length*Vec3{1,0,0}, rl.RED)
    rl.DrawLine3D(position, position+length*Vec3{0,1,0}, rl.GREEN)
    rl.DrawLine3D(position, position+length*Vec3{0,0,1}, rl.BLUE)
}
get_wasd_input :: proc(forward, right, up: Vec3) -> (wasd:Vec3) {
    Key_Vec :: struct{key: rl.KeyboardKey, pos: Vec3}
    key_vec_move := []Key_Vec {
        {.W, forward},
        {.S, -forward},
        {.D, right},
        {.A, -right},
    }
    key_vec_fly := []Key_Vec {
        {.SPACE, up},
        {.LEFT_SHIFT, -up},
    }
    for item in key_vec_move {
        if rl.IsKeyDown(item.key) {
            wasd += item.pos
        } 
    }
    if state.is_flying do for item in key_vec_fly {
        if rl.IsKeyDown(item.key) {
            wasd += item.pos
        }
    }
    wasd = linalg.normalize0(wasd)
    return
}
is_overlapping :: proc(player: Vec3, block_pos: [3]i32, block: Block) -> bool {
    if block == {.Air, {}} do return false
    info := block_infos[block.type]
    if .NO_COLLISION in info.flags do return false
    block_pos := to_vec3(block_pos)

    p_min := player - state.collider_offset
    p_max := p_min + state.collider_size

    // Test against each sub-bbox (2 for stairs, 1 for everything else)
    bbox_buf: [2]rl.BoundingBox
    for model_bbox in get_block_bboxes(block, &bbox_buf) {
        b_min := block_pos + model_bbox.min
        b_max := block_pos + model_bbox.max
        if min(p_max.x,b_max.x)-max(p_min.x,b_min.x) > 0.001 &&
           min(p_max.y,b_max.y)-max(p_min.y,b_min.y) > 0.001 &&
           min(p_max.z,b_max.z)-max(p_min.z,b_min.z) > 0.001 {
            return true
        }
    }
    return false
}
is_overlapping_at :: proc(player: Vec3, global_pos: [3]i32) -> bool {
    return is_overlapping(player, global_pos, world_get_block(global_pos))
}

