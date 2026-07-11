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

    hovered_item: Maybe(Item),
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
        dynamic_blocks_count := 0
        
        player_chunk := get_chunk_pos(to_vec3i(state.cam.position))
        r_dist := state.render_distance

        for dx in -r_dist..=r_dist {
            for dy in -r_dist..=r_dist {
                for dz in -r_dist..=r_dist {
                    c_pos := player_chunk + {dx, dy, dz}
                    if chunk, ok := state.world.chunks[c_pos]; ok {
                        dynamic_blocks_count += len(chunk.dynamic_blocks)
                    }
                }
            }
        }

        font_size := ui.vmin(ustate.view.size) / 30.0
        style := ui.make_text_style(font_size)
        
        texts := [4]string{
            fmt.tprintf("FPS: %v", rl.GetFPS()),
            fmt.tprintf("Position: %.2f, %.2f, %.2f", state.cam.position.x, state.cam.position.y, state.cam.position.z),
            fmt.tprintf("Tracked blocks: %v", len(state.world.traked_blocks)),
            fmt.tprintf("Dynamic blocks: %v", dynamic_blocks_count),
        }
        
        for t, i in texts {
            y_offset := f32(i) * font_size * 1.2
            // Draw drop shadow for visibility
            ui.draw_text(t, style, {font_size/15.0, y_offset + font_size/15.0}, rl.BLACK)
            // Draw main text
            ui.draw_text(t, style, {0, y_offset}, rl.WHITE)
        }
    }

    ui.end_draw()
}