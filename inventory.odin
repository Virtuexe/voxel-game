package voxel_game

import rl "vendor:raylib"

init_hotbar :: proc() {
    state.hotbar = {
        Item{type = .Dirt},
        Item{type = .Stone},
        Item{type = .Stairs},
        Item{type = .Piston},
        Item{type = .Button},
        Item{type = .Lever},
        Item{type = .Wire},
        Item{type = .Torch},
        Item{type = .Repeater},
    }
    state.held_item = state.hotbar[0]
}

init_inventory :: proc() {
    init_hotbar()
    state.player_storage[0] = Item{type = .Dirt}
    state.player_storage[1] = Item{type = .Planks}
    state.player_storage[2] = Item{type = .Cobblestone}
    state.player_storage[3] = Item{type = .Slab}
    state.player_storage[4] = Item{type = .Glass}
}

update_inventory :: proc(ustate: ^UI_State) {
    ustate.item_size = ui.Vec{0.08, 0.08}
    
    // Auto-scale
    ideal_padding := ustate.item_size * 0.15
    ideal_box_overlap_x := (ustate.item_size.x + ideal_padding.x * 2) - ideal_padding.x
    ideal_box_overlap_y := (ustate.item_size.y + ideal_padding.y * 2) - ideal_padding.y

    max_width_slots := f32(max(9, STORAGE_GRID[0]))
    total_required_width := (ideal_box_overlap_x * max_width_slots) + ideal_padding.x
    
    total_height_slots := f32(1)
    gap_count := f32(1) // Just hotbar + bottom padding
    if state.show_inventory {
        total_height_slots += f32(STORAGE_GRID[1] * 2)
        gap_count += 3
    }
    
    total_required_height := (ideal_box_overlap_y * total_height_slots) + (ideal_padding.y * gap_count)

    scale: f32 = 1.0
    if total_required_width > ustate.view.size.x {
        scale = min(scale, ustate.view.size.x / total_required_width)
    }
    if total_required_height > ustate.view.size.y {
        scale = min(scale, ustate.view.size.y / total_required_height)
    }
    
    ustate.item_size *= scale

    update_padding(ustate)
    update_hotbar(ustate)
    if state.show_inventory {
        update_storages(ustate)
        
        ustate.hovered_item = nil
        mouse_pos := ui.get_mouse_pos_local(state.ui_cam)
        clicked := ui.is_mouse_button_pressed(.LEFT)
        
        for i in 0..<9 {
            if ui.contains_point(ustate.hotbar_padding_boxes[i], mouse_pos) {
                ustate.hovered_item = state.hotbar[i]
                ustate.hovered_rec = ustate.hotbar_items[i]
                if clicked {
                    temp := state.cursor
                    state.cursor = state.hotbar[i]
                    state.hotbar[i] = temp
                }
            }
        }
        for i in 0..<STORAGE_SLOTS {
            if ui.contains_point(ustate.target_storage_padding_boxes[i], mouse_pos) {
                ustate.hovered_item = state.target_storage[i]
                ustate.hovered_rec = ustate.target_storage_items[i]
                if clicked {
                    temp := state.cursor
                    state.cursor = state.target_storage[i]
                    state.target_storage[i] = temp
                }
            }
            if ui.contains_point(ustate.player_storage_padding_boxes[i], mouse_pos) {
                ustate.hovered_item = state.player_storage[i]
                ustate.hovered_rec = ustate.player_storage_items[i]
                if clicked {
                    temp := state.cursor
                    state.cursor = state.player_storage[i]
                    state.player_storage[i] = temp
                }
            }
        }
    }
}

draw_inventory :: proc(ustate: ^UI_State) {
    draw_hotbar(ustate)
    if state.show_inventory {
        draw_storages(ustate)
        
        if state.cursor != nil {
            mouse_pos := ui.get_mouse_pos_local(state.ui_cam)
            rec := ui.Rec{ size = ustate.item_size }
            ui.align(&rec, ui.Rec{pos = mouse_pos, size = {0,0}}, .Center)
            draw_item(rec, textures[items[state.cursor.?.type].texture])
        }
        
        draw_tooltip(ustate)
    }
}

import "core:fmt"

draw_tooltip :: proc(ustate: ^UI_State) {
    if ustate.hovered_item == nil do return
    if state.cursor != nil do return
    
    item := ustate.hovered_item.?
    name := fmt.tprintf("%v", item.type)
    
    style := ui.make_text_style(ustate.item_size.y * 0.4)
    text_size := ui.measure_text_size(name, style)
    
    padding := ui.Vec{style.font_size * 0.5, style.font_size * 0.5}
    tooltip_rec := ui.Rec{ size = text_size + padding * 2 }
    
    mouse_pos := ui.get_mouse_pos_local(state.ui_cam)
    cursor_rec := ui.Rec{ {}, {ustate.item_size.x * 0.1, ustate.item_size.y * 0} }
    ui.align_at(&cursor_rec, .Bottom_Left, {mouse_pos, {}}, .Top_Left) //TODO custom function in raylib-ui

    ui.align_at(&tooltip_rec, .Bottom_Left, cursor_rec, .Top_Right)
    
    ui.draw_rec(tooltip_rec, ui.Color{0, 0, 0, 130})
    ui.draw_rec_lines(tooltip_rec, 0.004, ui.Color{0, 0, 0, 255})
    
    text_pos := tooltip_rec.pos + padding
    ui.draw_text(name, style, text_pos, ui.WHITE)
}

import ui "raylib-ui"

update_padding :: proc(ustate: ^UI_State) {
    padding := &ustate.padding
    padding_box := &ustate.padding_box
    padding_box_overlap := &ustate.padding_box_overlap
    padding^ = ustate.item_size*0.15
    padding_box^ = ui.Rec{{}, padding^ * 2 + ustate.item_size}
    padding_box_overlap^ = padding_box^
    ui.cut(&padding_box_overlap^, .Right, padding.x)
    ui.cut(&padding_box_overlap^, .Bottom, padding.y)
}

update_hotbar :: proc(ustate: ^UI_State) {
    padding := ustate.padding
    padding_box := ustate.padding_box
    padding_box_overlap := ustate.padding_box_overlap
    
    ustate.hotbar.size = {padding_box_overlap.size.x * 9, padding_box.size.y}
    ui.resize_anchored(&ustate.hotbar, .Center_Right, {padding.x, 0})
    ui.align(&ustate.hotbar, ustate.view, .Bottom_Center)
    for i in 0..<9 {
        ui.list(&padding_box_overlap, ustate.hotbar.pos, padding_box_overlap.size, i, .Top_Left)
        padding_box.pos = padding_box_overlap.pos
        ustate.hotbar_padding_boxes[i] = padding_box
        
        item := &ustate.hotbar_items[i]
        item.size = ustate.item_size
        ui.align(item, padding_box, .Center)
    }
}

draw_hotbar :: proc(ustate: ^UI_State) {
    ui.draw_rec(ustate.hotbar, ui.Color{0, 0, 0, 100})
    for i in 0..<9 {
        rec := ustate.hotbar_items[i]

        if i == state.hotbar_index {
            ui.draw_rec_lines(ustate.hotbar_padding_boxes[i], ustate.padding.x, ui.WHITE)
        }
        
        item := state.hotbar[i]
        if item != nil {
            draw_item(rec, textures[items[item.?.type].texture])
        }
    }
}

update_storages :: proc(ustate: ^UI_State) {
    padding := ustate.padding
    padding_box := ustate.padding_box
    padding_box_overlap := ustate.padding_box_overlap

    // 1. Calculate master container
    total_width := padding_box_overlap.size.x * f32(STORAGE_GRID[0]) + padding.x
    total_height := (padding_box_overlap.size.y * f32(STORAGE_GRID[1] * 2)) + padding.y * 3 // two grids + gap + padding bottoms
    
    master_rec := ui.Rec{ size = {total_width, total_height} }
    
    available_view := ustate.view
    ui.cut(&available_view, .Bottom, ustate.hotbar.size.y + padding.y * 2)

    ui.align(&master_rec, available_view, .Center)

    // 2. Set sizes and align
    grid_height := padding_box_overlap.size.y * f32(STORAGE_GRID[1]) + padding.y
    ustate.target_storage.size = {total_width, grid_height}
    ustate.player_storage.size = {total_width, grid_height}

    ui.align(&ustate.target_storage, master_rec, .Top_Center)
    ui.align(&ustate.player_storage, master_rec, .Bottom_Center)

    // 3. Populate grids
    for y in 0..<STORAGE_GRID[1] {
        for x in 0..<STORAGE_GRID[0] {
            index := y * STORAGE_GRID[0] + x
            
            // Target Storage
            ui.grid(&padding_box_overlap, ustate.target_storage.pos, padding_box_overlap.size, x, y, .Top_Left)
            padding_box.pos = padding_box_overlap.pos
            ustate.target_storage_padding_boxes[index] = padding_box
            
            item := &ustate.target_storage_items[index]
            item.size = ustate.item_size
            ui.align(item, padding_box, .Center)
            
            // Player Storage
            ui.grid(&padding_box_overlap, ustate.player_storage.pos, padding_box_overlap.size, x, y, .Top_Left)
            padding_box.pos = padding_box_overlap.pos
            ustate.player_storage_padding_boxes[index] = padding_box
            
            item_p := &ustate.player_storage_items[index]
            item_p.size = ustate.item_size
            ui.align(item_p, padding_box, .Center)
        }
    }
}

draw_storages :: proc(ustate: ^UI_State) {
    ui.draw_rec(ustate.target_storage, ui.Color{0, 0, 0, 100})
    ui.draw_rec(ustate.player_storage, ui.Color{0, 0, 0, 100})
    
    // Draw grid padding boxes and items
    for i in 0..<STORAGE_SLOTS {
        ui.draw_rec_lines(ustate.target_storage_padding_boxes[i], ustate.padding.x, ui.Color{0, 0, 0, 100})
        if item := state.target_storage[i]; item != nil {
            draw_item(ustate.target_storage_items[i], textures[items[item.?.type].texture])
        }
        
        ui.draw_rec_lines(ustate.player_storage_padding_boxes[i], ustate.padding.x, ui.Color{0, 0, 0, 100})
        if item := state.player_storage[i]; item != nil {
            draw_item(ustate.player_storage_items[i], textures[items[item.?.type].texture])
        }
    }
}

draw_item :: proc(rec: ui.Rec, tex: ui.Texture) {
    ui.draw_rec_texture(rec, tex)
}
