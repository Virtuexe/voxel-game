package raylib_ui

//scale
scale_f32 :: proc(item: ^f32, scale: f32) {
    item^ *= scale
}
scale_vec :: proc(item: ^Vec, scale: f32) {
    item^ *= scale
}
scale_rec :: proc(item: ^Rec, scale: f32) {
    item.pos  *= scale
    item.size *= scale
}
//-scale
unscale_f32 :: proc(item: ^f32, scale: f32) { item^ /= scale }
unscale_vec :: proc(item: ^Vec, scale: f32) { item^ /= scale }
unscale_rec :: proc(item: ^Rec, scale: f32) {
    item.pos  /= scale
    item.size /= scale
}
//offset
offset_vec :: proc(item: ^Vec, point: Vec) {
    item^ += point
}
offset_rec :: proc(item: ^Rec, point: Vec) {
    item.pos += point
}
//-offset
unoffset_vec :: proc(item: ^Vec, point: Vec) {
    item^ -= point
}

unoffset_rec :: proc(item: ^Rec, point: Vec) {
    item.pos -= point
}
//size
size_f32 :: proc(item: ^f32, size: Vec) {
    item^ *= vmin(size)
}
size_vec :: proc(item: ^Vec, size: Vec) {
    item^ *= size
}
size_rec :: proc(item: ^Rec, size: Vec) {
    item.pos  *= size
    item.size *= size
}
//-size
normalize_f32 :: proc(item: ^f32, size: Vec) { item^ /= vmin(size) }
normalize_vec :: proc(item: ^Vec, size: Vec) { item^ /= size }
normalize_rec :: proc(item: ^Rec, size: Vec) {
    item.pos  /= size
    item.size /= size
}
//parent
parent_f32 :: proc(item: ^f32, parent: Rec) {
    item^ *= vmin(parent.size)
}
parent_vec :: proc(item: ^Vec, parent: Rec) {
    item^ = parent.pos + (item^ * parent.size)
}
parent_rec :: proc(item: ^Rec, parent: Rec) {
    item.pos  = parent.pos + (item.pos * parent.size)
    item.size *= parent.size
}
//-parent
localize_f32 :: proc(item: ^f32, parent: Rec) {
    item^ /= vmin(parent.size)
}
localize_vec :: proc(item: ^Vec, parent: Rec) {
    item^ = (item^ - parent.pos) / parent.size
}
localize_rec :: proc(item: ^Rec, parent: Rec) {
    item.pos  = (item.pos - parent.pos) / parent.size
    item.size /= parent.size
}