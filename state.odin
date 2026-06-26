package voxel_game

import rl "vendor:raylib"

Player_Movement :: struct {
    forward: Vec3,
    apply_gravity: bool,
    is_flying: bool,
    can_jump: bool,
    move_speed: f32,
    gravity: f32,
    jump_strength: f32,
    is_grounded: bool,
    velocity: Vec3,
    yaw: f32,
    pitch: f32,
}

Player_Input :: struct {
    mouse_sensitivity: f32,
    use_key_input: bool,
    use_mouse_input: bool,
    mouse_lock: bool,
}

Player_Interaction :: struct {
    block_in_hand: Block,
    has_target_block: bool,
    target_block: [3]i32,
    place_block: Vec3,
    place_block_index: [3]i32,
    place_block_face_normal: Vec3,
    place_block_direction_normal: Vec3,
    place_block_direction_normal_2d: Vec2,
    place_block_face: Face,
    place_block_direction: Direction,
}

Player_Collider :: struct {
    collider_size: Vec3,
    collider_offset: Vec3,
    last_position: Vec3,
}

State :: struct {
    cam: rl.Camera3D,
    ui_cam: rl.Camera2D,
    code: Code_State,
    world: World_State,

    using movement: Player_Movement,
    using input: Player_Input,
    using interaction: Player_Interaction,
    using collider: Player_Collider,

    in_menu: bool,
    show_debug: bool,
}

state := State {
    cam = {
        position = {0, 5, 5},
        up       = {0, 1, 0},
        fovy     = 90,
        projection = .PERSPECTIVE,
    },
    ui_cam = {zoom=1},
    
    movement = {
        move_speed = 4.3,
        gravity = 32,
        jump_strength = 8.4,
        yaw = 90,
    },
    
    input = {
        mouse_sensitivity = 0.1,
        use_key_input = true,
        use_mouse_input = true,
    },
    
    interaction = {
        has_target_block = false,
    },
    
    collider = {
        collider_size = Vec3{0.5, 2, 0.5},
    },
}
