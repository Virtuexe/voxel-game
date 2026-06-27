package voxel_game

import "core:strings"
import "core:fmt"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

import "core:math"
import "core:math/linalg"

import ui "./raylib-ui"

Vec2 :: rl.Vector2
Vec3 :: rl.Vector3

// Math functions moved to math.odin

screen: [2]f32
center: [2]f32

CHUNK :: [3]i32{16, 16, 16}

crosshair_texture: rl.Texture2D
// State structs moved to state.odin

main :: proc() {
    state.collider_offset = state.collider_size/2 + {0, state.collider_size.y/4, 0}
    state.last_position = state.cam.position
    //RAYLIB
    rl.SetTraceLogLevel(.WARNING)
    rl.SetWindowState({.WINDOW_RESIZABLE})
    rl.InitWindow(800, 500, "Game")
    rl.SetTargetFPS(60)
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

    crosshair_texture = rl.LoadTexture("assets/crosshair.png")
    block_init()
    gen_redstone_textures()

    world_init()

    state.block_in_hand = {.Dirt, {}}

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
            state.block_in_hand = {.Dirt, {}}
        }
        if rl.IsKeyDown(.TWO) {
            state.block_in_hand = {.Stone, {}}
        }
        if rl.IsKeyDown(.THREE) {
            state.block_in_hand = {.Cobblestone, {}}
        }
        if rl.IsKeyDown(.FOUR) {
            state.block_in_hand = {.Glass, {}}
        }
        if rl.IsKeyDown(.FIVE) {
            state.block_in_hand = {.Planks, {}}
        }
        if rl.IsKeyDown(.SIX) {
            state.block_in_hand = {.Redstone, {}}
        }
        if rl.IsKeyDown(.SEVEN) {
            state.block_in_hand = {.Slab, {}}
        }
    }

    if state.use_mouse_input {
        if rl.IsMouseButtonPressed(.LEFT) && state.has_target_block {
            world_set_block(state.target_block, Block{.Air, {}})
            raycast()
        }
        if rl.IsMouseButtonPressed(.RIGHT) && state.has_target_block {
            block_place()
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

                info := block_infos[block.type]
                model_bbox := block_model_bbox
                if info.model == .Slab {
                    model_bbox = slab_model_bbox
                } else if info.model == .Decal {
                    model_bbox = decal_model_bbox
                }
                b_min := block_pos + model_bbox.min
                b_max := block_pos + model_bbox.max

                feet_y := state.cam.position.y - state.collider_offset.y
                if i != 1 && state.is_grounded && b_max.y - feet_y <= 0.6 && b_max.y > feet_y {
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
                model_to_draw := block_model
                if info.model == .Slab {
                    model_to_draw = slab_model
                } else if info.model == .Decal {
                    model_to_draw = decal_model
                }
                
                tex := info.texture
                if block.type == .Redstone {
                    redstone := block.data.redstone
                    tex = BlockT_Cube{tex = get_redstone_texture(redstone.on, redstone.connections).texture}
                }
                
                if texture, ok := tex.(BlockT_Cube); ok {
                    rl.SetMaterialTexture(&model_to_draw.materials[0], .ALBEDO, texture.tex)
                    if info.model != .Decal do rl.SetMaterialTexture(&model_to_draw.materials[1], .ALBEDO, texture.tex)
                } else if texture, ok := tex.(BlockT_Double); ok {
                    rl.SetMaterialTexture(&model_to_draw.materials[0], .ALBEDO, texture.side)
                    if info.model != .Decal do rl.SetMaterialTexture(&model_to_draw.materials[1], .ALBEDO, texture.top)
                }
                
                rl.DrawModel(model_to_draw, p, 1, rl.WHITE)
            }
        }
    }
    
    if state.has_target_block {
        pos := to_vec3(state.target_block)
        block := world_get_block(state.target_block)
        info := block_infos[block.type]
        
        if info.model != .Decal {
            model_to_draw := info.model == .Slab ? slab_model : block_model
            bbox := info.model == .Slab ? slab_model_bbox : block_model_bbox
            model_center := (bbox.min + bbox.max) / 2.0
            adjusted_pos := pos + model_center * (1.0 - 1.001)
            
            rl.SetMaterialTexture(&model_to_draw.materials[0], .ALBEDO, white_texture)
            rl.SetMaterialTexture(&model_to_draw.materials[1], .ALBEDO, white_texture)
            
            rl.DrawModel(model_to_draw, adjusted_pos, 1.001, rl.Color{255, 255, 255, 100})
        } else {
            rl.DrawCube(pos, 1.001, 1.001, 1.001, rl.Color{255, 255, 255, 100})
        }
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

// Rendering model inits and functions moved to render.odin

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
    state.has_target_block = false

    for c_pos, chunk in world.chunks {
        for block_key, i in chunk.block_keys {
            if block_key == 0 do continue
            l_pos := unflatten(i)
            global_pos := get_global_pos(c_pos, l_pos)
            block_pos := to_vec3(global_pos)
            
            info := block_infos[chunk.palette[block_key].type]
            model_bbox := block_model_bbox
            if info.model == .Slab {
                model_bbox = slab_model_bbox
            } else if info.model == .Decal {
                model_bbox = decal_model_bbox
            }
            
            bbox := rl.BoundingBox{block_pos + model_bbox.min, block_pos + model_bbox.max}

            hit := rl.GetRayCollisionBox(ray, bbox)

            if hit.hit && hit.distance < closest_hit.distance {
                closest_hit = hit
                state.has_target_block = true
                state.target_block = global_pos
                state.place_block = block_pos + closest_hit.normal
                state.place_block_index = from_vec3(state.place_block)
            }
        }
    }
    if state.has_target_block {
        pos := to_vec3(state.target_block)
        normal := fix_normal(closest_hit.normal)
        local_hit := closest_hit.point - pos
        face_hit := local_hit - local_hit*normal*normal
        face_normal := fix_normal(face_hit)

        state.place_block_face_normal = normal
        state.place_block_face = normal_to_face(normal)
        state.place_block_direction_normal = face_normal
        state.place_block_direction_normal_2d = ignore_normal(normal, face_normal)
        state.place_block_direction = normal_to_direction(state.place_block_direction_normal_2d)
    }
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
    model_bbox := block_model_bbox
    if info.model == .Slab {
        model_bbox = slab_model_bbox
    } else if info.model == .Decal {
        model_bbox = decal_model_bbox
    }
    
    b_min := block_pos + model_bbox.min
    b_max := block_pos + model_bbox.max
    
    overlap_x := min(p_max.x, b_max.x) - max(p_min.x, b_min.x)
    overlap_y := min(p_max.y, b_max.y) - max(p_min.y, b_min.y)
    overlap_z := min(p_max.z, b_max.z) - max(p_min.z, b_min.z)
    
    return overlap_x > 0.001 && overlap_y > 0.001 && overlap_z > 0.001
}
is_overlapping_at :: proc(player: Vec3, global_pos: [3]i32) -> bool {
    return is_overlapping(player, global_pos, world_get_block(global_pos))
}

