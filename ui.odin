package voxel_game

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"
import ui "raylib-ui"

UI_State :: struct {
    view: ui.Rec,
    hotbar: ui.Rec,

    item_size: ui.Vec,
    items: [9]ui.Rec,
    padding: ui.Vec,
    padding_boxes: [9]ui.Rec,
}

update_ui :: proc(state: ^State, ustate: ^UI_State) {
    ui.camera_set_viewport(&state.ui_cam)
    ustate.view = {{}, ui.get_view_size(state.ui_cam)}
    update_inventory(state, ustate)
}
draw_ui :: proc(state: ^State, ustate: ^UI_State) {
    ui.begin_draw(&state.ui_cam)
    draw_inventory(state, ustate)

    if !state.show_debug {
        crosshair := ui.Rec{{}, ui.vmin(ustate.view.size)/15}
        ui.align(&crosshair, ustate.view, .Center)
        ui.draw_rec_texture(crosshair, crosshair_texture)
    } else {
        text := fmt.aprint(
            "position: ", state.cam.position, "\n",
            allocator = context.temp_allocator
        )
        rl.DrawText(strings.clone_to_cstring(text, context.temp_allocator), 0, 0, i32(ui.vmin(ustate.view.size)/30), rl.WHITE)
    }

    ui.end_draw()
}