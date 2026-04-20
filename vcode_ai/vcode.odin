package vcode

import rl   "vendor:raylib"
import "core:strings"
import "core:math"
import "core:fmt"

// ══════════════════════════════════════════════════════════════════
//  LAYOUT CONSTANTS  (all in screen pixels unless noted)
// ══════════════════════════════════════════════════════════════════
//
//   ┌──────────┬──────────────────┬──────────────────────────────┐
//   │ CAT_STRIP│   BLOCK PALETTE  │         WORKSPACE            │
//   │  (72px)  │    (168px)       │  (rest of screen)            │
//   └──────────┴──────────────────┴──────────────────────────────┘
//
CAT_W     :: f32(72)          // category button strip
PAL_W     :: f32(180)         // block palette
SIDEBAR_W :: CAT_W + PAL_W   // total left sidebar width

// Block sizes in CANVAS UNITS (1 canvas unit = 1 pixel at zoom 1)
WS_BW    :: f32(200)   // statement / wrapper block width
EX_BW    :: f32(90)    // expression block width
EX_BH    :: f32(26)    // expression block height
BL_BH    :: f32(40)    // statement block height

SL_W     :: f32(54)    // empty expression slot width
SL_H     :: f32(22)    // empty expression slot height

WRAP_TOP :: f32(40)    // C-block header height
WRAP_BOT :: f32(18)    // C-block footer height
BODY_IND :: f32(20)    // body indentation

PAD      :: f32(8)     // generic padding

FONT_SZ  :: i32(16)
SMALL_SZ :: i32(13)

MAX_DEFS  :: 256
MAX_BLKS  :: 1024
MAX_SLOTS :: 4

// ══════════════════════════════════════════════════════════════════
//  TYPES
// ══════════════════════════════════════════════════════════════════

Category :: enum u8 { Motion, Control, Logic, Math, Text, Variables }

CAT_NAME := [Category]string{
    .Motion = "Motion", .Control = "Control", .Logic = "Logic",
    .Math = "Math", .Text = "Text", .Variables = "Vars",
}
CAT_COLOR := [Category]rl.Color{
    .Motion    = { 70,130,220,255},
    .Control   = {210,120, 40,255},
    .Logic     = {160, 80,200,255},
    .Math      = { 50,165, 80,255},
    .Text      = {200, 60,110,255},
    .Variables = {220, 70, 70,255},
}

Block_Shape :: enum u8 { Hat, Statement, Expression, Wrapper, WrapperElse }
Val_Type    :: enum u8 { Any, Bool, Int, Float, String }

val_color :: proc(t: Val_Type) -> rl.Color {
    switch t {
    case .Bool:   return {150, 70,190,255}
    case .Int:    return { 40,155, 70,255}
    case .Float:  return { 60,185,120,255}
    case .String: return {200, 50, 80,255}
    case .Any:    return {110,110,120,255}
    }
    return {80,80,80,255}
}

Block_Def :: struct {
    id, label:  string,
    category:   Category,
    shape:      Block_Shape,
    out_type:   Val_Type,
    color:      rl.Color,
    slot_count: int,
    slot_types: [MAX_SLOTS]Val_Type,
    has_text:   bool,
}

// A live block instance.
// canvas_pos = top-left in canvas coordinates (zoom-independent).
Block :: struct {
    def:        int,                  // index into ctx.defs; -1 = dead
    canvas_pos: rl.Vector2,          // position in canvas space
    parent:     int,                  // -1 = root
    child:      int,                  // next in sequence
    body:       int,                  // first child of wrapper body
    body_else:  int,                  // first child of else body
    slots:      [MAX_SLOTS]int,      // expression filling slot N; -1 = empty
    // computed each frame (screen space, updated during layout)
    scr_rec:    rl.Rectangle,
    scr_slots:  [MAX_SLOTS]rl.Rectangle,
    // text editing
    text:       [64]u8,
    text_len:   int,
}

Context :: struct {
    defs:      [MAX_DEFS]Block_Def,
    def_count: int,
    blocks:    [MAX_BLKS]Block,
    blk_count: int,

    // ── selection / drag ─────────────────────────────────────────
    // When holding >= 0, the block follows the mouse.
    // hold_off = vector from block's canvas_pos to the canvas point
    //            where the user grabbed it.
    holding:   int,
    hold_off:  rl.Vector2,

    // ── text editing ─────────────────────────────────────────────
    active_txt: int,  // -1 = none

    // ── category / palette ───────────────────────────────────────
    cat:        Category,
    pal_scroll: f32,

    // ── viewport (workspace) ─────────────────────────────────────
    // ws_origin = screen pixel coordinate of canvas (0,0)
    // i.e.  screen_pos = ws_origin + canvas_pos * zoom
    ws_origin:  rl.Vector2,
    zoom:       f32,
    panning:    bool,
    pan_ms:     rl.Vector2,  // mouse position when pan started
    pan_os:     rl.Vector2,  // ws_origin when pan started
}

// ══════════════════════════════════════════════════════════════════
//  COORDINATE HELPERS
// ══════════════════════════════════════════════════════════════════

@private
c2s :: #force_inline proc(ctx: ^Context, cp: rl.Vector2) -> rl.Vector2 {
    return ctx.ws_origin + cp * ctx.zoom
}
@private
s2c :: #force_inline proc(ctx: ^Context, sp: rl.Vector2) -> rl.Vector2 {
    return (sp - ctx.ws_origin) / ctx.zoom
}
@private
c2r :: proc(ctx: ^Context, cx, cy, cw, ch: f32) -> rl.Rectangle {
    sp := c2s(ctx, {cx, cy})
    return {sp.x, sp.y, cw * ctx.zoom, ch * ctx.zoom}
}

// ══════════════════════════════════════════════════════════════════
//  BLOCK GEOMETRY (canvas units)
// ══════════════════════════════════════════════════════════════════

block_w :: proc(d: ^Block_Def) -> f32 {
    return EX_BW if d.shape == .Expression else WS_BW
}

block_own_h :: proc(ctx: ^Context, idx: int) -> f32 {
    if idx < 0 { return 0 }
    b := &ctx.blocks[idx]
    if b.def < 0 { return 0 }
    d := &ctx.defs[b.def]
    switch d.shape {
    case .Expression:       return EX_BH
    case .Hat, .Statement:  return BL_BH
    case .Wrapper:
        bh := seq_h(ctx, b.body)
        return WRAP_TOP + max(bh, BL_BH) + WRAP_BOT
    case .WrapperElse:
        bh1 := seq_h(ctx, b.body)
        bh2 := seq_h(ctx, b.body_else)
        return WRAP_TOP + max(bh1, BL_BH) + WRAP_TOP + max(bh2, BL_BH) + WRAP_BOT
    }
    return BL_BH
}

seq_h :: proc(ctx: ^Context, first: int) -> (h: f32) {
    i := first
    for i != -1 {
        h += block_own_h(ctx, i)
        i  = ctx.blocks[i].child
    }
    return
}

// ══════════════════════════════════════════════════════════════════
//  LAYOUT  — update scr_rec / scr_slots for a whole tree
// ══════════════════════════════════════════════════════════════════

// Lay out the label of one block (canvas coords), return slot screen rects.
// `cx` starts at block.canvas_pos.x + PAD
compute_slots :: proc(ctx: ^Context, idx: int) {
    b := &ctx.blocks[idx]
    d := &ctx.defs[b.def]
    if d.slot_count == 0 { return }

    row_h: f32 = BL_BH
    if d.shape == .Expression                         { row_h = EX_BH }
    else if d.shape == .Wrapper || d.shape == .WrapperElse { row_h = WRAP_TOP }

    sl_cy := b.canvas_pos.y + (row_h - SL_H) * 0.5   // canvas y of slot holes
    cx    := b.canvas_pos.x + PAD

    label := d.label
    i     := 0
    slot_idx := 0
    for i < len(label) {
        if label[i] == '#' && i+1 < len(label) {
            n := int(label[i+1] - '0')
            if label[i+1] >= '0' && label[i+1] <= '9' && n < d.slot_count {
                sw := SL_W if b.slots[n] == -1 else EX_BW
                sp := c2s(ctx, {cx, sl_cy})
                b.scr_slots[n] = {sp.x, sp.y, sw * ctx.zoom, SL_H * ctx.zoom}
                cx += sw + 2
            }
            i += 2
            continue
        }
        if label[i] == '[' {
            cx += 58   // text field width (canvas)
            for i < len(label) && label[i] != ']' { i += 1 }
            i += 1
            continue
        }
        end := i + 1
        for end < len(label) && label[end] != '#' && label[end] != '[' { end += 1 }
        part := label[i:end]
        if len(part) > 0 {
            cs  := strings.clone_to_cstring(part, context.temp_allocator)
            tw  := f32(rl.MeasureText(cs, FONT_SZ))
            cx += tw + 3
        }
        i = end

        slot_idx += 1
    }
}

do_layout :: proc(ctx: ^Context, idx: int, cp: rl.Vector2) {
    if idx < 0 { return }
    b := &ctx.blocks[idx]
    if b.def < 0 { return }
    d := &ctx.defs[b.def]

    b.canvas_pos = cp
    w := block_w(d)
    h := block_own_h(ctx, idx)
    sp := c2s(ctx, cp)
    b.scr_rec = {sp.x, sp.y, w * ctx.zoom, h * ctx.zoom}

    compute_slots(ctx, idx)

    // Layout slot children
    for s in 0..<d.slot_count {
        sid := b.slots[s]
        if sid < 0 { continue }
        // child canvas pos derived from slot screen rect
        sr  := b.scr_slots[s]
        scp := s2c(ctx, {sr.x, sr.y})
        do_layout(ctx, sid, scp)
    }

    // Layout wrapper bodies
    #partial switch d.shape {
    case .Wrapper:
        ip := rl.Vector2{cp.x + BODY_IND, cp.y + WRAP_TOP}
        c  := b.body
        for c != -1 {
            do_layout(ctx, c, ip)
            ip.y += block_own_h(ctx, c)
            c     = ctx.blocks[c].child
        }
    case .WrapperElse:
        ip := rl.Vector2{cp.x + BODY_IND, cp.y + WRAP_TOP}
        c  := b.body
        for c != -1 {
            do_layout(ctx, c, ip)
            ip.y += block_own_h(ctx, c)
            c     = ctx.blocks[c].child
        }
        bh1 := seq_h(ctx, b.body)
        ip2 := rl.Vector2{cp.x + BODY_IND, cp.y + WRAP_TOP + max(bh1, BL_BH) + WRAP_TOP}
        c    = b.body_else
        for c != -1 {
            do_layout(ctx, c, ip2)
            ip2.y += block_own_h(ctx, c)
            c       = ctx.blocks[c].child
        }
    }

    // Sequence child below this block
    if b.child != -1 && d.shape != .Expression {
        do_layout(ctx, b.child, {cp.x, cp.y + h})
    }
}

layout_all :: proc(ctx: ^Context) {
    for i in 0..<ctx.blk_count {
        b := &ctx.blocks[i]
        if b.def >= 0 && b.parent == -1 {
            do_layout(ctx, i, b.canvas_pos)
        }
    }
}

// ══════════════════════════════════════════════════════════════════
//  INTERNAL HELPERS
// ══════════════════════════════════════════════════════════════════

reg :: proc(ctx: ^Context, d: Block_Def) {
    assert(ctx.def_count < MAX_DEFS)
    ctx.defs[ctx.def_count] = d
    ctx.def_count += 1
}

blk_new :: proc(ctx: ^Context, def_idx: int, cp: rl.Vector2) -> int {
    if ctx.blk_count >= MAX_BLKS { return -1 }
    idx := ctx.blk_count
    ctx.blk_count += 1
    b           := &ctx.blocks[idx]
    b.def        = def_idx
    b.canvas_pos = cp
    b.parent     = -1
    b.child      = -1
    b.body       = -1
    b.body_else  = -1
    b.text_len   = 0
    for s in 0..<MAX_SLOTS { b.slots[s] = -1 }
    return idx
}

blk_detach :: proc(ctx: ^Context, idx: int) {
    if idx < 0 { return }
    for i in 0..<ctx.blk_count {
        p := &ctx.blocks[i]
        if p.child     == idx { p.child     = -1 }
        if p.body      == idx { p.body      = -1 }
        if p.body_else == idx { p.body_else = -1 }
        for s in 0..<MAX_SLOTS { if p.slots[s] == idx { p.slots[s] = -1 } }
    }
    ctx.blocks[idx].parent = -1
}

is_ancestor :: proc(ctx: ^Context, anc, of: int) -> bool {
    c := ctx.blocks[of].parent
    for d := 0; c != -1 && d < MAX_BLKS; d += 1 {
        if c == anc { return true }
        c = ctx.blocks[c].parent
    }
    return false
}

pt_in :: proc(r: rl.Rectangle, p: rl.Vector2) -> bool {
    return p.x >= r.x && p.x < r.x+r.width && p.y >= r.y && p.y < r.y+r.height
}

// ══════════════════════════════════════════════════════════════════
//  INIT
// ══════════════════════════════════════════════════════════════════

init :: proc(ctx: ^Context) {
    ctx^          = {}
    ctx.holding   = -1
    ctx.active_txt = -1
    ctx.zoom      = 1.0
    ctx.ws_origin = {SIDEBAR_W + 20, 20}   // initial viewport offset

    s  := Block_Shape.Statement
    e  := Block_Shape.Expression
    w  := Block_Shape.Wrapper
    we := Block_Shape.WrapperElse
    h  := Block_Shape.Hat

    mc := CAT_COLOR[.Motion]
    cc := CAT_COLOR[.Control]
    lc := CAT_COLOR[.Logic]
    ac := CAT_COLOR[.Math]
    tc := CAT_COLOR[.Text]
    vc := CAT_COLOR[.Variables]

    // ── Motion ────────────────────────────────────────────────────
    reg(ctx, {id="on_update",  label="when game updates",          category=.Motion, shape=h, color=mc})
    reg(ctx, {id="teleport",   label="teleport #0 #1 #2",          category=.Motion, shape=s, color=mc, slot_count=3, slot_types={.Float,.Float,.Float,{}}})
    reg(ctx, {id="move",       label="move #0",                    category=.Motion, shape=s, color=mc, slot_count=1, slot_types={.Any,{},{},{}}})
    reg(ctx, {id="set_block",  label="set block #0 #1 #2 to #3",  category=.Motion, shape=s, color=mc, slot_count=4, slot_types={.Int,.Int,.Int,.Any}})
    reg(ctx, {id="player_x",   label="player X",                   category=.Motion, shape=e, color=mc, out_type=.Float})
    reg(ctx, {id="player_y",   label="player Y",                   category=.Motion, shape=e, color=mc, out_type=.Float})
    reg(ctx, {id="player_z",   label="player Z",                   category=.Motion, shape=e, color=mc, out_type=.Float})

    // ── Control ───────────────────────────────────────────────────
    reg(ctx, {id="if",        label="if #0",            category=.Control, shape=w,  color=cc, slot_count=1, slot_types={.Bool,{},{},{}}})
    reg(ctx, {id="if_else",   label="if #0 / else",     category=.Control, shape=we, color=cc, slot_count=1, slot_types={.Bool,{},{},{}}})
    reg(ctx, {id="for_range", label="for i in 0..<#0", category=.Control, shape=w,  color=cc, slot_count=1, slot_types={.Int,{},{},{}}})
    reg(ctx, {id="repeat",    label="repeat #0 times",  category=.Control, shape=w,  color=cc, slot_count=1, slot_types={.Int,{},{},{}}})
    reg(ctx, {id="break",     label="break",            category=.Control, shape=s,  color={180,80,20,255}})
    reg(ctx, {id="continue",  label="continue",         category=.Control, shape=s,  color={180,80,20,255}})
    reg(ctx, {id="return",    label="return #0",        category=.Control, shape=s,  color={200,50,50,255}, slot_count=1, slot_types={.Any,{},{},{}}})

    // ── Logic ─────────────────────────────────────────────────────
    reg(ctx, {id="eq",    label="#0 == #1", category=.Logic, shape=e, out_type=.Bool, color=lc, slot_count=2, slot_types={.Any,.Any,{},{}}})
    reg(ctx, {id="neq",   label="#0 != #1", category=.Logic, shape=e, out_type=.Bool, color=lc, slot_count=2, slot_types={.Any,.Any,{},{}}})
    reg(ctx, {id="lt",    label="#0 < #1",  category=.Logic, shape=e, out_type=.Bool, color=lc, slot_count=2, slot_types={.Any,.Any,{},{}}})
    reg(ctx, {id="gt",    label="#0 > #1",  category=.Logic, shape=e, out_type=.Bool, color=lc, slot_count=2, slot_types={.Any,.Any,{},{}}})
    reg(ctx, {id="and",   label="#0 && #1", category=.Logic, shape=e, out_type=.Bool, color=lc, slot_count=2, slot_types={.Bool,.Bool,{},{}}})
    reg(ctx, {id="or",    label="#0 || #1", category=.Logic, shape=e, out_type=.Bool, color=lc, slot_count=2, slot_types={.Bool,.Bool,{},{}}})
    reg(ctx, {id="not",   label="! #0",     category=.Logic, shape=e, out_type=.Bool, color=lc, slot_count=1, slot_types={.Bool,{},{},{}}})
    reg(ctx, {id="true",  label="true",     category=.Logic, shape=e, out_type=.Bool, color={120,50,170,255}})
    reg(ctx, {id="false", label="false",    category=.Logic, shape=e, out_type=.Bool, color={120,50,170,255}})

    // ── Math ──────────────────────────────────────────────────────
    reg(ctx, {id="add",    label="#0 + #1",        category=.Math, shape=e, out_type=.Float, color=ac, slot_count=2, slot_types={.Any,.Any,{},{}}})
    reg(ctx, {id="sub",    label="#0 - #1",        category=.Math, shape=e, out_type=.Float, color=ac, slot_count=2, slot_types={.Any,.Any,{},{}}})
    reg(ctx, {id="mul",    label="#0 * #1",        category=.Math, shape=e, out_type=.Float, color=ac, slot_count=2, slot_types={.Any,.Any,{},{}}})
    reg(ctx, {id="div",    label="#0 / #1",        category=.Math, shape=e, out_type=.Float, color=ac, slot_count=2, slot_types={.Any,.Any,{},{}}})
    reg(ctx, {id="mod",    label="#0 % #1",        category=.Math, shape=e, out_type=.Float, color=ac, slot_count=2, slot_types={.Any,.Any,{},{}}})
    reg(ctx, {id="abs",    label="abs(#0)",        category=.Math, shape=e, out_type=.Float, color=ac, slot_count=1, slot_types={.Any,{},{},{}}})
    reg(ctx, {id="min2",   label="min(#0,#1)",     category=.Math, shape=e, out_type=.Float, color=ac, slot_count=2, slot_types={.Any,.Any,{},{}}})
    reg(ctx, {id="max2",   label="max(#0,#1)",     category=.Math, shape=e, out_type=.Float, color=ac, slot_count=2, slot_types={.Any,.Any,{},{}}})
    reg(ctx, {id="clamp",  label="clamp(#0,#1,#2)", category=.Math, shape=e, out_type=.Float, color=ac, slot_count=3, slot_types={.Any,.Any,.Any,{}}})
    reg(ctx, {id="lit_i",  label="[int]",          category=.Math, shape=e, out_type=.Int,   color={30,120,60,255},  has_text=true})
    reg(ctx, {id="lit_f",  label="[float]",        category=.Math, shape=e, out_type=.Float, color={30,120,60,255},  has_text=true})

    // ── Text ──────────────────────────────────────────────────────
    reg(ctx, {id="println", label="println #0",     category=.Text, shape=s, color=tc, slot_count=1, slot_types={.Any,{},{},{}}})
    reg(ctx, {id="str_cat", label="#0 + #1",        category=.Text, shape=e, out_type=.String, color=tc, slot_count=2, slot_types={.String,.String,{},{}}})
    reg(ctx, {id="str_len", label="len(#0)",        category=.Text, shape=e, out_type=.Int,    color=tc, slot_count=1, slot_types={.String,{},{},{}}})
    reg(ctx, {id="lit_str", label="[text]",         category=.Text, shape=e, out_type=.String, color={160,40,70,255}, has_text=true})

    // ── Variables ─────────────────────────────────────────────────
    reg(ctx, {id="decl_int",   label="int [name] := #0",   category=.Variables, shape=s, color=vc, slot_count=1, slot_types={.Int,{},{},{}},    has_text=true})
    reg(ctx, {id="decl_f32",   label="f32 [name] := #0",   category=.Variables, shape=s, color=vc, slot_count=1, slot_types={.Float,{},{},{}},  has_text=true})
    reg(ctx, {id="decl_bool",  label="bool [name] := #0",  category=.Variables, shape=s, color=vc, slot_count=1, slot_types={.Bool,{},{},{}},   has_text=true})
    reg(ctx, {id="decl_str",   label="str [name] := #0",   category=.Variables, shape=s, color=vc, slot_count=1, slot_types={.String,{},{},{}}, has_text=true})
    reg(ctx, {id="assign",     label="[name] = #0",        category=.Variables, shape=s, color=vc, slot_count=1, slot_types={.Any,{},{},{}},    has_text=true})
    reg(ctx, {id="add_asgn",   label="[name] += #0",       category=.Variables, shape=s, color=vc, slot_count=1, slot_types={.Any,{},{},{}},    has_text=true})
    reg(ctx, {id="var_ref",    label="[name]",             category=.Variables, shape=e, out_type=.Any,  color={190,60,60,255},  has_text=true})
    reg(ctx, {id="lit_bool",   label="[bool]",             category=.Variables, shape=e, out_type=.Bool, color={130,40,150,255}, has_text=true})
}

// ══════════════════════════════════════════════════════════════════
//  SNAP  (screen-space hit testing)
// ══════════════════════════════════════════════════════════════════

try_snap :: proc(ctx: ^Context, dropped: int, mouse: rl.Vector2) -> bool {
    d := &ctx.defs[ctx.blocks[dropped].def]

    for t in 0..<ctx.blk_count {
        if t == dropped || ctx.blocks[t].def < 0 { continue }
        if is_ancestor(ctx, dropped, t)           { continue }
        tb := &ctx.blocks[t]
        td := &ctx.defs[tb.def]

        // ── Slot snap (expression into slot hole) ──────────────
        if d.shape == .Expression {
            for s in 0..<td.slot_count {
                if tb.slots[s] != -1                        { continue }
                if !pt_in(tb.scr_slots[s], mouse)          { continue }
                tb.slots[s] = dropped
                ctx.blocks[dropped].parent = t
                return true
            }
        }

        // ── Sequence snap (statement/wrapper below another) ────
        if d.shape != .Expression && td.shape != .Expression {
            if tb.child != -1 { continue }
            // snap zone: bottom 14px of block's screen rect
            snap := rl.Rectangle{tb.scr_rec.x, tb.scr_rec.y + tb.scr_rec.height - 14,
                                  tb.scr_rec.width, 18}
            if !pt_in(snap, mouse) { continue }
            tb.child = dropped
            ctx.blocks[dropped].parent = t
            return true
        }

        // ── Body snap (into Wrapper / WrapperElse body) ────────
        if d.shape != .Expression &&
           (td.shape == .Wrapper || td.shape == .WrapperElse) {

            bh1_c := max(seq_h(ctx, tb.body), BL_BH)
            // body zone top-left in canvas
            body_cp := rl.Vector2{tb.canvas_pos.x + BODY_IND, tb.canvas_pos.y + WRAP_TOP}
            body_sp := c2s(ctx, body_cp)
            body_scr := rl.Rectangle{body_sp.x, body_sp.y,
                                     (WS_BW - BODY_IND) * ctx.zoom, bh1_c * ctx.zoom}

            if tb.body == -1 && pt_in(body_scr, mouse) {
                tb.body = dropped
                ctx.blocks[dropped].parent = t
                return true
            }

            if td.shape == .WrapperElse {
                bh2_c  := max(seq_h(ctx, tb.body_else), BL_BH)
                else_cy := tb.canvas_pos.y + WRAP_TOP + bh1_c + WRAP_TOP
                else_sp  := c2s(ctx, {tb.canvas_pos.x + BODY_IND, else_cy})
                else_scr := rl.Rectangle{else_sp.x, else_sp.y,
                                         (WS_BW - BODY_IND) * ctx.zoom, bh2_c * ctx.zoom}
                if tb.body_else == -1 && pt_in(else_scr, mouse) {
                    tb.body_else = dropped
                    ctx.blocks[dropped].parent = t
                    return true
                }
            }
        }
    }
    return false
}

// ══════════════════════════════════════════════════════════════════
//  UPDATE
// ══════════════════════════════════════════════════════════════════

update :: proc(ctx: ^Context, screen_rec: rl.Vector2) {
    sw, sh := screen_rec.x, screen_rec.y
    mouse  := rl.GetMousePosition()

    // Workspace screen rect (right of sidebar)
    ws := rl.Rectangle{SIDEBAR_W, 0, sw - SIDEBAR_W, sh}
    in_ws := pt_in(ws, mouse)

    // ── Update ws_origin so it always starts right of sidebar ────
    // ws_origin encodes the pan offset; x must never go left of SIDEBAR_W
    // (the base offset before pan is {SIDEBAR_W, 0})
    base_x := SIDEBAR_W + ctx.ws_origin.x - SIDEBAR_W   // = ctx.ws_origin.x; tracked freely
    // (we keep ws_origin.x >= SIDEBAR_W at rest; pan can shift it)

    // ── Zoom (Ctrl + scroll) ─────────────────────────────────────
    wheel := rl.GetMouseWheelMove()
    if in_ws && rl.IsKeyDown(.LEFT_CONTROL) && wheel != 0 {
        old  := ctx.zoom
        ctx.zoom = clamp(ctx.zoom * math.pow(f32(1.12), wheel), 0.2, 5.0)
        // zoom toward mouse
        ctx.ws_origin = mouse - (mouse - ctx.ws_origin) * (ctx.zoom / old)
    }

    // ── Pan (middle mouse or right mouse in workspace) ────────────
    if rl.IsMouseButtonPressed(.MIDDLE) && in_ws {
        ctx.panning = true
        ctx.pan_ms  = mouse
        ctx.pan_os  = ctx.ws_origin
    }
    if rl.IsMouseButtonReleased(.MIDDLE) { ctx.panning = false }
    if ctx.panning {
        ctx.ws_origin = ctx.pan_os + (mouse - ctx.pan_ms)
    }

    // ── Category clicks ───────────────────────────────────────────
    cat_h := sh / f32(len(Category))
    if rl.IsMouseButtonPressed(.LEFT) {
        for cat, ci in Category {
            btn := rl.Rectangle{0, f32(ci) * cat_h, CAT_W, cat_h}
            if pt_in(btn, mouse) {
                ctx.cat        = cat
                ctx.pal_scroll = 0
                break
            }
        }
    }

    // ── Palette scroll ────────────────────────────────────────────
    pal_rec := rl.Rectangle{CAT_W, 0, PAL_W, sh}
    if pt_in(pal_rec, mouse) && !rl.IsKeyDown(.LEFT_CONTROL) {
        ctx.pal_scroll -= wheel * 32
        if ctx.pal_scroll < 0 { ctx.pal_scroll = 0 }
    }

    // ── Build palette item list ───────────────────────────────────
    pal_defs: [MAX_DEFS]int
    pal_recs: [MAX_DEFS]rl.Rectangle
    pal_n := 0
    {
        cx := CAT_W + 6
        cy := f32(30) - ctx.pal_scroll
        for i in 0..<ctx.def_count {
            if ctx.defs[i].category != ctx.cat { continue }
            bh := EX_BH if ctx.defs[i].shape == .Expression else BL_BH
            pal_defs[pal_n] = i
            pal_recs[pal_n] = {cx, cy, PAL_W - 12, bh}
            pal_n += 1
            cy += bh + 5
        }
    }

    // ── Text editing ──────────────────────────────────────────────
    if ctx.active_txt != -1 {
        b := &ctx.blocks[ctx.active_txt]
        ch := rl.GetCharPressed()
        for ch != 0 {
            if b.text_len < 63 {
                b.text[b.text_len] = u8(ch)
                b.text_len += 1
            }
            ch = rl.GetCharPressed()
        }
        if rl.IsKeyPressed(.BACKSPACE) && b.text_len > 0 {
            b.text_len -= 1
        }
        if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.ESCAPE) {
            ctx.active_txt = -1
        }
        // click outside block to deactivate
        if rl.IsMouseButtonPressed(.LEFT) && !pt_in(b.scr_rec, mouse) {
            ctx.active_txt = -1
        }
    }

    // ── Mouse press: pick block ───────────────────────────────────
    if rl.IsMouseButtonPressed(.LEFT) && ctx.holding == -1 && ctx.active_txt == -1 {

        // 1) Workspace: pick existing block (front to back)
        if in_ws {
            for i := ctx.blk_count - 1; i >= 0; i -= 1 {
                b := &ctx.blocks[i]
                if b.def < 0 || !pt_in(b.scr_rec, mouse) { continue }
                ctx.holding = i
                // hold offset = difference from block's canvas_pos to mouse in canvas
                ctx.hold_off = s2c(ctx, mouse) - b.canvas_pos
                blk_detach(ctx, i)
                break
            }
        }

        // 2) Palette: spawn new block
        if ctx.holding == -1 {
            for i in 0..<pal_n {
                if !pt_in(pal_recs[i], mouse) { continue }
                // Spawn at canvas position under mouse
                cp := s2c(ctx, mouse) - {EX_BW * 0.5, EX_BH * 0.5}
                new_b := blk_new(ctx, pal_defs[i], cp)
                if new_b >= 0 {
                    ctx.holding  = new_b
                    ctx.hold_off = {EX_BW * 0.5, EX_BH * 0.5}
                }
                break
            }
        }
    }

    // ── Mouse held: move block ────────────────────────────────────
    if ctx.holding != -1 {
        new_cp := s2c(ctx, mouse) - ctx.hold_off
        ctx.blocks[ctx.holding].canvas_pos = new_cp
    }

    // ── Mouse release: snap or drop ───────────────────────────────
    if rl.IsMouseButtonReleased(.LEFT) && ctx.holding != -1 {
        h := ctx.holding
        ctx.holding = -1

        if !in_ws {
            // Dropped on sidebar → delete
            ctx.blocks[h].def = -1
            if ctx.active_txt == h { ctx.active_txt = -1 }
        } else {
            // Try to snap
            try_snap(ctx, h, mouse)

            // Activate text editing after drop (not during drag)
            if ctx.blocks[h].def >= 0 && ctx.defs[ctx.blocks[h].def].has_text {
                ctx.active_txt = h
            }
        }
    }

    // ── Full layout (updates all scr_rec / scr_slots) ─────────────
    layout_all(ctx)
}

// ══════════════════════════════════════════════════════════════════
//  DRAW HELPERS
// ══════════════════════════════════════════════════════════════════

drk :: proc(c: rl.Color) -> rl.Color { return {c.r/2, c.g/2, c.b/2, 255} }
lit :: proc(c: rl.Color, a: int) -> rl.Color {
    return {u8(min(int(c.r)+a,255)), u8(min(int(c.g)+a,255)), u8(min(int(c.b)+a,255)), 255}
}

fill  :: proc(r: rl.Rectangle, c: rl.Color) { rl.DrawRectangleRec(r, c) }
lines :: proc(r: rl.Rectangle, t: f32, c: rl.Color) { rl.DrawRectangleLinesEx(r, t, c) }

text_centered :: proc(t: cstring, r: rl.Rectangle, fs: i32, c: rl.Color) {
    tw := rl.MeasureText(t, fs)
    rl.DrawText(t, i32(r.x) + (i32(r.width) - tw) / 2,
                    i32(r.y) + (i32(r.height) - fs) / 2, fs, c)
}

// Draw a single block and recursively all children.
draw_block :: proc(ctx: ^Context, idx: int) {
    if idx < 0 { return }
    b := &ctx.blocks[idx]
    if b.def < 0 { return }
    d   := &ctx.defs[b.def]
    col := d.color
    dk  := drk(col)
    z   := ctx.zoom

    x, y := b.canvas_pos.x, b.canvas_pos.y
    w    := block_w(d)
    h    := block_own_h(ctx, idx)

    cvr :: proc(ctx: ^Context, cx, cy, cw, ch: f32) -> rl.Rectangle {
        sp := c2s(ctx, {cx, cy})
        return {sp.x, sp.y, cw * ctx.zoom, ch * ctx.zoom}
    }

    switch d.shape {

    case .Hat:
        r := cvr(ctx, x, y, w, h)
        fill(r, col) ; lines(r, 2, dk)
        // hat notch
        n := cvr(ctx, x+14, y+h-5, 20, 8)
        fill(n, lit(col, 50))

    case .Statement:
        r := cvr(ctx, x, y, w, h)
        fill(r, col) ; lines(r, 2, dk)
        // connector nub at bottom
        n := cvr(ctx, x+14, y+h-5, 20, 8)
        fill(n, lit(col, 50))

    case .Expression:
        r := cvr(ctx, x, y, w, h)
        fill(r, col) ; lines(r, 1, dk)

    case .Wrapper:
        bh := max(seq_h(ctx, b.body), BL_BH)
        // header
        fill(cvr(ctx, x, y, w, WRAP_TOP), col)
        lines(cvr(ctx, x, y, w, WRAP_TOP), 2, dk)
        // left arm
        fill(cvr(ctx, x, y+WRAP_TOP, BODY_IND, bh), col)
        lines(cvr(ctx, x, y+WRAP_TOP, BODY_IND, bh), 2, dk)
        // body bg hint
        if b.body == -1 {
            fill(cvr(ctx, x+BODY_IND, y+WRAP_TOP, w-BODY_IND, BL_BH),
                 rl.Color{col.r/5, col.g/5, col.b/5, 180})
        }
        // footer
        fill(cvr(ctx, x, y+WRAP_TOP+bh, w, WRAP_BOT), col)
        lines(cvr(ctx, x, y+WRAP_TOP+bh, w, WRAP_BOT), 2, dk)
        // connector nub
        fill(cvr(ctx, x+14, y+WRAP_TOP+bh+WRAP_BOT-5, 20, 8), lit(col, 50))

    case .WrapperElse:
        bh1 := max(seq_h(ctx, b.body), BL_BH)
        bh2 := max(seq_h(ctx, b.body_else), BL_BH)
        ey  := y + WRAP_TOP + bh1
        fy  := ey + WRAP_TOP + bh2
        // if header
        fill(cvr(ctx, x, y, w, WRAP_TOP), col) ; lines(cvr(ctx, x, y, w, WRAP_TOP), 2, dk)
        // then arm + body hint
        fill(cvr(ctx, x, y+WRAP_TOP, BODY_IND, bh1), col)
        lines(cvr(ctx, x, y+WRAP_TOP, BODY_IND, bh1), 2, dk)
        if b.body == -1 {
            fill(cvr(ctx, x+BODY_IND, y+WRAP_TOP, w-BODY_IND, BL_BH),
                 rl.Color{col.r/5, col.g/5, col.b/5, 180})
        }
        // else bar
        alt := lit(col, 30)
        fill(cvr(ctx, x, ey, w, WRAP_TOP), alt) ; lines(cvr(ctx, x, ey, w, WRAP_TOP), 2, dk)
        ep := c2s(ctx, {x + PAD, ey + (WRAP_TOP - f32(FONT_SZ))*0.5})
        rl.DrawTextEx(rl.GetFontDefault(), "else", ep, f32(FONT_SZ)*z, 1*z, rl.WHITE)
        // else arm + body hint
        fill(cvr(ctx, x, ey+WRAP_TOP, BODY_IND, bh2), col)
        lines(cvr(ctx, x, ey+WRAP_TOP, BODY_IND, bh2), 2, dk)
        if b.body_else == -1 {
            fill(cvr(ctx, x+BODY_IND, ey+WRAP_TOP, w-BODY_IND, BL_BH),
                 rl.Color{col.r/5, col.g/5, col.b/5, 180})
        }
        // footer
        fill(cvr(ctx, x, fy, w, WRAP_BOT), col) ; lines(cvr(ctx, x, fy, w, WRAP_BOT), 2, dk)
        fill(cvr(ctx, x+14, fy+WRAP_BOT-5, 20, 8), lit(col, 50))
    }

    // ── Draw label ────────────────────────────────────────────────
    row_h: f32 = BL_BH
    if d.shape == .Expression                           { row_h = EX_BH }
    else if d.shape == .Wrapper || d.shape == .WrapperElse { row_h = WRAP_TOP }

    label_y_canvas := y + (row_h - f32(FONT_SZ)) * 0.5
    slot_y_canvas  := y + (row_h - SL_H) * 0.5
    cx := x + PAD

    label := d.label
    i := 0
    for i < len(label) {
        // expression slot #N
        if label[i] == '#' && i+1 < len(label) && label[i+1] >= '0' && label[i+1] <= '9' {
            n := int(label[i+1] - '0')
            if n < d.slot_count {
                if b.slots[n] == -1 {
                    sc  := val_color(d.slot_types[n])
                    sr  := cvr(ctx, cx, slot_y_canvas, SL_W, SL_H)
                    bg  := rl.Color{sc.r/3, sc.g/3, sc.b/3, 220}
                    fill(sr, bg) ; lines(sr, 1, sc)
                    cx += SL_W + 2
                } else {
                    // filled slot — block drawn separately
                    cx += EX_BW + 2
                }
            }
            i += 2
            continue
        }

        // text field [...]
        if label[i] == '[' {
            fw  := f32(58)
            fr  := cvr(ctx, cx, slot_y_canvas, fw, SL_H)
            dark := rl.Color{col.r/3, col.g/3, col.b/3, 255}
            fill(fr, dark) ; lines(fr, 1, rl.WHITE)
            if b.text_len > 0 {
                ts := strings.string_from_ptr(&b.text[0], b.text_len)
                tc := strings.clone_to_cstring(ts, context.temp_allocator)
                tp := c2s(ctx, {cx + 3, slot_y_canvas + 4})
                rl.DrawTextEx(rl.GetFontDefault(), tc, tp, f32(SMALL_SZ)*z, 1*z, rl.WHITE)
            }
            cx += fw + 2
            for i < len(label) && label[i] != ']' { i += 1 }
            i += 1
            continue
        }

        // plain text
        end := i + 1
        for end < len(label) && label[end] != '#' && label[end] != '[' { end += 1 }
        part := label[i:end]
        if len(part) > 0 {
            pc := strings.clone_to_cstring(part, context.temp_allocator)
            tp := c2s(ctx, {cx, label_y_canvas})
            rl.DrawTextEx(rl.GetFontDefault(), pc, tp, f32(FONT_SZ)*z, 1*z, rl.WHITE)
            tw := f32(rl.MeasureText(pc, FONT_SZ))
            cx += tw + 2
        }
        i = end
    }

    // ── Slot children ─────────────────────────────────────────────
    for s in 0..<d.slot_count {
        if b.slots[s] != -1 { draw_block(ctx, b.slots[s]) }
    }

    // ── Body children ─────────────────────────────────────────────
    c := b.body
    for c != -1 { draw_block(ctx, c) ; c = ctx.blocks[c].child }
    c = b.body_else
    for c != -1 { draw_block(ctx, c) ; c = ctx.blocks[c].child }

    // ── Sequence child ────────────────────────────────────────────
    if b.child != -1 { draw_block(ctx, b.child) }

    // ── Text-edit outline ─────────────────────────────────────────
    if ctx.active_txt == idx {
        rl.DrawRectangleLinesEx(
            {b.scr_rec.x-2, b.scr_rec.y-2, b.scr_rec.width+4, b.scr_rec.height+4},
            2, rl.YELLOW)
    }
}

// ══════════════════════════════════════════════════════════════════
//  DRAW  (main entry — called every frame)
// ══════════════════════════════════════════════════════════════════

draw :: proc(ctx: ^Context, screen: rl.Vector2) {
    sw, sh := screen.x, screen.y

    // ── Workspace (right of sidebar) ──────────────────────────────
    ws := rl.Rectangle{SIDEBAR_W, 0, sw - SIDEBAR_W, sh}
    fill(ws, {22, 22, 34, 255})

    // dot grid aligned to camera
    z       := ctx.zoom
    step    := f32(28) * z
    ox      := math.mod(ctx.ws_origin.x - SIDEBAR_W, step)
    oy      := math.mod(ctx.ws_origin.y, step)
    if ox < 0 { ox += step }
    if oy < 0 { oy += step }
    dcol := rl.Color{44, 44, 66, 255}
    gy := oy
    for gy < sh {
        gx := SIDEBAR_W + ox
        for gx < sw {
            rl.DrawPixelV({gx, gy}, dcol)
            gx += step
        }
        gy += step
    }

    // Scissor workspace so blocks cannot bleed over sidebar
    rl.BeginScissorMode(i32(SIDEBAR_W), 0, i32(sw - SIDEBAR_W), i32(sh))
    for i in 0..<ctx.blk_count {
        b := &ctx.blocks[i]
        if b.def < 0 || b.parent != -1 || i == ctx.holding { continue }
        draw_block(ctx, i)
    }
    if ctx.holding != -1 { draw_block(ctx, ctx.holding) }
    rl.EndScissorMode()

    // ── Sidebar base ──────────────────────────────────────────────
    fill({0, 0, SIDEBAR_W, sh}, {30, 30, 42, 255})

    // ── Category strip (LEFT: 0..CAT_W) ──────────────────────────
    fill({0, 0, CAT_W, sh}, {22, 22, 32, 255})
    cat_h := sh / f32(len(Category))
    for cat, ci in Category {
        by  := f32(ci) * cat_h
        btn := rl.Rectangle{0, by, CAT_W, cat_h}
        c   := CAT_COLOR[cat]

        if cat == ctx.cat {
            fill(btn, c)
            // active indicator: right-side stripe
            fill({CAT_W-4, by, 4, cat_h}, rl.WHITE)
        } else {
            fill(btn, drk(c))
        }
        cn := strings.clone_to_cstring(CAT_NAME[cat], context.temp_allocator)
        text_centered(cn, btn, SMALL_SZ, rl.WHITE)

        if ci > 0 {
            rl.DrawLineV({0, by}, {CAT_W, by}, {0,0,0,60})
        }
    }
    // divider between cat strip and palette
    rl.DrawLineV({CAT_W, 0}, {CAT_W, sh}, {0,0,0,100})

    // ── Block palette (CAT_W .. SIDEBAR_W) ────────────────────────
    pal_rec := rl.Rectangle{CAT_W, 0, PAL_W, sh}
    fill(pal_rec, {38, 38, 52, 255})

    // palette header
    hdr := rl.Rectangle{CAT_W, 0, PAL_W, 26}
    fill(hdr, CAT_COLOR[ctx.cat])
    hn := strings.clone_to_cstring(CAT_NAME[ctx.cat], context.temp_allocator)
    text_centered(hn, hdr, SMALL_SZ, rl.WHITE)

    // scissor palette items
    rl.BeginScissorMode(i32(CAT_W), 26, i32(PAL_W), i32(sh-26))
    {
        cx := CAT_W + 6
        cy := f32(32) - ctx.pal_scroll
        for i in 0..<ctx.def_count {
            def := &ctx.defs[i]
            if def.category != ctx.cat { continue }
            bh := EX_BH if def.shape == .Expression else BL_BH
            r  := rl.Rectangle{cx, cy, PAL_W - 12, bh}
            fill(r, def.color)
            lines(r, 1, drk(def.color))
            lc := strings.clone_to_cstring(def.label, context.temp_allocator)
            rl.DrawText(lc, i32(cx)+5, i32(cy) + (i32(bh)-FONT_SZ)/2, FONT_SZ, rl.WHITE)
            cy += bh + 5
        }
    }
    rl.EndScissorMode()

    // divider between sidebar and workspace
    rl.DrawLineV({SIDEBAR_W, 0}, {SIDEBAR_W, sh}, {0,0,0,130})

    // ── Zoom indicator & help text ────────────────────────────────
    zoom_s := fmt.ctprintf("%d%%", i32(ctx.zoom*100))
    rl.DrawText(zoom_s, i32(SIDEBAR_W)+8, 6, 11, {200,200,200,140})
    rl.DrawText("Ctrl+Scroll=zoom  MMB=pan  drop on sidebar=delete  C=close",
                i32(SIDEBAR_W)+8, i32(sh)-16, 10, {180,180,180,100})
}
