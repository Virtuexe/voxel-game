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
//MOVEMENT & LOOK
apply_gravity: bool
is_flying: bool
can_jump: bool
move_speed: f32 = 4.3
gravity: f32 = 32
jump_strength: f32 = 8.4
mouse_sensitivity: f32 = 0.1

is_grounded: bool
velocity: Vec3
in_menu: bool = false
use_key_input: bool = true
use_mouse_input: bool = true
mouse_lock: bool
yaw: f32 = -90
pitch: f32
cam := rl.Camera3D {
    position = {0, 5, 0},
    up       = {0, 1, 0},
    fovy     = 90,
    projection = .PERSPECTIVE,
}
//INTERACTION
block_in_hand: Block_Type
target_block: int = -1
place_block: int
//COLLISION
collider_size := Vec3{0.5, 2, 0.5}
collider_offset := collider_size/2 + {0, collider_size.y/4, 0}
last_position := cam.position

main :: proc() {
    //RAYLIB
    rl.SetTraceLogLevel(.WARNING)
    rl.SetWindowState({.WINDOW_RESIZABLE})
    rl.InitWindow(800, 500, "Game")
    rl.SetTargetFPS(60)
    rl.SetExitKey(rl.KeyboardKey.KEY_NULL)

    init()
    init_code()

    for !rl.WindowShouldClose() {        
        update()
        update_code()
        rl.BeginDrawing()
        draw()
        draw_code()
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

    block_in_hand = .Dirt

    apply_gravity = true
    is_flying = false
    can_jump = true
}

update :: proc() {
    screen = [2]i32{rl.GetScreenWidth(), rl.GetScreenHeight()}
    delta := rl.GetFrameTime()
    //ESC
    mouse_lock = true
    use_key_input = true
    use_mouse_input = true
    if rl.IsKeyPressed(.ESCAPE) {
        in_menu = !in_menu
    }
    if in_menu || in_code {
        mouse_lock = false
        use_mouse_input = false
    }
    //LOOK
    if mouse_lock {
        mouse_delta := rl.GetMouseDelta()
        yaw += mouse_delta.x * mouse_sensitivity
        pitch -= mouse_delta.y * mouse_sensitivity
        pitch = clamp(pitch, -89.9, 89.9)
    }
    yaw_rad := yaw * rl.DEG2RAD
    pitch_rad := pitch * rl.DEG2RAD
    up := Vec3{0,1,0}
    forward := Vec3 {
        math.cos_f32(pitch_rad) * math.cos_f32(yaw_rad),
        math.sin_f32(pitch_rad),
        math.cos_f32(pitch_rad) * math.sin_f32(yaw_rad),
    }
    forward_move := Vec3{forward.x, 0, forward.z}
    right_move := linalg.normalize(linalg.vector_cross3(forward_move, up))
    if mouse_lock {
        rl.HideCursor()
        rl.SetMousePosition(screen.x/2, screen.y/2)
    }
    else {
        rl.ShowCursor()
    }
    //RAYCAST
    raycast()
    //INTERACTION
    if use_key_input {
        if rl.IsKeyDown(.ONE) {
            block_in_hand = .Dirt
        }
        if rl.IsKeyDown(.TWO) {
            block_in_hand = .Stone
        }
    }

    if use_mouse_input {
        if rl.IsMouseButtonPressed(.LEFT) && target_block != -1 {
            blocks[target_block] = .Air
            raycast()
        }
        if rl.IsMouseButtonPressed(.RIGHT) && target_block != -1 {
        if !is_overlapping(cam.position, unflatten(place_block), block_in_hand) {
                blocks[place_block] = block_in_hand
                raycast()
        }}
    }
    //MOVEMENT
    move_speed := move_speed
    if rl.IsKeyDown(.LEFT_CONTROL) {
        move_speed *= 1.5
    }
    wasd: Vec3
    if use_key_input do wasd = get_wasd_input(forward_move, right_move, up)
    movement := wasd * delta * move_speed
    if apply_gravity {
        velocity.y -= gravity * delta
    }
    if rl.IsKeyPressed(.SPACE) && is_grounded && use_key_input {
        velocity.y = jump_strength
    }
    movement += velocity * delta
    //COLLISION
    is_grounded = false
    for i in 0..<3 {
        cam.position[i] += movement[i]
        for block, block_i in blocks {
            block_pos := to_vec3(unflatten(block_i))
            if !is_overlapping_at(cam.position, block_i) do continue

            if movement[i] < 0 {
                cam.position[i] = block_pos[i] + 0.5 + collider_offset[i]
            } else if movement[i] > 0 {
                cam.position[i] = block_pos[i] - 0.5 + collider_offset[i] - collider_size[i]
            }

            movement[i] = 0
            if i == 1 {
                is_grounded = true
                velocity.y = 0
            }
            break
        }
    }
    last_position = cam.position
    cam.target = cam.position + forward
}
draw :: proc() {
    rl.ClearBackground(rl.BLACK)
    rl.BeginMode3D(cam)
    
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
            if i == target_block {
                white_glaze := rl.Color{255, 255, 255, 25}
                rl.DrawCube(p, 1.001, 1.001, 1.001, white_glaze)
            }
        }
    }
    rl.EndMode3D()
}

raycast :: proc() {
    center := Vec2{f32(screen.x/2), f32(screen.y/2)}
    ray := rl.GetScreenToWorldRay(center, cam)

    closest_hit := rl.RayCollision{ distance = 5.0 }
    target_block = -1

    for block, i in blocks {
        pos := to_vec3(unflatten(i))
        if block == .Air do continue
        min_box := pos - rl.Vector3{0.5, 0.5, 0.5} 
        max_box := pos + rl.Vector3{0.5, 0.5, 0.5}
        bbox := rl.BoundingBox{min_box, max_box}

        hit := rl.GetRayCollisionBox(ray, bbox)

        if hit.hit && hit.distance < closest_hit.distance {
            closest_hit = hit
            target_block = i
            place_block = flatten(from_vec3(pos + closest_hit.normal))
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
    if is_flying do for item in key_vec_fly {
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

    p_min := player - collider_offset
    p_max := p_min + collider_size
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

