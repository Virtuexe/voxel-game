package voxel_game

import "core:fmt"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

import "core:math"
import "core:math/linalg"

Vec2 :: rl.Vector2
Vec3 :: rl.Vector3

Block_Type :: enum {
    Air, Dirt, Stone
}

screen: [2]i32

CHUNK :: [3]i32{16, 16, 16}

block_mesh: rl.Mesh
block_model: rl.Model
blocks: [16*16*16]Block_Type
block_paths := #partial [Block_Type]cstring {
    .Dirt = "assets/dirt.png",
    .Stone = "assets/stone.png",
}
block_textures: [Block_Type]rl.Texture2D
State :: struct {
    cam: rl.Camera3D,
    //MOVEMENT & LOOK
    //rules
    apply_gravity: bool,
    is_flying: bool,
    can_jump: bool,
    move_speed: f32,
    gravity: f32,
    jump_strength: f32,
    //current
    is_grounded: bool,
    velocity: Vec3,
    yaw: f32,
    pitch: f32,
    //INPUT
    mouse_sensitivity: f32,
    in_menu: bool,
    use_key_input: bool,
    use_mouse_input: bool,
    mouse_lock: bool,
    //INTERACTION
    block_in_hand: Block_Type,
    target_block: int,
    place_block: int,
    //COLLISION
    collider_size: Vec3,
    collider_offset: Vec3,
    last_position: Vec3,
}
state := State {
    cam = {
        position = {0, 5, 0},
        up       = {0, 1, 0},
        fovy     = 90,
        projection = .PERSPECTIVE,
    },
    //MOVEMENT & LOOK
    //rulles
    move_speed = 4.3,
    gravity = 32,
    jump_strength = 8.4,
    //curent
    yaw = 90,
    //INPUT
    mouse_sensitivity = 0.1,
    in_menu = false,
    use_key_input = true,
    use_mouse_input = true,
    //INTECATION
    target_block = -1,
    //COLLIDER
    collider_size = Vec3{0.5, 2, 0.5},
}

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

    for block in Block_Type {
        rl.UnloadTexture(block_textures[block])
    }
    rl.UnloadModel(block_model)
    rl.CloseWindow()
}

init :: proc() {
    block_mesh = rl.GenMeshPlane(1, 1, 1, 1)
    block_model = rl.LoadModelFromMesh(block_mesh)
    for block in Block_Type {
        if block == .Air do continue
        block_textures[block] = rl.LoadTexture(block_paths[block])
    }

    for i in 0..<16*16 {
        x: i32 = i32(i/16)
        z: i32 = i32(i%16)
        blocks[flatten({x, 0, z})] = .Stone
        blocks[flatten({x, 1, z})] = .Dirt
    }

    state.block_in_hand = .Dirt

    state.apply_gravity = true
    state.is_flying = false
    state.can_jump = true
}

update :: proc() {
    screen = [2]i32{rl.GetScreenWidth(), rl.GetScreenHeight()}
    delta := rl.GetFrameTime()
    //ESC
    state.mouse_lock = true
    state.use_key_input = true
    state.use_mouse_input = true
    if rl.IsKeyPressed(.ESCAPE) {
        state.in_menu = !state.in_menu
    }
    if state.in_menu /*|| in_code*/ {
        state.mouse_lock = false
        state.use_mouse_input = false
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
    forward_move := Vec3{forward.x, 0, forward.z}
    right_move := linalg.normalize(linalg.vector_cross3(forward_move, up))
    if state.mouse_lock {
        rl.HideCursor()
        rl.SetMousePosition(screen.x/2, screen.y/2)
    }
    else {
        rl.ShowCursor()
    }
    //RAYCAST
    raycast()
    //INTERACTION
    if state.use_key_input {
        if rl.IsKeyDown(.ONE) {
            state.block_in_hand = .Dirt
        }
        if rl.IsKeyDown(.TWO) {
            state.block_in_hand = .Stone
        }
    }

    if state.use_mouse_input {
        if rl.IsMouseButtonPressed(.LEFT) && state.target_block != -1 {
            blocks[state.target_block] = .Air
            raycast()
        }
        if rl.IsMouseButtonPressed(.RIGHT) && state.target_block != -1 {
        if !is_overlapping(state.cam.position, unflatten(state.place_block), state.block_in_hand) {
                blocks[state.place_block] = state.block_in_hand
                raycast()
        }}
    }
    //MOVEMENT
    move_speed := state.move_speed
    if rl.IsKeyDown(.LEFT_CONTROL) {
        move_speed *= 1.5
    }
    wasd: Vec3
    if state.use_key_input do wasd = get_wasd_input(forward_move, right_move, up)
    movement := wasd * delta * move_speed
    if state.apply_gravity {
        state.velocity.y -= state.gravity * delta
    }
    if rl.IsKeyPressed(.SPACE) && state.is_grounded && state.use_key_input {
        state.velocity.y = state.jump_strength
    }
    movement += state.velocity * delta
    //COLLISION
    state.is_grounded = false
    for i in 0..<3 {
        state.cam.position[i] += movement[i]
        for block, block_i in blocks {
            block_pos := to_vec3(unflatten(block_i))
            if !is_overlapping_at(state.cam.position, block_i) do continue

            if movement[i] < 0 {
                state.cam.position[i] = block_pos[i] + 0.5 + state.collider_offset[i]
            } else if movement[i] > 0 {
                state.cam.position[i] = block_pos[i] - 0.5 + state.collider_offset[i] - state.collider_size[i]
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
}
draw :: proc() {
    rl.ClearBackground(rl.BLACK)
    rl.BeginMode3D(state.cam)
    
    for block, i in blocks {
        if block == .Air do continue
        texture := block_textures[block]
        rl.SetMaterialTexture(&block_model.materials[0], .ALBEDO, texture)
        p := to_vec3(unflatten(i))
        items := [?]struct{pos: Vec3, euler: Vec3} {
            { {0, 0.5, 0},      {0, 0, 0} },          // Y
            { {0, -0.5, 0},     {180, 0, 0} },        //-Y
            { {0, -0, -0.5},    {-90, 0, 180} },      //-Z
            { {0, -0, 0.5},     {90, 0, 0} },         // Z
            { {0.5, -0, 0},     {0, 90, -90} },       // X
            { {-0.5, -0, 0},    {0, -90, 90} },       //-X
        }
        for item in items {
            e := item.euler * rl.DEG2RAD
            q := rl.QuaternionFromEuler(e.x, e.y, e.z)
            block_model.transform = rl.QuaternionToMatrix(q)
            color := rl.WHITE
            rl.DrawModel(block_model, p + item.pos, 1, color)
            if i == state.target_block {
                white_glaze := rl.Color{255, 255, 255, 25}
                rl.DrawCube(p, 1.001, 1.001, 1.001, white_glaze)
            }
        }
    }
    rl.EndMode3D()
}

raycast :: proc() {
    center := Vec2{f32(screen.x/2), f32(screen.y/2)}
    ray := rl.GetScreenToWorldRay(center, state.cam)

    closest_hit := rl.RayCollision{ distance = 5.0 }
    state.target_block = -1

    for block, i in blocks {
        pos := to_vec3(unflatten(i))
        if block == .Air do continue
        min_box := pos - rl.Vector3{0.5, 0.5, 0.5} 
        max_box := pos + rl.Vector3{0.5, 0.5, 0.5}
        bbox := rl.BoundingBox{min_box, max_box}

        hit := rl.GetRayCollisionBox(ray, bbox)

        if hit.hit && hit.distance < closest_hit.distance {
            closest_hit = hit
            state.target_block = i
            state.place_block = flatten(from_vec3(pos + closest_hit.normal))
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
is_overlapping :: proc(player: Vec3, block_pos: [3]i32, block: Block_Type) -> bool {
    if block == .Air do return false
    block_pos := to_vec3(block_pos)

    p_min := player - state.collider_offset
    p_max := p_min + state.collider_size
    b_min := block_pos - Vec3{0.5, 0.5, 0.5}
    b_max := block_pos + Vec3{0.5, 0.5, 0.5}
    
    overlap_x := min(p_max.x, b_max.x) - max(p_min.x, b_min.x)
    overlap_y := min(p_max.y, b_max.y) - max(p_min.y, b_min.y)
    overlap_z := min(p_max.z, b_max.z) - max(p_min.z, b_min.z)
    
    return overlap_x > 0.001 && overlap_y > 0.001 && overlap_z > 0.001
}
is_overlapping_at :: proc(player: Vec3, block: int) -> bool {
    return is_overlapping(player, unflatten(block), blocks[block])
}

