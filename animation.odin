package voxel_game

import "core:math"
import rl "vendor:raylib"

Animator :: struct {
    transforms: [MAX_TEXTURE_GROUPS]rl.Matrix,
}

animator_init :: proc() -> Animator {
    a: Animator
    for i in 0..<MAX_TEXTURE_GROUPS {
        a.transforms[i] = rl.Matrix(1)
    }
    return a
}

animator_translate :: proc(a: ^Animator, group: int, offset: Vec3) {
    a.transforms[group] = rl.MatrixTranslate(offset.x, offset.y, offset.z) * a.transforms[group]
}

animator_scale :: proc(a: ^Animator, group: int, scale: Vec3) {
    a.transforms[group] = rl.MatrixScale(scale.x, scale.y, scale.z) * a.transforms[group]
}

animator_rotate :: proc(a: ^Animator, group: int, axis: Vec3, angle: f32) {
    a.transforms[group] = rl.MatrixRotate(axis, angle) * a.transforms[group]
}

Block_Animate_Action :: enum {
    None,
    Piston_Animate,
}
Block_Animate_Proc :: proc(block: Block, a: ^Animator)

block_animate_procs := [Block_Animate_Action]Block_Animate_Proc {
    .None = nil,
    .Piston_Animate = piston_animate,
}

piston_animate :: proc(block: Block, a: ^Animator) {
    if block.data.piston.activation_time == 0 do return
    
    t := f32(rl.GetTime() - block.data.piston.activation_time)
    
    ext: f32 = 0.0
    head_rot: f32 = 0.0
    
    if t < 0.3 {
        // Push out over 0.3s
        ext = (t / 0.3) * 1.0
    } else if t < 0.4 {
        // Wait 0.1s
        ext = 1.0
    } else if t < 0.7 {
        // Pull back over 0.3s
        ext = 1.0 - ((t - 0.4) / 0.3) * 1.0
    }
    
    if ext > 0 {
        animator_translate(a, 2, {0, ext, 0}) // head
        scale := (0.75 + ext) / 0.75
        animator_scale(a, 1, {1, scale, 1}) // arm
    }
    
    if head_rot > 0 {
        // Rotate head around its center point {0.5, 0.875, 0.5}
        animator_translate(a, 2, {-0.5, -0.875, -0.5})
        animator_rotate(a, 2, {0, 1, 0}, head_rot)
        animator_translate(a, 2, {0.5, 0.875, 0.5})
    }
}
