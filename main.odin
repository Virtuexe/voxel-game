package voxel_game

import "core:fmt"
import rl "vendor:raylib"

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
    
    if rot_mat != rl.Matrix(1) {
        offset_to_center := rl.MatrixTranslate(-0.5, -0.5, -0.5)
        offset_back := rl.MatrixTranslate(0.5, 0.5, 0.5)
        rot_mat = offset_back * rot_mat * offset_to_center
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

    ustate := UI_State{}

    state.last_position = state.position
    //RAYLIB
    rl.SetTraceLogLevel(.WARNING)
    rl.SetWindowState({.WINDOW_RESIZABLE})
    rl.InitWindow(800, 500, "Game")
    rl.SetTargetFPS(120)
    rl.SetExitKey(rl.KeyboardKey.KEY_NULL)

    init(&ustate)

    for !rl.WindowShouldClose() {        
        update(&ustate)
        rl.BeginDrawing()
        draw(&ustate)
        rl.EndDrawing()
    }

    rl.UnloadTexture(crosshair_texture)
    for texture in redstone_render_texture {
        rl.UnloadRenderTexture(texture)
    }
    for &data in block_models {
        if data.model.meshCount > 0 {
            rl.UnloadModel(data.model)
        }
        delete(data.collision_bboxes)
    }
    rl.CloseWindow()
}

init :: proc(ustate: ^UI_State) {
    calc_window()

    arrow_texture = rl.LoadTexture("assets/arrow.png")
    crosshair_texture = rl.LoadTexture("assets/crosshair.png")
    init_textures()
    init_shaders()
    block_init()
    gen_redstone_textures()

    world_init()

    init_inventory()

    state.apply_gravity = true
    state.is_flying = false
    state.can_jump = true
    init_code()
}

update :: proc(ustate: ^UI_State) {
    calc_window()
    delta := get_delta()

    update_player(delta)

    update_ui(ustate)
    update_code()
}

draw :: proc(ustate: ^UI_State) {
    rl.ClearBackground(rl.Color{17, 17, 17, 255})
    rl.BeginMode3D(state.cam)
    rl.BeginBlendMode(.ALPHA)

    draw_world_chunks()
    draw_player_target_box()
    
    rl.EndMode3D()

    //UI
    draw_ui(ustate)

    draw_code()
}

get_delta :: proc() -> f32 {
    return min(0.14, rl.GetFrameTime())
}

calc_window :: proc() {
    screen = Vec2{f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}
    center = screen/2
}
