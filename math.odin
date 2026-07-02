package voxel_game

import "core:math"
Block_Face :: enum{Top, Bottom, North, South, East, West}
Cardinal :: enum{North, South, East, West}

fix_normal :: proc(vec: Vec3) -> (res: Vec3) {
    biggest_i: int
    biggest: f32
    for n, i in vec {
        if abs(n) > biggest {
            biggest = abs(n)
            biggest_i = i
        }
    }
    for &n, i in res {
        if i == biggest_i {
            if vec[i] < 0 do n = -1
            else do n = 1
            break
        }
    }
    return
}

normal_to_face :: proc(vec: Vec3) -> Block_Face {
    switch vec {
    case {0, 0, 1}: return .South
    case {0, 0, -1}: return .North
    case {1, 0, 0}: return .East
    case {-1, 0, 0}: return .West
    case {0, 1, 0}: return .Top
    case {0, -1, 0}: return .Bottom
    }
    return {}
}

face_to_normal :: proc(side: Block_Face) -> Vec3 {
    switch side {
    case .South: return {0, 0, 1}
    case .North: return {0, 0, -1}
    case .East: return {1, 0, 0}
    case .West: return {-1, 0, 0}
    case .Top: return {0, 1, 0}
    case .Bottom: return {0, -1, 0}
    }
    return {}
}

ignore_normal :: proc(ignore_normal, normal: Vec3) -> Vec2 {
    switch ignore_normal {
    case {0,0,1}:
        return {normal.x,-normal.y}
    case {0,0,-1}:
        return {-normal.x,-normal.y}
    case {0,1,0}:
        return {normal.x,normal.z}
    case {0,-1,0}:
        return {normal.x,-normal.z}
    case {1,0,0}:
        return {-normal.z,-normal.y}
    case {-1,0,0}:
        return {normal.z,-normal.y}
    }
    return {}
}

restore_normal :: proc(ignore_normal: Vec3, local_dir: Vec2) -> Vec3 {
    switch ignore_normal {
    case {0, 0, 1}:
        return {local_dir.x, -local_dir.y, 0}
    case {0, 0, -1}:
        return {-local_dir.x, -local_dir.y, 0}
    case {0, 1, 0}:
        return {local_dir.x, 0, local_dir.y}
    case {0, -1, 0}:
        return {local_dir.x, 0, -local_dir.y}
    case {1, 0, 0}:
        return {0, -local_dir.y, -local_dir.x}
    case {-1, 0, 0}:
        return {0, -local_dir.y, local_dir.x}
    }
    return {}
}

normal_to_direction :: proc(normal: Vec2) -> Cardinal {
    switch normal{
    case {0,-1}: return .North
    case {0,1}: return .South
    case {1,0}: return .East
    case {-1,0}: return .West
    }
    return {}
}

direction_to_normal :: proc(dir: Cardinal) -> Vec2 {
    switch dir{
    case .North: return {0,-1}
    case .South: return {0,1}
    case .East: return {1,0}
    case .West: return {-1,0}
    }
    return {}
}

Raycast_Iterator :: struct {
    t_max: [3]f32,
    t_delta: [3]f32,
    step: [3]i32,
    current_voxel: [3]i32,
    max_distance: f32,
    t: f32,
}

make_raycast_iterator :: proc(ray_pos, ray_dir: Vec3, max_distance: f32) -> Raycast_Iterator {
    it: Raycast_Iterator
    it.max_distance = max_distance
    
    // Shift ray position by 0.5 because voxels are centered at integer coordinates
    // and span from X-0.5 to X+0.5. By shifting, we align the mathematical grid (integers)
    // with our voxel grid boundaries (X.5).
    shifted_pos := Vec3{ray_pos.x + 0.5, ray_pos.y + 0.5, ray_pos.z + 0.5}

    it.current_voxel = {
        i32(math.floor(shifted_pos.x)),
        i32(math.floor(shifted_pos.y)),
        i32(math.floor(shifted_pos.z)),
    }

    for i in 0..<3 {
        if ray_dir[i] > 0 {
            it.step[i] = 1
            it.t_delta[i] = 1.0 / ray_dir[i]
            it.t_max[i] = (math.floor(shifted_pos[i]) + 1.0 - shifted_pos[i]) * it.t_delta[i]
        } else if ray_dir[i] < 0 {
            it.step[i] = -1
            it.t_delta[i] = 1.0 / -ray_dir[i]
            it.t_max[i] = (shifted_pos[i] - math.floor(shifted_pos[i])) * it.t_delta[i]
        } else {
            it.step[i] = 0
            it.t_delta[i] = math.INF_F32
            it.t_max[i] = math.INF_F32
        }
    }
    return it
}

raycast_iterator_next :: proc(it: ^Raycast_Iterator) -> (voxel: [3]i32, ok: bool) {
    if it.t > it.max_distance do return {}, false
    
    voxel = it.current_voxel
    ok = true
    
    min_t := it.t_max[0]
    min_i := 0
    if it.t_max[1] < min_t {
        min_t = it.t_max[1]
        min_i = 1
    }
    if it.t_max[2] < min_t {
        min_t = it.t_max[2]
        min_i = 2
    }
    
    it.t = min_t
    it.current_voxel[min_i] += it.step[min_i]
    it.t_max[min_i] += it.t_delta[min_i]
    
    return
}
