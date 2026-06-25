package vcode
import ui "../raylib-ui"
import "core:fmt"
import rl "vendor:raylib"

Block :: struct {
    rec: ui.Rec,
    label: Label,
    peg_info: Peg_Info,
}
blocks: []Block = {
    {
        label={
            words={{text="Value is "}, {text="."}},
            holes={{}},
            order={.Word,.Hole,.Word},
        },
        peg_info={
            top=Peg{},
            bottom=Peg{},
            left=Peg{},
        }
    },
        {
        label={
            words={{text="IDK "}, {text="."}},
            holes={{}},
            order={.Word,.Hole,.Word},
        },
        peg_info={
            top=Peg{},
            bottom=Peg{},
            left=Peg{},
        }
    }
}
held_block := -1
Label :: struct {
    words: []Label_Word,
    holes: []Label_Hole,
    order: []Label_Item_Type,
    rec: ui.Rec,
}
Label_Word :: struct {
    text: string,
    style: ui.Text_Style,
    item: Label_Item,
}
Label_Hole :: struct {
    item: Label_Item,
}
Label_Item :: struct {
    rec: ui.Rec,
}
Label_Item_Type :: enum{Word, Hole}

Peg_Info :: struct {
    top: Maybe(Peg),
    bottom: Maybe(Peg),
    left: Maybe(Peg),
    right: []Peg,
}
Peg :: struct {
    rec: ui.Rec,
    hitbox: ui.Rec,
}

camera: ui.Camera
init :: proc() {
    camera = ui.create_camera()
}

update :: proc() {
    ui.camera_set_viewport(&camera)
    for &block in blocks {
        calculate_block(&block)
    }
    mouse := ui.get_mouse_pos_local(camera)
    if ui.is_mouse_button_pressed(.LEFT) {
        for block, i in blocks {
            if ui.contains_point(block.label.rec, mouse) {
                held_block = i
            }
        }
    }
    if ui.is_mouse_button_released(.LEFT) && held_block != -1 {
        block1 := &blocks[held_block]
        info1 := &block1.peg_info
        for &block2, i in blocks {
            info2 := &block2.peg_info
            if held_block == i do continue
            if peg1, ok := info1.top.(Peg); ok do if peg2, ok := info2.bottom.(Peg); ok {
                try_join_blocks(block1, block2, peg1, peg2, .Top_Left, .Bottom_Left)
            }
            if peg1, ok := info1.bottom.(Peg); ok do if peg2, ok := info2.top.(Peg); ok {
                try_join_blocks(block1, block2, peg1, peg2, .Bottom_Left, .Top_Left)
            }
        }
        held_block = -1
    }
    if held_block != -1 {
        block := &blocks[held_block]
        block.rec.pos = mouse - block.label.rec.size/2
    }
    try_join_blocks :: proc(block1: ^Block, block2: Block, peg1, peg2: Peg, anchor1, anchor2: ui.Anchor) -> (joined: bool) {
        if ui.overlaps(peg1.hitbox, peg2.hitbox) {
            block1.rec = ui.align_at(block1.rec, anchor1, block2.rec, anchor2)
            calculate_block(block1)
            return true
        }
        return false
    }
}
calculate_block :: proc(block: ^Block) {
    calculate_label(&block.label, block.rec.pos)
    block.rec.size = block.label.rec.size
    calculate_peg_info(&block.peg_info, block.rec)
}
calculate_label :: proc(label: ^Label, pos: ui.Vec) {
    label.rec.pos = pos
    pos := pos
    ti, hi: int
    for order in label.order {
        item: ^Label_Item
        switch order {
        case .Word:
            text := &label.words[ti]
            item = &text.item
            text.style = ui.make_text_style(5)
            item.rec.size = ui.measure_text_size(text.text, text.style)
            ti += 1
        case .Hole:
            hole := &label.holes[hi]
            item = &hole.item
            item.rec.size = {30, 5}
            hi += 1
        }
        item.rec.pos = pos
        pos.x += item.rec.size.x
    }
    label.rec.size = {pos.x-label.rec.pos.x, 5} + 3
}
calculate_peg_info :: proc(info: ^Peg_Info, rec: ui.Rec) {
    dist := f32(2.5)
    height := f32(2.5)
    width := f32(2)  
    if peg, ok := &info.top.(Peg); ok {
        at := ui.align_at({{},{width,height}}, .Bottom_Left, rec, .Top_Left)
        peg.rec = ui.move(at, {dist,0})
        peg.hitbox = ui.resize(peg.rec, .Center, peg.rec.size)
    }
    if peg, ok := &info.bottom.(Peg); ok {
        at := ui.align({{},{width,height}}, rec, .Bottom_Left)
        peg.rec = ui.move(at, {dist,0})
        peg.hitbox = ui.resize(peg.rec, .Center, peg.rec.size)
    }
    if peg, ok := &info.left.(Peg); ok {
        at := ui.align({{},{height,width}}, rec, .Top_Left)
        peg.rec = ui.move(at, {0,dist})
        peg.hitbox = ui.resize(peg.rec, .Center, peg.rec.size)
    }
}
draw :: proc() {
    ui.begin_draw(&camera)
    for &block in blocks {
        label := &block.label
        ui.draw_rec(label.rec, ui.GREEN)
        for word in label.words {
            ui.draw_text(word.text, word.style, word.item.rec.pos, ui.WHITE)
        }
        for hole in label.holes {
            ui.draw_rec(hole.item.rec, ui.WHITE)
        }
        info := &block.peg_info
        if peg, ok := &info.bottom.(Peg); ok {
            ui.draw_rec(peg.rec, ui.BLACK)
        }
        if peg, ok := &info.left.(Peg); ok {
            ui.draw_rec(peg.rec, ui.BLACK)
        }
    }
    for &block in blocks {
        info := &block.peg_info
        if peg, ok := &info.top.(Peg); ok {
            ui.draw_rec(peg.rec, ui.GREEN)
        }
    }
    ui.end_draw()
}