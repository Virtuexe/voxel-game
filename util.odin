package voxel_game
import "core:math"

flatten :: proc(pos: Vec3I) -> int {
    return int(pos.x + (pos.y * CHUNK.y) + (pos.z * CHUNK.y * CHUNK.z))
}
unflatten :: proc(index: int) -> (pos: Vec3I) {
    index := i32(index)
    pos.x = index % CHUNK.y
    pos.y = (index / CHUNK.y) % CHUNK.z
    pos.z = index / (CHUNK.y * CHUNK.z)
    return
}

to_vec3 :: proc(a: Vec3I) -> Vec3 {
    return {f32(a.x), f32(a.y), f32(a.z)}
}
to_vec3i :: proc(a: Vec3) -> Vec3I {
    return Vec3I{i32(math.floor(a.x)), i32(math.floor(a.y)), i32(math.floor(a.z))}
}
to_vec2 :: proc(a: [2]i32) -> Vec2 {
    return {f32(a.x), f32(a.y)}
}
from_vec2 :: proc(a: Vec2) -> [2]i32 {
    return {i32(a.x), i32(a.y)}
}

get_chunk_pos :: proc(pos: Vec3I) -> Vec3I {
    return {
        pos.x < 0 ? (pos.x + 1) / CHUNK.x - 1 : pos.x / CHUNK.x,
        pos.y < 0 ? (pos.y + 1) / CHUNK.y - 1 : pos.y / CHUNK.y,
        pos.z < 0 ? (pos.z + 1) / CHUNK.z - 1 : pos.z / CHUNK.z,
    }
}
get_local_pos :: proc(pos: Vec3I) -> Vec3I {
    return {
        pos.x %% CHUNK.x,
        pos.y %% CHUNK.y,
        pos.z %% CHUNK.z,
    }
}

get_global_pos :: proc(c_pos, l_pos: Vec3I) -> Vec3I {
    return {
        c_pos.x * CHUNK.x + l_pos.x,
        c_pos.y * CHUNK.y + l_pos.y,
        c_pos.z * CHUNK.z + l_pos.z,
    }
}

