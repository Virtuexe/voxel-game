package voxel_game

import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

update_player :: proc(delta: f32) {
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
            bbox_buf: [8]rl.BoundingBox
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

    //RAYCAST
    raycast()

    //INTERACTION
    if state.use_key_input {
        if rl.IsKeyPressed(.ONE) { state.hotbar_index = 0 }
        if rl.IsKeyPressed(.TWO) { state.hotbar_index = 1 }
        if rl.IsKeyPressed(.THREE) { state.hotbar_index = 2 }
        if rl.IsKeyPressed(.FOUR) { state.hotbar_index = 3 }
        if rl.IsKeyPressed(.FIVE) { state.hotbar_index = 4 }
        if rl.IsKeyPressed(.SIX) { state.hotbar_index = 5 }
        if rl.IsKeyPressed(.SEVEN) { state.hotbar_index = 6 }
        if rl.IsKeyPressed(.EIGHT) { state.hotbar_index = 7 }
        if rl.IsKeyPressed(.NINE) { state.hotbar_index = 8 }
        state.held_item = state.hotbar[state.hotbar_index]
    }
    
    if state.use_mouse_input {
        scroll := rl.GetMouseWheelMove()
        if scroll > 0 {
            state.hotbar_index -= 1
            if state.hotbar_index < 0 do state.hotbar_index = 8
            state.held_item = state.hotbar[state.hotbar_index]
        } else if scroll < 0 {
            state.hotbar_index += 1
            if state.hotbar_index > 8 do state.hotbar_index = 0
            state.held_item = state.hotbar[state.hotbar_index]
        }

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
                if state.held_item != nil {
                    item := items[state.held_item.?]
                    if item.on_right_click != nil do item.on_right_click()
                }
            }
        }
    }
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

is_overlapping :: proc(player: Vec3, block_pos: [3]i32, block: Block) -> bool {
    if block == {.Air, {}} do return false
    info := block_infos[block.type]
    if .NO_COLLISION in info.flags do return false
    block_pos := to_vec3(block_pos)

    p_min := player - state.collider_offset
    p_max := p_min + state.collider_size

    // Test against each sub-bbox (2 for stairs, 1 for everything else)
    bbox_buf: [8]rl.BoundingBox
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

closest_hit: rl.RayCollision

raycast :: proc() {
    //TODO closest hit normal can hit face diagonally
    center := Vec2{f32(screen.x/2), f32(screen.y/2)}
    ray := rl.GetScreenToWorldRay(center, state.cam)

    closest_hit = rl.RayCollision{ distance = 5.0 }
    state.looking_at_block = false

    for c_pos, chunk in state.world.chunks {
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
        block := get_target_block()
        normal := fix_normal(closest_hit.normal)
        local_hit := closest_hit.point - (pos + get_block_center(block))
        face_hit := local_hit - local_hit*normal*normal
        face_normal := fix_normal(face_hit)

        state.hit_normal = normal
        state.hit_face = normal_to_face(-normal)
        state.place_dir_normal = face_normal
        state.place_dir_normal_2d = ignore_normal(normal, face_normal)
        state.place_dir = normal_to_direction(state.place_dir_normal_2d)
    }
}

draw_player_target_box :: proc() {
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
