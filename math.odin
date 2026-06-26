package voxel_game

Face :: enum{Front, Back, Right, Left, Up, Down}
Direction :: enum{Up, Down, Right, Left}

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

normal_to_face :: proc(vec: Vec3) -> Face {
    switch vec {
    case {0, 0, 1}: return .Front
    case {0, 0, -1}: return .Back
    case {1, 0, 0}: return .Right
    case {-1, 0, 0}: return .Left
    case {0, 1, 0}: return .Up
    case {0, -1, 0}: return .Down
    }
    return {}
}

face_to_normal :: proc(side: Face) -> Vec3 {
    switch side {
    case .Front: return {0, 0, 1}
    case .Back: return {0, 0, -1}
    case .Right: return {1, 0, 0}
    case .Left: return {-1, 0, 0}
    case .Up: return {0, 1, 0}
    case .Down: return {0, -1, 0}
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

normal_to_direction :: proc(normal: Vec2) -> Direction {
    switch normal{
    case {0,-1}: return .Up
    case {0,1}: return .Down
    case {1,0}: return .Right
    case {-1,0}: return .Left
    }
    return {}
}

direction_to_normal :: proc(dir: Direction) -> Vec2 {
    switch dir{
    case .Up: return {0,-1}
    case .Down: return {0,1}
    case .Right: return {1,0}
    case .Left: return {-1,0}
    }
    return {}
}
