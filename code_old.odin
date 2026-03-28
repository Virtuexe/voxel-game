package voxel_game
// import rl "vendor:raylib"
// import "core:container/rbtree"
// import "core:fmt"
// import ui "../raylib-ui"

// Color :: rl.Color
// Rec :: ui.Rec

// cam2 := rl.Camera2D{zoom=1}
// in_code: bool
// zoom: f32 = 1


// //DRAW
// cblock_size := Vec2{.20, .10}

// window, menu: Rec

// Node :: struct {
//     text: string,
//     type: Node_Type,
//     color: rl.Color,
// }
// Node_Type :: enum {
//     Expr, Bool, 
// }
// CBlock :: struct {
//     cblock_index: int,
//     rec: Rec,
// }

// nodes := [?]Node{
//     {"Setblock", .Expr, rl.RED},
//     {"Teleport", .Expr, rl.PINK},
// }

// menu_cblock_recs: [len(nodes)]Rec
// cblocks: [dynamic]CBlock
// holding := -1

// init_code :: proc() {
// }
// update_code :: proc() {
//     if rl.IsKeyPressed(.C) {
//         in_code = !in_code
//     }
//     if !in_code do return

//     wheel := rl.GetMouseWheelMove()
//     zoom += wheel*0.01

//     window = Rec{{}, to_vec2(screen)}
//     cblock_rec_tmp := Rec{{}, window.size * cblock_size}
//     cblock_margin_tmp := ui.inset(cblock_rec_tmp, -ui.vmin(cblock_rec_tmp.size)*0.10)

//     window, menu = ui.cut(window, .Left, cblock_margin_tmp.size.x)


//     menu_cursor: f32
//     for node, i in nodes {
//         rec_margin := ui.write(.Bottom, cblock_margin_tmp, menu.pos, &menu_cursor)
//         cblock_rec := ui.align(cblock_rec_tmp.size, rec_margin, .Center)
//         cblock_rec = ui.to_relative_rec(cblock_rec, window)
//         menu_cblock_recs[i] = cblock_rec
//     }
// update_interact: {
//     mouse := rl.GetMousePosition()
//     click: if rl.IsMouseButtonPressed(.LEFT) {
//         for cblock, i in cblocks {
//             rec := ui.to_absolute_rec(cblock.rec, window)
//             if !ui.contains_point(rec, mouse) do continue
//             holding = i
//             break click
//         }
//         for rec, i in menu_cblock_recs {
//             rec := ui.to_absolute_rec(rec, window)
//             if !ui.contains_point(rec, mouse) do continue
//             holding = len(cblocks)
//             rec.pos = mouse
//             rec = ui.center(rec)
//             rec = ui.to_relative_rec(rec, window)
//             append(&cblocks, CBlock{i, rec})
//         }
//     }
//     else if rl.IsMouseButtonReleased(.LEFT) && holding != -1 {
//         mouse := ui.to_relative_point(mouse, window)
//         snapped: bool
//         check_all_blocks: for &cblock, i in cblocks {
//             if holding == i do continue 
//             check_box := ui.inset_vec(cblock.rec, -cblock.rec.size/2)
//             if !ui.contains_point(check_box, mouse) do continue

//             for side in ui.Side {
//                 dir := ui.get_dir(side)
//                 rec := Rec{cblock.rec.pos + dir*cblock.rec.size*0.5, cblock.rec.size}
//                 rec, _ = ui.cut(rec, ui.get_opposite_side(side), rec.size[ui.get_axis(side)]*0.5)
//                 if ui.contains_point(rec, mouse) {
//                     snapped = true
//                     cursor: f32
//                     ui.write(side, cblock.rec, cblock.rec.pos, &cursor)
//                     cblocks[holding].rec = ui.write(side, cblocks[holding].rec, cblock.rec.pos, &cursor)
//                     break check_all_blocks
//                 } 
//             }
//         }
//         window_relative := ui.to_relative_rec(window, window)
//         if !snapped && !ui.contains_rec(window_relative, cblocks[holding].rec) {
//             unordered_remove(&cblocks, holding)
//         } 
//         holding = -1
//     }
//     if holding != -1 {
//         cblock := &cblocks[holding]
//         cblock.rec.pos += ui.to_relative_vec(rl.GetMouseDelta(), window.size)
//     }
// }
// }
// draw_code :: proc() {
//     if !in_code do return
//     rl.BeginMode2D(cam2)
//     defer rl.EndMode2D()

//     ui.draw_rec(window, {0,0,0,50})
//     ui.draw_rec(menu, rl.WHITE)
//     for rec, i in menu_cblock_recs {
//         rec := ui.to_absolute_rec(rec, window)
//         ui.draw_rec(rec, nodes[i].color)
//     }
//     for cblock in cblocks {
//         rec := ui.to_absolute_rec(cblock.rec, window)
//         ui.draw_rec(rec, nodes[cblock.cblock_index].color)
//     }
// }