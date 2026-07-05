package voxel_game

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"
import ui "raylib-ui"

UI_State :: struct {
    view: ui.Rec,
    item_size: ui.Vec,
    hotbar: ui.Rec,
    items: [9]ui.Rec,
}
ustate: UI_State

update_ui :: proc() {
    ui.camera_set_viewport(&state.ui_cam)
    ustate.view = {{}, ui.get_view_size(state.ui_cam)}
    update_inventory()
}
draw_ui :: proc() {
    ui.begin_draw(&state.ui_cam)
    draw_inventory()

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

update_inventory :: proc() {
    ustate.item_size = ui.Vec{0.08, 0.08}
    update_hotbar()
}
draw_inventory :: proc() {
    draw_hotbar()
}

hotbar: ui.Rec
update_hotbar :: proc() {
    item := ustate.item_size
    hotbar.size = {item.x * 9, item.y}
    ui.align(&hotbar, ustate.view, .Bottom_Center)
    for i in 0..<9 {
        ustate.items[i].size = item
        if i == 0 {
            ui.align_at(&ustate.items[i], .Top_Left, hotbar, .Top_Left)
        } else {
            ui.align_at(&ustate.items[i], .Top_Left, ustate.items[i-1], .Top_Right)
        }
    }
}
draw_hotbar :: proc() {
    ui.draw_rec(hotbar, rl.Color{0, 0, 0, 100})
    for i in 0..<9 {
        rec := ustate.items[i]
        
        if state.hotbar_index == i {
            ui.draw_rec_lines(rec, 0.005, rl.WHITE)
        } else {
            ui.draw_rec_lines(rec, 0.005, rl.Color{100, 100, 100, 255})
        }
        
        block := state.hotbar[i]
        if block.type != .Air {
            info := block_infos[block.type]
            if item, ok := info.item.?; ok {
                draw_item(rec.pos, items[item].texture)
            }
        }
    }
}

draw_item :: proc(pos: ui.Vec, tex: ui.Texture) {
    ui.draw_rec_texture({pos, ustate.item_size}, tex)
}