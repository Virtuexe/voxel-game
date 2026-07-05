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
    state := State {
        cam = {
            position = {0, 5, 5},
            up       = {0, 1, 0},
            fovy     = 90,
            projection = .PERSPECTIVE,
        },
        ui_cam = {zoom=1},
        movement = {
            move_speed = 4.3,
            gravity = 32,
            jump_strength = 8.4,
            yaw = 90,
        },
        input = {
            mouse_sensitivity = 0.1,
            use_key_input = true,
            use_mouse_input = true,
        },
        interaction = {
            looking_at_block = false,
        },
        collider = {
            collider_size = Vec3{0.5, 2, 0.5},
        },
    }
    ustate := UI_State{}

    state.collider_offset = state.collider_size/2 + {0, state.collider_size.y/4, 0}
    state.last_position = state.cam.position
    //RAYLIB
    rl.SetTraceLogLevel(.WARNING)
    rl.SetWindowState({.WINDOW_RESIZABLE})
    rl.InitWindow(800, 500, "Game")
    rl.SetTargetFPS(120)
    rl.SetExitKey(rl.KeyboardKey.KEY_NULL)

    init(&state, &ustate)

    for !rl.WindowShouldClose() {        
        update(&state, &ustate)
        rl.BeginDrawing()
        draw(&state, &ustate)
        rl.EndDrawing()
    }

    rl.UnloadTexture(crosshair_texture)
    for texture in redstone_render_texture {
        rl.UnloadRenderTexture(texture)
    }
    rl.UnloadModel(block_model)
    rl.CloseWindow()
}

init :: proc(state: ^State, ustate: ^UI_State) {
    calc_window()

    arrow_texture = rl.LoadTexture("assets/arrow.png")
    crosshair_texture = rl.LoadTexture("assets/crosshair.png")
    init_textures()
    init_shaders()
    block_init()
    gen_redstone_textures()

    world_init(state)

    init_inventory(state)

    state.apply_gravity = true
    state.is_flying = false
    state.can_jump = true
    init_code(state)
}

update :: proc(state: ^State, ustate: ^UI_State) {
    calc_window()
    delta := get_delta()

    update_player(state, delta)

    update_ui(state, ustate)
    update_code(state)
}

draw :: proc(state: ^State, ustate: ^UI_State) {
    rl.ClearBackground(rl.BLACK)
    rl.BeginMode3D(state.cam)
    rl.BeginBlendMode(.ALPHA)

    draw_world_chunks(state)
    draw_player_target_box(state)
    
    rl.EndMode3D()

    //UI
    draw_ui(state, ustate)

    draw_code(state)
}

get_delta :: proc() -> f32 {
    return min(0.14, rl.GetFrameTime())
}

calc_window :: proc() {
    screen = Vec2{f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}
    center = screen/2
}
