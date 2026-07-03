package voxel_game

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"
import ui "raylib-ui"

view: ui.Rec

update_ui :: proc() {
    ui.camera_set_viewport(&state.ui_cam)
    view = {{}, ui.get_view_size(state.ui_cam)}
    update_hotbar()
}
draw_ui :: proc() {
    ui.begin_draw(&state.ui_cam)
    draw_hotbar()

    if !state.show_debug {
        crosshair := ui.Rec{{}, ui.vmin(view.size)/15}
        ui.align(&crosshair, view, .Center)
        ui.draw_rec_texture(crosshair, crosshair_texture)
    } else {
        text := fmt.aprint(
            "position: ", state.cam.position, "\n",
            allocator = context.temp_allocator
        )
        rl.DrawText(strings.clone_to_cstring(text, context.temp_allocator), 0, 0, i32(ui.vmin(view.size)/30), rl.WHITE)
    }

    ui.end_draw()
}

hotbar: ui.Rec
update_hotbar :: proc() {
    hotbar.size.x = view.size.x*0.5
    hotbar.size.y = view.size.x*0.05
    ui.align(&hotbar, view, .Bottom_Center)
}
draw_hotbar :: proc() {
}