package voxel_game

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

get_chunk_pos :: proc(pos: [3]i32) -> [3]i32 {
    return {
        pos.x < 0 ? (pos.x + 1) / CHUNK.x - 1 : pos.x / CHUNK.x,
        pos.y < 0 ? (pos.y + 1) / CHUNK.y - 1 : pos.y / CHUNK.y,
        pos.z < 0 ? (pos.z + 1) / CHUNK.z - 1 : pos.z / CHUNK.z,
    }
}
get_local_pos :: proc(pos: [3]i32) -> [3]i32 {
    return {
        pos.x %% CHUNK.x,
        pos.y %% CHUNK.y,
        pos.z %% CHUNK.z,
    }
}
