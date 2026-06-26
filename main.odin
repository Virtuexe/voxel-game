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

Face :: enum{Front, Back, Right, Left, Up, Down}
Direction :: enum{Up, Down, Right, Left}
fix_normal :: proc(vec: Vec3) -> (res: Vec3) {
    biggest_i: int
    biggest: f32
    for n, i in vec {
        if abs(n) > biggest {
            biggest = abs(n)
            biggest_i = i
        }
    }
    for &n, i in res {
        if i == biggest_i {
            if vec[i] < 0 do n = -1
            else do n = 1
            break
        }
    }
    return
}
normal_to_face :: proc(vec: Vec3) -> Face {
    switch vec {
    case {0, 0, 1}: return .Front
    case {0, 0, -1}: return .Back
    case {1, 0, 0}: return .Right
    case {-1, 0, 0}: return .Left
    case {0, 1, 0}: return .Up
    case {0, -1, 0}: return .Down
    }
    return {}
}
face_to_normal :: proc(side: Face) -> Vec3 {
    switch side {
    case .Front: return {0, 0, 1} //-z
    case .Back: return {0, 0, -1} //-z
    case .Right: return {1, 0, 0}
    case .Left: return {-1, 0, 0}
    case .Up: return {0, 1, 0}
    case .Down: return {0, -1, 0}
    }
    return {}
}
ignore_normal :: proc(ignore_normal, normal: Vec3) -> Vec2 {
    switch ignore_normal {
    case {0,0,1}:
        return {normal.x,-normal.y}
    case {0,0,-1}:
        return {-normal.x,-normal.y}
    case {0,1,0}:
        return {normal.x,normal.z}
    case {0,-1,0}:
        return {normal.x,-normal.z}
    case {1,0,0}:
        return {-normal.z,-normal.y}
    case {-1,0,0}:
        return {normal.z,-normal.y}
    }
    return {}
}
restore_normal :: proc(ignore_normal: Vec3, local_dir: Vec2) -> Vec3 {
    switch ignore_normal {
    case {0, 0, 1}:
        return {local_dir.x, -local_dir.y, 0}
    case {0, 0, -1}:
        return {-local_dir.x, -local_dir.y, 0}
    case {0, 1, 0}:
        return {local_dir.x, 0, local_dir.y}
    case {0, -1, 0}:
        return {local_dir.x, 0, -local_dir.y}
    case {1, 0, 0}:
        return {0, -local_dir.y, -local_dir.x}
    case {-1, 0, 0}:
        return {0, -local_dir.y, local_dir.x}
    }
    
    return {}
}
normal_to_direction :: proc(normal: Vec2) -> Direction {
    switch normal{
    case {0,-1}: return .Up
    case {0,1}: return .Down
    case {1,0}: return .Right
    case {-1,0}: return .Left
    }
    return {}
}
direction_to_normal :: proc(dir: Direction) -> Vec2 {
    switch dir{
    case .Up: return {0,-1}
    case .Down: return {0,1}
    case .Right: return {1,0}
    case .Left: return {-1,0}
    }
    return {}
}

screen: [2]f32
center: [2]f32

CHUNK :: [3]i32{16, 16, 16}

crosshair_texture: rl.Texture2D
State :: struct {
    cam: rl.Camera3D,
    ui_cam: rl.Camera2D,
    code: Code_State,
    world: World_State,
    //MOVEMENT & LOOK
    forward: Vec3,
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
    show_debug: bool,
    //INTERACTION
    block_in_hand: Block,
    target_block: int,
    place_block: Vec3,
    place_block_index: int,
    place_block_face_normal: Vec3,
    place_block_direction_normal: Vec3,
    place_block_direction_normal_2d: Vec2,
    place_block_face: Face,
    place_block_direction: Direction,
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
    forward_move := Vec3{forward.x, 0, forward.z}
    right_move := linalg.normalize(linalg.vector_cross3(forward_move, up))
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
    }

    if state.use_mouse_input {
        if rl.IsMouseButtonPressed(.LEFT) && state.target_block != -1 {
            world.block_keys[state.target_block] = palette_provide_block_key({.Air, {}})
            raycast()
        }
        if rl.IsMouseButtonPressed(.RIGHT) && state.target_block != -1 {
            block_place()
        }
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
    rl.BeginBlendMode(.ALPHA)

    //3D
    for do_transparent in ([]bool{false, true}) {
    for block_key, i in world.block_keys {
        block := world.palette[block_key]
        info := block_infos[block.type]
        if do_transparent != .TEXTURE_TRANSPARENT in info.flags do continue // TODO

        p := to_vec3(unflatten(i))
        if texture, ok := &info.texture.(BlockT_Cube); ok {
            texture := texture.tex
            rl.SetMaterialTexture(&block_model.materials[0], .ALBEDO, texture)
            rl.DrawModel(block_model, p, 1, rl.WHITE)
        }
        else if texture, ok := &info.texture.(BlockT_Double); ok{

        }
        else if .TEXTURE_DECAL in info.flags {
            if block.type == .Redstone {
                redstone := block.data.redstone
                texture := get_redstone_texture(redstone.on, redstone.connections)
                rl.SetMaterialTexture(&decal_model.materials[0], .ALBEDO, texture.texture)
            }
            rl.DrawModel(decal_model, p - {0,.499,0}, 1, rl.WHITE)
        }
    }}
    
    if block := state.target_block; block != -1 {
        pos := to_vec3(unflatten(block))
        rl.DrawCube(pos, 1.001, 1.001, 1.001, rl.Color{255, 255, 255, 100})
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

UV_NORMAL :: [8]f32{ 0,0, 0,1, 1,1, 1,0 }
UV_ROT_90 :: [8]f32{ 0,1, 1,1, 1,0, 0,0 }
UV_ROT_180:: [8]f32{ 1,1, 1,0, 0,0, 0,1 }
UV_ROT_270:: [8]f32{ 1,0, 0,0, 0,1, 1,1 }
set_face_uvs :: proc(c: [^]f32, face_idx: int, uv_data: [8]f32) {
    for val, i in uv_data {
        c[face_idx * 8 + i] = val
    }
}
init_block_model :: proc() {
    mesh := rl.GenMeshCube(1, 1, 1)
    coords := cast([^]f32)mesh.texcoords

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

UV_HALF_ROT_90  :: [8]f32{ 0,1, 1,1, 1,0.5, 0,0.5 }
UV_HALF_ROT_180 :: [8]f32{ 1,1, 1,0.5, 0,0.5, 0,1 }

init_slab_model :: proc() {
    mesh := rl.GenMeshCube(1, 0.5, 1)

    verts := cast([^]f32)mesh.vertices
    for i in 0..<mesh.vertexCount {
        verts[i * 3 + 1] -= 0.25 
    }
    rl.UpdateMeshBuffer(mesh, 0, mesh.vertices, mesh.vertexCount * 3 * size_of(f32), 0)

    coords := cast([^]f32)mesh.texcoords

    // FRONT
    set_face_uvs(coords, 0, UV_HALF_ROT_90)  
    // BACK
    set_face_uvs(coords, 1, UV_HALF_ROT_180) 
    // TOP
    set_face_uvs(coords, 2, UV_NORMAL) 
    // BOTTOM
    set_face_uvs(coords, 3, UV_ROT_90)  
    // RIGHT
    set_face_uvs(coords, 4, UV_HALF_ROT_180)  
    // LEFT
    set_face_uvs(coords, 5, UV_HALF_ROT_90) 
    
    rl.UpdateMeshBuffer(mesh, 1, mesh.texcoords, mesh.vertexCount * 2 * size_of(f32), 0)
    slab_model = rl.LoadModelFromMesh(mesh) 
}
init_decal_model :: proc() {
    decal_model = rl.LoadModelFromMesh(rl.GenMeshPlane(1, 1, 1, 1))
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
        texture = gen_redstone_texture(is_on, connections)
    }
}
gen_redstone_texture :: proc(on: bool, connections: [Direction]bool) -> rl.RenderTexture2D {
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
        case .Up: rot = 180
        case .Down: rot = 0
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
get_redstone_texture :: proc(on: bool, connections: [Direction]bool) -> rl.RenderTexture2D {
    state := int(on) * (1 << len(Direction))
    
    for connected, dir in connections {
        if connected {
            state |= (1 << uint(dir))
        }
    }
    
    return redstone_render_texture[state]
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
    state.target_block = -1

    for block, i in world.block_keys {
        block_pos := to_vec3(unflatten(i))
        if block == palette_get_block_key({.Air,{}}) do continue
        min_box := block_pos - rl.Vector3{0.5, 0.5, 0.5}
        max_box := block_pos + rl.Vector3{0.5, 0.5, 0.5}
        bbox := rl.BoundingBox{min_box, max_box}

        hit := rl.GetRayCollisionBox(ray, bbox)

        if hit.hit && hit.distance < closest_hit.distance {
            closest_hit = hit
            state.target_block = i
            state.place_block = block_pos + closest_hit.normal
            state.place_block_index = flatten(from_vec3(state.place_block))
        }
    }
    if state.target_block != -1 {
        pos := to_vec3(unflatten(state.target_block))
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
    if .STATEFUL in info.flags do return false 
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

