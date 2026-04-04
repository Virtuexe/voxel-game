package voxel_game

import "core:fmt"
import rl "vendor:raylib"

import "core:math"
import "core:math/linalg"

import ui "./raylib-ui"

Vec2 :: rl.Vector2
Vec3 :: rl.Vector3

Side :: enum{Front, Back, Right, Left, Up, Down}
Direction :: enum{Front, Back, Right, Left}

screen: [2]f32
center: [2]f32

CHUNK :: [3]i32{16, 16, 16}

block_model: rl.Model
//connections -> on/off
crosshair_texture: rl.Texture2D
redstone_render_texture: [(1<<len(Direction))*2]rl.RenderTexture2D
block_cube_textures: [Block_Type]rl.Texture2D
is_block_cube :: proc(block: Block_Type) -> bool {
    switch block {
    case .Dirt, .Stone:
        return true
    case .Air, .Redstone:
        return false
    }
    return false
}
State :: struct {
    cam: rl.Camera3D,
    ui_cam: rl.Camera2D,
    code: Code_State,
    world: World_State,
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
    block_in_hand: Block,
    target_block: int,
    place_block: int,
    //COLLISION
    collider_size: Vec3,
    collider_offset: Vec3,
    last_position: Vec3,
}
state := State {
    cam = {
        position = {0, 5, 5},
        up       = {0, 1, 0},
        fovy     = 90,
        projection = .PERSPECTIVE,
    },
    ui_cam = {zoom=1},
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

    rl.UnloadTexture(crosshair_texture)
    for texture, block in block_cube_textures {
        if !is_block_cube(block) do continue
        rl.UnloadTexture(texture)
    }
    for texture in redstone_render_texture {
        rl.UnloadRenderTexture(texture)
    }
    rl.UnloadModel(block_model)
    rl.CloseWindow()
}

init :: proc() {
    calc_window()

    init_block_model()
    crosshair_texture = rl.LoadTexture("assets/crosshair.png")
    block_cube_textures = #partial {
        .Dirt = rl.LoadTexture("assets/dirt.png"),
        .Stone = rl.LoadTexture("assets/stone.png"),
    }
    gen_redstone_textures()

    world_init()

    state.block_in_hand = {.Dirt, {}}

    state.apply_gravity = true
    state.is_flying = false
    state.can_jump = true
    init_code()
}

update :: proc() {
    calc_window()
    delta := get_delta()
    //ESC
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
        rl.SetMousePosition(i32(screen.x/2), i32(screen.y/2))
    }
    else {
        rl.ShowCursor()
    }
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
    }

    if state.use_mouse_input {
        if rl.IsMouseButtonPressed(.LEFT) && state.target_block != -1 {
            world.block_keys[state.target_block] = palette_get_block_key({.Air, {}})
            raycast()
        }
        if rl.IsMouseButtonPressed(.RIGHT) && state.target_block != -1 {
        if !is_overlapping(state.cam.position, unflatten(state.place_block), state.block_in_hand) {
                world.block_keys[state.place_block] = palette_get_block_key(state.block_in_hand)
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
        for block, block_i in world.block_keys {
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

    update_code()
}
draw :: proc() {
    rl.ClearBackground(rl.BLACK)
    rl.BeginMode3D(state.cam)
    //3D
    for block_key, i in world.block_keys {
        normal_block: Block
        ok: bool
        block := world.palette[block_key]
        if is_block_cube(block.type) {
            texture := block_cube_textures[block.type]
            rl.SetMaterialTexture(&block_model.materials[0], .ALBEDO, texture)
            p := to_vec3(unflatten(i))
            rl.DrawModel(block_model, p, 1, rl.WHITE)
        }
        else if block.type == .Redstone {
            //TODO
        }
    }
    if block := state.target_block; block != -1 {
        pos := to_vec3(unflatten(block))
        rl.DrawCube(pos, 1.001, 1.001, 1.001, rl.Color{255, 255, 255, 100})
    }
    rl.EndMode3D()

    //UI
    rl.BeginMode2D(state.ui_cam)
    
    crosshair := ui.Rec{{}, ui.vmin(screen)/15}
    crosshair.pos = center-crosshair.size/2
    ui.draw_rec_texture(crosshair, crosshair_texture)

    rl.EndMode2D()

    draw_code()
}

UV_NORMAL :: [8]f32{ 0,0, 0,1, 1,1, 1,0 }
UV_ROT_90 :: [8]f32{ 0,1, 1,1, 1,0, 0,0 }
UV_ROT_180:: [8]f32{ 1,1, 1,0, 0,0, 0,1 }
UV_ROT_270:: [8]f32{ 1,0, 0,0, 0,1, 1,1 }
init_block_model :: proc() {
    mesh := rl.GenMeshCube(1, 1, 1)
    if mesh.texcoords == nil do return
    coords := cast([^]f32)mesh.texcoords

    set_face_uvs :: proc(c: [^]f32, face_idx: int, uv_data: [8]f32) {
        for val, i in uv_data {
            c[face_idx * 8 + i] = val
        }
    }
    // FRONT
    set_face_uvs(coords, 0, UV_ROT_90)  
    // BACK
    set_face_uvs(coords, 1, UV_ROT_180) 
    // TOP
    set_face_uvs(coords, 2, UV_NORMAL) 
    // BOTTOM
    set_face_uvs(coords, 3, UV_ROT_90)  
    // RIGHT
    set_face_uvs(coords, 4, UV_ROT_180)  
    // LEFT
    set_face_uvs(coords, 5, UV_ROT_90) 
    // Sync CPU changes to GPU
    rl.UpdateMeshBuffer(mesh, 1, mesh.texcoords, mesh.vertexCount * 2 * size_of(f32), 0)

    block_model = rl.LoadModelFromMesh(mesh)
}

gen_redstone_textures :: proc() {
    for &texture, state in redstone_render_texture {
        is_on := (state & (1 << len(Direction))) != 0
        connections: [Direction]bool
        for dir, dir_index in Direction {
            dir_index := uint(dir_index)
            has_dir := (state & (1 << dir_index)) != 0
            connections[dir] = has_dir
        }
        texture = get_redstone_textures(connections, is_on)
    }
}
get_redstone_textures :: proc(connections: [Direction]bool, on: bool) -> rl.RenderTexture2D {
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
        case .Front: rot = 0
        case .Back: rot = 180
        case .Right: rot = 90
        case .Left: rot = 270
        }
        rl.DrawTexturePro(wire, rec, {8,8,16,16}, {8, 8}, rot, rl.WHITE)
    }
    rl.EndTextureMode()
    rl.UnloadTexture(dot)
    rl.UnloadTexture(wire)
    return result
}

get_delta :: proc() -> f32 {
    return min(0.2, rl.GetFrameTime())
}
calc_window :: proc() {
    screen = Vec2{f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}
    center = screen/2
}
raycast :: proc() {
    center := Vec2{f32(screen.x/2), f32(screen.y/2)}
    ray := rl.GetScreenToWorldRay(center, state.cam)

    closest_hit := rl.RayCollision{ distance = 5.0 }
    state.target_block = -1

    for block, i in world.block_keys {
        pos := to_vec3(unflatten(i))
        if block == palette_get_block_key({.Air,{}}) do continue
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
is_overlapping :: proc(player: Vec3, block_pos: [3]i32, block: Block) -> bool {
    if block == {.Air, {}} do return false
    if !is_block_stateless(block) do return false 
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
    return is_overlapping(player, unflatten(block), world.palette[world.block_keys[block]])
}

