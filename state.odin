package voxel_game

import rl "vendor:raylib"

Player_Movement :: struct {
    forward: Vec3,
    apply_gravity: bool,
    is_flying: bool,
    can_jump: bool,
    move_speed: f32,
    fly_sprint_multiplier: f32,
    gravity: f32,
    jump_strength: f32,
    is_grounded: bool,
    velocity: Vec3,
    yaw: f32,
    pitch: f32,
    is_shifting: bool,
    eye_height: f32,
}

Player_Input :: struct {
    mouse_sensitivity: f32,
    use_key_input: bool,
    use_mouse_input: bool,
    mouse_lock: bool,
}

Player_Interaction :: struct {
    look_target: Vec3I,
    looking_at_block: bool,
    hit_face: Block_Face,
    hit_normal: Vec3,
    place_target: Vec3I,
    place_pos: Vec3,
    place_dir: Cardinal,
    place_dir_normal: Vec3,
    place_dir_normal_2d: Vec2,

    place_yaw_dir: Cardinal,
    place_pitch_face: Block_Face,
    place_half: Block_Face,
    
    held_item: Maybe(Item),
    hotbar: [9]Maybe(Item),
    hotbar_index: int,
    
    cursor: Maybe(Item),
    player_storage: [STORAGE_SLOTS]Maybe(Item),
    target_storage: [STORAGE_SLOTS]Maybe(Item),
}

Player_Collider :: struct {
    collider_size: Vec3,
    position: Vec3,
    last_position: Vec3,
}

State :: struct {
    cam: rl.Camera3D,
    ui_cam: rl.Camera2D,
    code: Code_State,
    world: World_State,
    
    render_distance: i32,

    using movement: Player_Movement,
    using input: Player_Input,
    using interaction: Player_Interaction,
    using collider: Player_Collider,

    in_menu: bool,
    show_inventory: bool,
    show_debug: bool,
}

state := State {
    cam = {
        up       = {0, 1, 0},
        fovy     = 90,
        projection = .PERSPECTIVE,
    },
    ui_cam = {zoom=1},
    render_distance = 4,
    movement = {
        move_speed = 4.3,
        fly_sprint_multiplier = 3.0,
        gravity = 32,
        jump_strength = 8.4,
        yaw = 90,
        eye_height = 1.8,
    },
    input = {
        mouse_sensitivity = 0.1,
        use_key_input = true,
        use_mouse_input = true,
    },
    interaction = {
        looking_at_block = false,
    },
    collider = {
        position = {0, 5, 5},
        collider_size = Vec3{0.5, 2, 0.5},
    },
}
