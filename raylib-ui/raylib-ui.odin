package raylib_ui

import "core:strings"
import rl "vendor:raylib"

Vec :: rl.Vector2
Color :: rl.Color
LIGHTGRAY, GRAY, DARKGRAY, YELLOW, GOLD :: rl.LIGHTGRAY, rl.GRAY, rl.DARKGRAY, rl.YELLOW, rl.GOLD
ORANGE, PINK, RED, MAROON, GREEN, LIME :: rl.ORANGE, rl.PINK, rl.RED, rl.MAROON, rl.GREEN, rl.LIME
DARKGREEN, SKYBLUE, BLUE, DARKBLUE, PURPLE, VIOLET :: rl.DARKGREEN, rl.SKYBLUE, rl.BLUE, rl.DARKBLUE, rl.PURPLE, rl.VIOLET
DARKPURPLE, BEIGE, BROWN, DARKBROWN, WHITE, BLACK :: rl.DARKPURPLE, rl.BEIGE, rl.BROWN, rl.DARKBROWN, rl.WHITE, rl.BLACK
BLANK, MAGENTA, RAYWHITE :: rl.BLANK, rl.MAGENTA, rl.RAYWHITE
Font :: rl.Font

Rec :: struct {
    pos, size: Vec, 
}
Text_Style :: struct {
    font_size: f32,
    font: Font,
}
Texture :: rl.Texture2D

Anchor :: enum {
    Top_Left, Top_Center, Top_Right,
    Center_Left, Center, Center_Right,
    Bottom_Left, Bottom_Center, Bottom_Right
}

Side :: enum {
    Left, Right, Top, Bottom
}

Camera :: rl.Camera2D
create_camera :: proc() -> Camera { return {zoom = 1} }
camera_set_viewport :: proc(camera: ^Camera) {
    min_dim := vmin(get_screen_size())
    if min_dim > 0 {
        camera.zoom = min_dim
    }
}
screen_to_camera :: proc(pos: Vec, cam: Camera) -> Vec {
    return rl.GetScreenToWorld2D(pos, cam)
}
camera_to_screen :: proc(pos: Vec, cam: Camera) -> Vec {
    return rl.GetWorldToScreen2D(pos, cam)
}
//get view size based on zoom
get_view_size :: proc(camera: Camera) -> Vec {
    screen_size := get_screen_size()
    if camera.zoom <= 0 do return screen_size 
    return screen_size / camera.zoom
}


//Before any draw call begin_draw needs to be called.
//Raylib BeginDraw needs to be called before this.
begin_draw :: proc(camera: ^Camera) {
    rl.BeginMode2D(camera^)
    // pos := window.pos; size := window.size
    // x := pos.x; y := pos.y; w := size.x; h := size.y
    // rl.BeginScissorMode(i32(x), i32(y), i32(w), i32(h))
}
//After draw calls end_draw needs to be called.
end_draw :: proc() {
    // rl.EndScissorMode()
    rl.EndMode2D()
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
get_dir :: proc(side: Side) -> Vec {
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
set_opposite_side :: proc(side: ^Side) {side^ = get_opposite_side(side^)}
get_anchor_dir :: proc(anchor: Anchor) -> Vec {
    switch anchor {
    case .Top_Left:      return {-1, -1}
    case .Top_Center:    return { 0, -1}
    case .Top_Right:     return { 1, -1}
    
    case .Center_Left:   return {-1,  0}
    case .Center:        return { 0,  0}
    case .Center_Right:  return { 1,  0}
    
    case .Bottom_Left:   return {-1,  1}
    case .Bottom_Center: return { 0,  1}
    case .Bottom_Right:  return { 1,  1}
    }
    return {0, 0}
}
get_anchor_uv :: proc(anchor: Anchor) -> Vec {
    switch anchor {
    case .Top_Left:      return {0.0, 0.0}
    case .Top_Center:    return {0.5, 0.0}
    case .Top_Right:     return {1.0, 0.0}
    
    case .Center_Left:   return {0.0, 0.5}
    case .Center:        return {0.5, 0.5}
    case .Center_Right:  return {1.0, 0.5}
    
    case .Bottom_Left:   return {0.0, 1.0}
    case .Bottom_Center: return {0.5, 1.0}
    case .Bottom_Right:  return {1.0, 1.0}
    }
    return {0.5, 0.5}
}
get_opposite_anchor :: proc(anchor: Anchor) -> Anchor {
    switch anchor {
    case .Top_Left:      return .Bottom_Right
    case .Top_Center:    return .Bottom_Center
    case .Top_Right:     return .Bottom_Left
    
    case .Center_Left:   return .Center_Right
    case .Center:        return .Center
    case .Center_Right:  return .Center_Left
    
    case .Bottom_Left:   return .Top_Right
    case .Bottom_Center: return .Top_Center
    case .Bottom_Right:  return .Top_Left
    }
    return .Center
}
set_opposite_anchor :: proc(anchor: ^Anchor) {anchor^ = get_opposite_anchor(anchor^)}

vmin :: proc(v: Vec) -> f32 {
    return min(v.x, v.y)
}
vmax :: proc(v: Vec) -> f32 {
    return max(v.x, v.y)
}

get_screen_size :: proc() -> Vec {
    return {f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}
}

get_mouse_pos :: rl.GetMousePosition
get_mouse_pos_local :: proc(cam: Camera) -> Vec {
    return screen_to_camera(get_mouse_pos(), cam)
}
get_mouse_delta :: rl.GetMouseDelta
get_mouse_scroll :: rl.GetMouseWheelMove
is_mouse_button_down :: rl.IsMouseButtonDown
is_mouse_button_pressed :: rl.IsMouseButtonPressed
is_mouse_button_released :: rl.IsMouseButtonReleased

fit :: proc(this_size, into_size: Vec) -> (scale: f32) {
    scale_vec := into_size / this_size
    scale = vmin(scale_vec)
    return
}

contains_point :: proc(rec: Rec, point: Vec) -> bool {
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
draw_rec_lines :: proc(rec: Rec, thick: f32, color: Color) {
    rl.DrawRectangleLinesEx({rec.pos.x, rec.pos.y, rec.size.x, rec.size.y}, thick, color)
}
draw_line :: proc(start_pos, end_pos: Vec, thick: f32, color: Color) {
    rl.DrawLineEx(start_pos, end_pos, thick, color)
}
draw_rec_texture :: proc(rec: Rec, texture: Texture, color := rl.WHITE) {
    rl.DrawTexturePro(
        texture, 
        {0, 0, f32(texture.width), f32(texture.height)},
        {rec.pos.x, rec.pos.y, rec.size.x, rec.size.y},
        {}, {},
        color
    )
}

make_text_style :: proc(font_size: f32, font: Font = {}) -> Text_Style {
    font := font
    if font == {} do font = rl.GetFontDefault()
    return {font_size, font}
}
draw_text :: proc(text: string, style: Text_Style, pos: Vec, color: rl.Color) {
    text := strings.clone_to_cstring(text, context.temp_allocator)
    rl.DrawTextEx(style.font, text, pos, style.font_size, style.font_size/10, color)
}
measure_text_size :: proc(text: string, style: Text_Style) -> Vec {
    value := strings.clone_to_cstring(text, context.temp_allocator)
    return rl.MeasureTextEx(style.font, value, style.font_size, style.font_size/10)
}

get_anchor_point :: proc(rec: Rec, anchor: Anchor) -> Vec {
    res := rec.pos

    #partial switch anchor {
    case .Top_Center, .Center, .Bottom_Center:
        res.x += rec.size.x / 2.0
    case .Top_Right, .Center_Right, .Bottom_Right:
        res.x += rec.size.x
    }

    #partial switch anchor {
    case .Center_Left, .Center, .Center_Right:
        res.y += rec.size.y / 2.0
    case .Bottom_Left, .Bottom_Center, .Bottom_Right:
        res.y += rec.size.y
    }

    return res
}
get_centered_pos :: proc(pos, size: Vec) -> Vec {
    return pos - size/2
}
get_aligned_pos :: proc(size: Vec, target: Rec, anchor: Anchor) -> Vec {
    target_anchor := get_anchor_point(target, anchor)
    self_anchor   := get_anchor_point({{}, size}, anchor)
    
    return target_anchor - self_anchor
}
get_aligned_at_pos :: proc(size: Vec, align_at: Anchor, target: Rec, anchor: Anchor) -> Vec {
    target_anchor := get_anchor_point(target, anchor)
    self_anchor   := get_anchor_point({{}, size}, align_at)
    
    return target_anchor - self_anchor
}
move :: proc(item: ^Rec, vector: Vec) { item.pos += vector }
center :: proc(item: ^Rec, pos: Vec) {
    item.pos = get_centered_pos(pos, item.size)
}
align :: proc(item: ^Rec, target: Rec, anchor: Anchor) {
    item.pos = get_aligned_pos(item.size, target, anchor)
}
align_at :: proc(item: ^Rec, item_anchor: Anchor, target: Rec, anchor: Anchor) {
    item.pos = get_aligned_at_pos(item.size, item_anchor, target, anchor)
}
resize_anchored :: proc(item: ^Rec, anchor: Anchor, amount: Vec) {
    item.size += amount

    #partial switch anchor {
    case .Top_Center, .Center, .Bottom_Center:
        item.pos.x -= amount.x / 2.0
    case .Top_Right, .Center_Right, .Bottom_Right:
        item.pos.x -= amount.x
    }

    #partial switch anchor {
    case .Center_Left, .Center, .Center_Right:
        item.pos.y -= amount.y / 2.0
    case .Bottom_Left, .Bottom_Center, .Bottom_Right:
        item.pos.y -= amount.y
    }
}

crop :: proc(item: ^Rec, side: Side, amount: f32) {
    switch side {
    case .Left:
        item.pos.x += amount
        item.size.x -= amount
    case .Right:
        item.size.x -= amount
    case .Top:
        item.pos.y += amount
        item.size.y -= amount
    case .Bottom:
        item.size.y -= amount
    }
}

cut :: proc(target: ^Rec, side: Side, amount: f32) -> (piece: Rec) {
    crop(target, side, amount)
    
    piece = target^

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

    return piece
}

list :: proc(item: ^Rec, pos: Vec, element_size: Vec, index: int, anchor: Anchor) {
    item.size = element_size
    item.pos = pos
    
    #partial switch anchor {
    case .Top_Left, .Center_Left, .Bottom_Left:
        item.pos.x += element_size.x * f32(index)
    case .Top_Right, .Center_Right, .Bottom_Right:
        item.pos.x -= element_size.x * f32(index)
    case .Top_Center, .Center, .Bottom_Center:
        item.pos.y += element_size.y * f32(index)
    }
}

grid :: proc(item: ^Rec, pos: Vec, element_size: Vec, x, y: int, anchor: Anchor) {
    item.size = element_size
    item.pos = pos
    
    // Horizontal layout
    #partial switch anchor {
    case .Top_Left, .Center_Left, .Bottom_Left, .Top_Center, .Center, .Bottom_Center:
        item.pos.x += element_size.x * f32(x)
    case .Top_Right, .Center_Right, .Bottom_Right:
        item.pos.x -= element_size.x * f32(x)
    }

    // Vertical layout
    #partial switch anchor {
    case .Top_Left, .Top_Center, .Top_Right, .Center_Left, .Center, .Center_Right:
        item.pos.y += element_size.y * f32(y)
    case .Bottom_Left, .Bottom_Center, .Bottom_Right:
        item.pos.y -= element_size.y * f32(y)
    }
}