package voxel_game

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
