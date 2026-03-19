package voxel_game
import ui "../raylib-ui"

flatten :: proc(pos: [3]i32) -> int {
    return int(pos.x + (pos.y * CHUNK.y) + (pos.z * CHUNK.y * CHUNK.z))
}
unflatten :: proc(index: int) -> (pos: [3]i32) {
    index := i32(index)
    pos.x = index % CHUNK.y
    pos.y = (index / CHUNK.y) % CHUNK.z
    pos.z = index / (CHUNK.y * CHUNK.z)
    return
}

to_vec3 :: proc(a: [3]i32) -> Vec3 {
    return {f32(a.x), f32(a.y), f32(a.z)}
}
from_vec3 :: proc(a: Vec3) -> [3]i32 {
    return {i32(a.x), i32(a.y), i32(a.z)}
}
to_vec2 :: proc(a: [2]i32) -> Vec2 {
    return {f32(a.x), f32(a.y)}
}
from_vec2 :: proc(a: Vec2) -> [2]i32 {
    return {i32(a.x), i32(a.y)}
}