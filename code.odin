package voxel_game
import ui "./raylib-ui"
import "core:fmt"
import rl "vendor:raylib"

workspace: ui.Rec
workspace_zoom: f32 = 1
workspace_zoomed: ui.Rec
Code_State :: struct {
    cam: rl.Camera2D,
    in_code: bool,

    holding_cblock: int,
    cblocks: []Cblock,
}
Cblock :: struct {
    rec: ui.Rec,
    color: rl.Color,
    type: union{CWrap},
    child: int,
}
CWrap :: struct {
    child: int,
    up, left, bottom: ui.Rec,
}
cst: ^Code_State
init_code :: proc() {
    cst = &state.code
    cst^ = {
        cam = {zoom=1},
        in_code = false,

        holding_cblock = -1,
        cblocks = make([]Cblock, 4)
    }
    for &cblock in cst.cblocks {
        cblock.child = -1
    }
    copy(cst.cblocks, []Cblock{
        {{{},{100, 50}}, rl.RED, nil, -1},
        {{{},{100, 50}}, rl.BLUE, nil, -1},
        {{{},{100, 50}}, rl.WHITE, nil, -1},
        {{{},{100, 50}}, rl.PINK, CWrap{}, -1},
    })

    calc_code_window()
    cblocks_to_relative()
}
update_code :: proc() {
    if rl.IsKeyPressed(.C) {
        cst.in_code = !cst.in_code
    }
    if !cst.in_code do return
    calc_code_window()

    mouse := rl.GetMousePosition()

    //CBLOCK INTERACTION
    cblocks_to_absolute()
    if rl.IsMouseButtonPressed(.LEFT) {
    #reverse for &cblock, i in cst.cblocks {
        if ui.contains_point(cblock.rec, mouse) {
            cst.holding_cblock = i
            break
        }
    }}
    if rl.IsMouseButtonReleased(.LEFT) && cst.holding_cblock != -1 {
        cblock_i := cst.holding_cblock
        cblock := &cst.cblocks[cst.holding_cblock]
        cblock_unchild(cblock_i)
        #reverse for &check, check_i in cst.cblocks {
            if cblock_i == check_i do continue

            rec := cblock.rec
            check_box_top := ui.Rec{rec.pos, {rec.size.x, rec.size.y/2}}
            check_box_bottom := ui.Rec{rec.pos, {rec.size.x, rec.size.y/2}}
            check_box_bottom.pos.y += rec.size.y

            if ui.overlaps(check_box_bottom, cblock.rec) && check.child == -1 {
                cursor: f32
                ui.write(.Bottom, check.rec.size, check.rec.pos, &cursor)
                cblock.rec = ui.write(.Bottom, cblock.rec.size, check.rec.pos, &cursor)
                cblock_update_children(cblock^)
                check.child = cblock_i
            }
        }
        cst.holding_cblock = -1
    }
    if cst.holding_cblock != -1 {
        cblock := &cst.cblocks[cst.holding_cblock]
        cblock.rec.pos = mouse - cblock.rec.size/2
        cblock_update_children(cblock^)
    }
    cblocks_to_relative()
}
draw_code :: proc() {
    if !cst.in_code do return
    rl.BeginMode2D(cst.cam)
    defer rl.EndMode2D()

    screen := Vec2{f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}
    center := screen/2
    
    cblocks_to_absolute()
    for cblock in cst.cblocks {
        ui.draw_rec(cblock.rec, cblock.color)
    }
    cblocks_to_relative()
}

cblock_unchild :: proc(cblock: int) {
    for &parent in cst.cblocks {
        if parent.child == cblock {
            parent.child = -1
            break
        }
    }
}
cblock_update_children :: proc(cblock: Cblock) {
    cursor: f32
    from := cblock.rec.pos
    ui.write(.Bottom, cblock.rec.size, from, &cursor)
    child: ^Cblock
    for parent := cblock; parent.child != -1; parent = child^ {
        child = &cst.cblocks[parent.child]
        child.rec = ui.write(.Bottom, child.rec.size, from, &cursor)
    }
}

//HELPER
calc_code_window :: proc() {
    workspace = {{}, screen}
    workspace_zoomed = {workspace.pos, workspace.size*workspace_zoom}
}
cblocks_to_relative :: proc() {
    for &cblock in cst.cblocks {
        cblock.rec = ui.to_relative_rec(cblock.rec, workspace_zoomed)
    }
}
cblocks_to_absolute :: proc() {
    for &cblock in cst.cblocks {
        cblock.rec = ui.to_absolute_rec(cblock.rec, workspace_zoomed)
    }
}