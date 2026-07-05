package voxel_game

import rl "vendor:raylib"
import vcode "./vcode"

Code_State :: struct {
    in_code: bool,
}

init_code :: proc(state: ^State) {
    vcode.init()
}

update_code :: proc(state: ^State) {
    if rl.IsKeyPressed(.C) {
        state.code.in_code = !state.code.in_code
        if state.code.in_code {
            rl.ShowCursor()
            rl.SetMousePosition(i32(screen.x/2), i32(screen.y/2))
        }
    }
    
    if !state.code.in_code do return
    
    vcode.update()
}

draw_code :: proc(state: ^State) {
    if !state.code.in_code do return
    vcode.draw()
}
