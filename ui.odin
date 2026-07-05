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

update_hotbar :: proc() {
    padding := &ustate.padding
    padding^ = ustate.item_size*0.15
    padding_box := ui.Rec{{}, padding^ * 2 + ustate.item_size}
    padding_box_overlap := padding_box
    ui.cut(&padding_box_overlap, .Right, padding.x)

    ustate.hotbar.size = {padding_box_overlap.size.x * 9, padding_box_overlap.size.y}
    ui.resize_anchored(&ustate.hotbar, .Center_Right, {padding.x, 0})
    ui.align(&ustate.hotbar, ustate.view, .Bottom_Center)
    for i in 0..<9 {
        ui.list(&padding_box_overlap, ustate.hotbar.pos, padding_box_overlap.size, i, .Top_Left)
        padding_box.pos = padding_box_overlap.pos
        ustate.padding_boxes[i] = padding_box
        
        item := &ustate.items[i]
        item.size = ustate.item_size
        ui.align(item, padding_box, .Center)
    }
}
draw_hotbar :: proc() {
    ui.draw_rec(ustate.hotbar, rl.Color{0, 0, 0, 100})
    for i in 0..<9 {
        rec := ustate.items[i]

        if i == state.hotbar_index {
            ui.draw_rec_lines(ustate.padding_boxes[i], ustate.padding.x, ui.WHITE)
        }
        
        block := state.hotbar[i]
        if block.type != .Air {
            info := block_infos[block.type]
            if item, ok := info.item.?; ok {
                draw_item(rec, items[item].texture)
            }
        }
    }
}

draw_item :: proc(rec: ui.Rec, tex: ui.Texture) {
    ui.draw_rec_texture(rec, tex)
}