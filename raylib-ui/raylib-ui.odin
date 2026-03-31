package raylib_ui

import rl "vendor:raylib"

Vec2 :: rl.Vector2 
Color :: rl.Color

Rec :: struct {
    pos, size: Vec2, 
}

Anchor :: enum {
    Top_Left, Top_Center, Top_Right,
    Center_Left, Center, Center_Right,
    Bottom_Left, Bottom_Center, Bottom_Right
}

Side :: enum {
    Left, Right, Top, Bottom
}
get_axis :: proc(side: Side) -> int {
    switch side {
    case .Left, .Right:
        return 0
    case .Top, .Bottom:
        return 1
    }
    return -1
}
get_dir :: proc(side: Side) -> Vec2 {
    switch side {
    case .Left: return {-1,0}
    case .Right: return {1,0}
    case .Top: return {0,-1}
    case .Bottom: return {0,1}
    }
    return {}
}
get_opposite_side :: proc(side: Side) -> Side {
    switch side {
    case .Left: return .Right
    case .Right: return .Left
    case .Top: return .Bottom
    case .Bottom: return .Top
    }
    return {}
}

vmin :: proc(v: Vec2) -> f32 {
    return min(v.x, v.y)
}

contains_point :: proc(rec: Rec, point: Vec2) -> bool {
    return point.x >= rec.pos.x && 
           point.x <= rec.pos.x + rec.size.x &&
           point.y >= rec.pos.y && 
           point.y <= rec.pos.y + rec.size.y
}
contains_rec :: proc(outer: Rec, inner: Rec) -> bool {
    return inner.pos.x >= outer.pos.x &&
           inner.pos.y >= outer.pos.y &&
           (inner.pos.x + inner.size.x) <= (outer.pos.x + outer.size.x) &&
           (inner.pos.y + inner.size.y) <= (outer.pos.y + outer.size.y)
}
overlaps :: proc(a: Rec, b: Rec) -> bool {
    return a.pos.x < (b.pos.x + b.size.x) &&
           (a.pos.x + a.size.x) > b.pos.x &&
           a.pos.y < (b.pos.y + b.size.y) &&
           (a.pos.y + a.size.y) > b.pos.y
}

draw_rec :: proc(rec: Rec, color: Color) {
    rl.DrawRectangleRec({rec.pos.x, rec.pos.y, rec.size.x, rec.size.y}, color)
}

center :: proc(rec: Rec) -> Rec {
    return {rec.pos - rec.size/2, rec.size}
}
align :: proc(rec_size: Vec2, target: Rec, anchor: Anchor) -> (res: Rec) {
    res = {{}, rec_size}

    #partial switch anchor {
    case .Top_Left, .Center_Left, .Bottom_Left:
        res.pos.x = target.pos.x
    case .Top_Center, .Center, .Bottom_Center:
        res.pos.x = target.pos.x + (target.size.x - res.size.x) / 2.0
    case .Top_Right, .Center_Right, .Bottom_Right:
        res.pos.x = target.pos.x + target.size.x - res.size.x
    }

    #partial switch anchor {
    case .Top_Left, .Top_Center, .Top_Right:
        res.pos.y = target.pos.y
    case .Center_Left, .Center, .Center_Right:
        res.pos.y = target.pos.y + (target.size.y - res.size.y) / 2.0
    case .Bottom_Left, .Bottom_Center, .Bottom_Right:
        res.pos.y = target.pos.y + target.size.y - res.size.y
    }

    return res
}

inset :: proc(rec: Rec, amount: f32) -> Rec {
    return inset_vec(rec, {amount, amount})
}
inset_vec :: proc(rec: Rec, amount: Vec2) -> Rec {
    res := rec
    res.pos += amount
    res.size -= amount * 2.0
    
    return res
}

crop :: proc(rec: Rec, side: Side, amount: f32) -> Rec {
    res := rec
    switch side {
    case .Left:
        res.pos.x += amount
        res.size.x -= amount
    case .Right:
        res.size.x -= amount
    case .Top:
        res.pos.y += amount
        res.size.y -= amount
    case .Bottom:
        res.size.y -= amount
    }
    return res
}

cut :: proc(target: Rec, side: Side, amount: f32) -> (res: Rec, piece: Rec) {
    res = crop(target, side, amount)
    
    piece = target

    switch side {
    case .Left:
        piece.size.x = amount
    case .Right:
        piece.pos.x = target.pos.x + target.size.x - amount
        piece.size.x = amount
    case .Top:
        piece.size.y = amount
    case .Bottom:
        piece.pos.y = target.pos.y + target.size.y - amount
        piece.size.y = amount
    }

    return res, piece
}

write :: proc(dir: Side, rec_size: Vec2, from: Vec2, cursor: ^f32) -> Rec {
    res := Rec{{}, rec_size}
    res.pos = from

    switch dir {
    case .Right:
        res.pos.x += cursor^
        cursor^ += res.size.x

    case .Left:
        cursor^ += res.size.x
        res.pos.x -= cursor^
    case .Bottom:
        res.pos.y += cursor^
        cursor^ += res.size.y
    case .Top:
        cursor^ += res.size.y
        res.pos.y -= cursor^
    }

    return res
}


to_relative_point :: proc(pos: Vec2, parent: Rec) -> Vec2 {
    return {
        (pos.x - parent.pos.x) / parent.size.x,
        (pos.y - parent.pos.y) / parent.size.y,
    }
}
to_absolute_point :: proc(rel_pos: Vec2, parent: Rec) -> Vec2 {
    return {
        parent.pos.x + (rel_pos.x * parent.size.x),
        parent.pos.y + (rel_pos.y * parent.size.y),
    }
}
to_relative_vec :: proc(size: Vec2, parent_size: Vec2) -> Vec2 {
    return {
        size.x / parent_size.x,
        size.y / parent_size.y,
    }
}
to_absolute_vec :: proc(rel_size: Vec2, parent_size: Vec2) -> Vec2 {
    return {
        rel_size.x * parent_size.x,
        rel_size.y * parent_size.y,
    }
}

to_relative_rec :: proc(child: Rec, parent: Rec) -> Rec {
    return {
        pos  = to_relative_point(child.pos, parent),
        size = to_relative_vec(child.size, parent.size),
    }
}

to_absolute_rec :: proc(rel: Rec, parent: Rec) -> Rec {
    return {
        pos  = to_absolute_point(rel.pos, parent),
        size = to_absolute_vec(rel.size, parent.size),
    }
}