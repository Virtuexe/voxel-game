package voxel_game

init_hotbar :: proc() {
    state.hotbar = {
        .Dirt,
        .Stone,
        .Cobblestone,
        .Glass,
        .Planks,
        .Redstone,
        .Slab,
        .Stairs,
        .Piston,
    }
    state.held_item = state.hotbar[0]
}

init_inventory :: proc() {
    init_hotbar()
    for type in Item_Type {
        if block, ok := items[type].block.?; ok {
            if block == .Redstone {
                items[type].texture = get_redstone_texture(false, {}).texture
            } else {
                tex_type := block_infos[block].textures[0][.Top]
                items[type].texture = block_textures[tex_type]
            }
        }
    }
}

update_inventory :: proc(ustate: ^UI_State) {
    ustate.item_size = ui.Vec{0.08, 0.08}
    update_hotbar(ustate)
}
draw_inventory :: proc(ustate: ^UI_State) {
    draw_hotbar(ustate)
}

import ui "raylib-ui"

update_hotbar :: proc(ustate: ^UI_State) {
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
draw_hotbar :: proc(ustate: ^UI_State) {
    ui.draw_rec(ustate.hotbar, ui.Color{0, 0, 0, 100})
    for i in 0..<9 {
        rec := ustate.items[i]

        if i == state.hotbar_index {
            ui.draw_rec_lines(ustate.padding_boxes[i], ustate.padding.x, ui.WHITE)
        }
        
        item := state.hotbar[i]
        if item != nil {
            draw_item(rec, items[item.?].texture)
        }
    }
}

draw_item :: proc(rec: ui.Rec, tex: ui.Texture) {
    ui.draw_rec_texture(rec, tex)
}
