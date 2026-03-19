package voxel_game
import rl "vendor:raylib"
import "core:fmt"
import ui "../raylib-ui"

Color :: rl.Color
Rec :: ui.Rec

cam2 := rl.Camera2D{zoom=1}
in_code: bool
mouse_lock_last: bool


//DRAW
element_size := Vec2{.20, .10}

window, menu: Rec

Node :: struct {
    text: string,
    type: Node_Type,
    color: rl.Color,
}
Node_Type :: enum {
    Expr, Bool, 
}
CBlock :: struct {
    cblock_index: int,
    rec: Rec,
}

nodes := [?]Node{
    {"Setblock", .Expr, rl.RED},
    {"Teleport", .Expr, rl.PINK},
}
cblocks: [dynamic]CBlock

init_code :: proc() {
}
update_code :: proc() {
    if rl.IsKeyPressed(.C) {
        in_code = !in_code
    }
    if !in_code do return


    screenf := to_vec2(screen)
    window = Rec{{}, screenf}
    rec := Rec{{}, window.size * element_size}
    rec_margin := ui.padding(rec, -ui.vmin(rec.size)*0.10)
update_menu: {
    window, menu = ui.cut(window, .Left, rec_margin.size.x)
    menu_cursor: f32
    for node, i in nodes {
        rec_margin := ui.write(.Bottom, rec_margin, menu.pos, &menu_cursor)
        rec := ui.align(rec.size, rec_margin, .Center)
        append(&cblocks, CBlock{i, rec})
    }
}}
draw_code :: proc() {
    if !in_code do return
    rl.BeginMode2D(cam2)
    defer rl.EndMode2D()

    ui.draw_rec(window, {0,0,0,50})
    ui.draw_rec(menu, rl.WHITE)
    for cblock in cblocks {
        ui.draw_rec(cblock.rec, nodes[cblock.cblock_index].color)
    }
}