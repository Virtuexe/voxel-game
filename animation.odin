package voxel_game

import "core:math"
import rl "vendor:raylib"

Animation_Type :: enum {
    Piston_Push,
    Piston_Pull,
    Move, Button,
}

Animation_Info :: struct {
    proc_: proc(Animation_Data, ^Animator),
    end: f32,
}
animation_infos := [Animation_Type]Animation_Info{
    .Piston_Push = {
        proc_ = animate_piston_push,
        end = 1,
    },
    .Piston_Pull = {
        proc_ = animate_piston_pull,
        end = 1,
    },
    .Move = {
        proc_ = animate_move,
        end = 1,
    },
    .Button = {
        proc_ = animate_button,
        end = 0.5,
    }

}

Animation_Data :: struct {
    type: Animation_Type,
    pos: Vec3I,
    progress: f32,
    from: Vec3I, //used by block .Move
}

Animator :: struct {
    local_transforms: [MAX_TEXTURE_GROUPS]rl.Matrix,
    global_transforms: [MAX_TEXTURE_GROUPS]rl.Matrix,
}

Keyframe :: struct {
    duration: f32,
    target: f32,
}

animate_piston_push :: proc(data: Animation_Data, a: ^Animator) {
    info := animation_infos[.Piston_Push]
    progress := data.progress / info.end
    if progress > 1 do progress = 1
    
    animator_translate(a, 2, {0, progress, 0}) // head
    scale := (0.75 + progress) / 0.75
    animator_scale(a, 1, {1, scale, 1}) // arm
}

animate_piston_pull :: proc(data: Animation_Data, a: ^Animator) {
    info := animation_infos[.Piston_Pull]
    progress := 1.0 - (data.progress / info.end)
    if progress < 0 do progress = 0
    
    animator_translate(a, 2, {0, progress, 0}) // head
    scale := (0.75 + progress) / 0.75
    animator_scale(a, 1, {1, scale, 1}) // arm
}

animate_move :: proc(data: Animation_Data, a: ^Animator) {
    info := animation_infos[.Move]
    progress := data.progress / info.end
    if progress > 1 do progress = 1
    
    offset := [3]f32{
        f32(data.from.x - data.pos.x),
        f32(data.from.y - data.pos.y),
        f32(data.from.z - data.pos.z),
    } * (1.0 - progress)
    
    for i in 0..<MAX_TEXTURE_GROUPS {
        animator_translate_global(a, i, offset)
    }
}

animate_button :: proc(data: Animation_Data, a: ^Animator) {
    info := animation_infos[.Button]
    progress := data.progress / info.end
    if progress > 1 do progress = 1
    
    amount: f32
    if progress < 0.2 {
        amount = progress / 0.2
    } else if progress > 0.8 {
        amount = (1.0 - progress) / 0.2
    } else {
        amount = 1.0
    }
    
    offset := [3]f32{0, 0, amount * (0.5 / 16.0)}
    
    for i in 0..<MAX_TEXTURE_GROUPS {
        animator_translate(a, i, offset)
    }
}

animate_sequence :: proc(t: f32, initial_val: f32, seq: []Keyframe) -> f32 {
    current_time: f32 = 0.0
    current_val: f32 = initial_val
    
    for kf in seq {
        if t <= current_time + kf.duration {
            if kf.duration <= 0 do return kf.target
            progress := (t - current_time) / kf.duration
            return current_val + (kf.target - current_val) * progress
        }
        current_time += kf.duration
        current_val = kf.target
    }
    
    return current_val
}

animator_init :: proc() -> Animator {
    a: Animator
    for i in 0..<MAX_TEXTURE_GROUPS {
        a.local_transforms[i] = rl.Matrix(1)
        a.global_transforms[i] = rl.Matrix(1)
    }
    return a
}

animator_translate :: proc(a: ^Animator, group: int, offset: Vec3) {
    a.local_transforms[group] = rl.MatrixTranslate(offset.x, offset.y, offset.z) * a.local_transforms[group]
}

animator_translate_global :: proc(a: ^Animator, group: int, offset: Vec3) {
    a.global_transforms[group] = rl.MatrixTranslate(offset.x, offset.y, offset.z) * a.global_transforms[group]
}

animator_scale :: proc(a: ^Animator, group: int, scale: Vec3) {
    a.local_transforms[group] = rl.MatrixScale(scale.x, scale.y, scale.z) * a.local_transforms[group]
}

animator_scale_global :: proc(a: ^Animator, group: int, scale: Vec3) {
    a.global_transforms[group] = rl.MatrixScale(scale.x, scale.y, scale.z) * a.global_transforms[group]
}

animator_rotate :: proc(a: ^Animator, group: int, axis: Vec3, angle: f32) {
    a.local_transforms[group] = rl.MatrixRotate(axis, angle) * a.local_transforms[group]
}

animator_rotate_global :: proc(a: ^Animator, group: int, axis: Vec3, angle: f32) {
    a.global_transforms[group] = rl.MatrixRotate(axis, angle) * a.global_transforms[group]
}
