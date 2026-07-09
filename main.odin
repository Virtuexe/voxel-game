package voxel_game

import "core:fmt"
import rl "vendor:raylib"

get_block_transform :: proc(block: Block) -> rl.Matrix {
    info := block_infos[block.type]
    model_data := block_models[block.type]
    rot_mat := rl.Matrix(1)
    
    // Helper to map Cardinal to Block_Face
    cardinal_to_face :: proc(dir: Cardinal) -> Block_Face {
        switch dir {
        case .North: return .North
        case .East:  return .East
        case .South: return .South
        case .West:  return .West
        }
        return .North
    }
    
    // Direct rotations to/from North
    get_rot_to_north :: proc(f: Block_Face) -> rl.Matrix {
        switch f {
        case .North: return rl.Matrix(1)
        case .South: return rl.MatrixRotateY(rl.PI)
        case .East:  return rl.MatrixRotateY(rl.PI/2)
        case .West:  return rl.MatrixRotateY(-rl.PI/2)
        case .Top:   return rl.MatrixRotateX(-rl.PI/2)
        case .Bottom:return rl.MatrixRotateX(rl.PI/2)
        }
        return rl.Matrix(1)
    }

    get_rot_from_north :: proc(f: Block_Face) -> rl.Matrix {
        switch f {
        case .North: return rl.Matrix(1)
        case .South: return rl.MatrixRotateY(rl.PI)
        case .East:  return rl.MatrixRotateY(-rl.PI/2)
        case .West:  return rl.MatrixRotateY(rl.PI/2)
        case .Top:   return rl.MatrixRotateX(rl.PI/2)
        case .Bottom:return rl.MatrixRotateX(-rl.PI/2)
        }
        return rl.Matrix(1)
    }
    
    if .HAS_CARDINAL in info.flags && .HAS_BLOCK_FACE in info.flags {
        // Stairs
        target_face := cardinal_to_face(block.data.direction)
        
        if block.data.facing == .Top {
            rot_mat = get_rot_from_north(target_face) * rl.MatrixRotateZ(rl.PI) * get_rot_to_north(model_data.base_facing)
        } else {
            rot_mat = get_rot_from_north(target_face) * get_rot_to_north(model_data.base_facing)
        }
    } else if .HAS_BLOCK_FACE in info.flags {
        // 6-way block (Piston)
        rot_mat = get_rot_from_north(block.data.facing) * get_rot_to_north(model_data.base_facing)
    } else if .HAS_CARDINAL in info.flags {
        // 4-way block
        target_face := cardinal_to_face(block.data.direction)
        rot_mat = get_rot_from_north(target_face) * get_rot_to_north(model_data.base_facing)
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

wire_model_texture: rl.Texture2D
crosshair_texture: rl.Texture2D
// State structs moved to state.odin

main :: proc() {

    ustate := UI_State{}

    state.last_position = state.position
    //RAYLIB
    rl.SetTraceLogLevel(.WARNING)
    rl.SetWindowState({.WINDOW_RESIZABLE})
    rl.InitWindow(1200, 800, "Game")
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
        for part in data.parts {
            delete(part.collision_bboxes)
        }
        delete(data.parts)
    }
    rl.CloseWindow()
}

init :: proc(ustate: ^UI_State) {
    calc_window()

    wire_model_texture = rl.LoadTexture("assets/arrow.png")
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

    update_input()
    update_player(delta)

    update_ui(ustate)
    update_code()
    world_update_scheduled_actions()
    world_update_moves()
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
