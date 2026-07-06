package voxel_game

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"
import ui "raylib-ui"

STORAGE_GRID :: [2]int{9, 3}
STORAGE_SLOTS :: STORAGE_GRID[0] * STORAGE_GRID[1]

UI_State :: struct {
    view: ui.Rec,
    item_size: ui.Vec,
    padding: ui.Vec,
    padding_box: ui.Rec,
    padding_box_overlap: ui.Rec,

    hotbar: ui.Rec,
    hotbar_items: [9]ui.Rec,
    hotbar_padding_boxes: [9]ui.Rec,

    player_storage: ui.Rec,
    player_storage_items: [STORAGE_SLOTS]ui.Rec,
    player_storage_padding_boxes: [STORAGE_SLOTS]ui.Rec,

    hovered_item: Maybe(Item_Type),
    hovered_rec: ui.Rec,

    target_storage: ui.Rec,
    target_storage_items: [STORAGE_SLOTS]ui.Rec,
    target_storage_padding_boxes: [STORAGE_SLOTS]ui.Rec,
}

update_ui :: proc(ustate: ^UI_State) {
    ui.camera_set_viewport(&state.ui_cam)
    ustate.view = {{}, ui.get_view_size(state.ui_cam)}
    update_inventory(ustate)
}
draw_ui :: proc(ustate: ^UI_State) {
    ui.begin_draw(&state.ui_cam)
    draw_inventory(ustate)

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