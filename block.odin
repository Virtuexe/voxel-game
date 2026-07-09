package voxel_game
import rl "vendor:raylib"
import "core:fmt"



redstone_render_texture: [(1<<len(Cardinal))*2]rl.RenderTexture2D

Block_Type :: enum {
    Air, Dirt, Stone, Cobblestone, Glass, Planks,
    Redstone, Slab, Stairs, Piston, Button, Torch,
}

Block_Action :: enum {
    None,
    Activate_Wired_Blocks,
    Deactivate_Wired_Blocks,
    Piston_Activate,
    Button_Activate,
    Button_Deactivate,
    Torch_Turn_On,
    Torch_Turn_Off,
}
Block_Action_Proc :: proc(pos: [3]i32)

block_actions := [Block_Action]Block_Action_Proc {
    .None = nil,
    .Activate_Wired_Blocks = activate_wired_blocks,
    .Deactivate_Wired_Blocks = deactivate_wired_blocks,
    .Piston_Activate = piston_activate,
    .Button_Activate = button_activate,
    .Button_Deactivate = button_deactivate,
    .Torch_Turn_On = torch_turn_on,
    .Torch_Turn_Off = torch_turn_off,
}



Block_Info :: struct {
    flags: bit_set[Block_Flag],
    item: Maybe(Item_Type),
    model: Block_Model,
    texture: Block_Texture,
    on_right_click: Block_Action,
    on_activate: Block_Action,
    on_deactivate: Block_Action,
    animate: Block_Animate_Action,
}
Block_Flag :: enum {
    TEXTURE_TRANSPARENT,
    STATEFUL,
    NO_COLLISION,
    HAS_CARDINAL,
    HAS_BLOCK_FACE,
    WIRE_INPUT,
    WIRE_OUTPUT,
}

block_infos := [Block_Type]Block_Info {
    .Air = {
        flags = {},
    },
    .Dirt = {
        flags = {},
        item = .Dirt,
        model = .Cube,
    },
    .Stone = {
        flags = {},
        item = .Stone,
        model = .Cube,
    },
    .Cobblestone = {
        flags = {},
        item = .Cobblestone,
        model = .Cube,
    },
    .Glass = {
        flags = {.TEXTURE_TRANSPARENT, .WIRE_INPUT, .WIRE_OUTPUT},
        item = .Glass,
        model = .Cube,
        on_activate = .Activate_Wired_Blocks
    },
    .Planks = {
        flags = {},
        item = .Planks,
        model = .Cube,
    },
    .Redstone = {
        flags = {.TEXTURE_TRANSPARENT, .STATEFUL, .NO_COLLISION},
        item = .Redstone,
        model = .Decal,
    },
    .Slab = {
        flags = {.HAS_BLOCK_FACE},
        item = .Slab,
        model = .Slab,
    },
    .Stairs = {
        flags = {.HAS_BLOCK_FACE, .HAS_CARDINAL},
        item = .Stairs,
        model = .Stairs,
    },
    .Piston = {
        flags = {.HAS_BLOCK_FACE, .WIRE_OUTPUT},
        item = .Piston,
        model = .Piston,
        on_activate = .Piston_Activate,
        animate = .Piston_Animate
    },
    .Button = {
        flags = {.HAS_BLOCK_FACE, .NO_COLLISION, .WIRE_INPUT, .STATEFUL},
        item = .Button,
        model = .Button,
        on_right_click = .Button_Activate
    },
    .Torch = {
        flags = {.NO_COLLISION, .STATEFUL, .TEXTURE_TRANSPARENT, .WIRE_INPUT, .WIRE_OUTPUT},
        item = .Torch,
        model = .Torch,
        on_activate = .Torch_Turn_Off,
        on_deactivate = .Torch_Turn_On,
    }
}



block_init :: proc() {
    init_block_textures()
    init_models()
}
//TODO unload textures

//runs activate function of all block
activate_wired_blocks :: proc(pos: [3]i32) {
    block := world_get_block(pos)
    if !block.data.has_wires do return
    
    if wires, ok := state.world.wires[pos]; ok {
        for wire in wires {
            target_pos := wire.to
            target_block := world_get_block(target_pos)
            info := block_infos[target_block.type]
            if info.on_activate != .None {
                block_actions[info.on_activate](target_pos)
            }
        }
    }
}

deactivate_wired_blocks :: proc(pos: [3]i32) {
    block := world_get_block(pos)
    if !block.data.has_wires do return
    
    if wires, ok := state.world.wires[pos]; ok {
        for wire in wires {
            target_pos := wire.to
            target_block := world_get_block(target_pos)
            info := block_infos[target_block.type]
            if info.on_deactivate != .None {
                block_actions[info.on_deactivate](target_pos)
            }
        }
    }
}

button_activate :: proc(pos: [3]i32) {
    block := world_get_block(pos)
    if block.data.button.on do return
    block.data.button.on = true
    world_set_block(pos, block)
    activate_wired_blocks(pos)
    world_schedule_action(.Button_Deactivate, pos, 2.0)
}

button_deactivate :: proc(pos: [3]i32) {
    block := world_get_block(pos)
    if !block.data.button.on do return
    block.data.button.on = false
    world_set_block(pos, block)
    deactivate_wired_blocks(pos)
}

torch_turn_on :: proc(pos: [3]i32) {
    block := world_get_block(pos)
    if block.data.torch.on do return
    block.data.torch.on = true
    world_set_block(pos, block)
    activate_wired_blocks(pos)
}

torch_turn_off :: proc(pos: [3]i32) {
    block := world_get_block(pos)
    if !block.data.torch.on do return
    block.data.torch.on = false
    world_set_block(pos, block)
    deactivate_wired_blocks(pos)
}
//will push block that is facing to, if Air will instead pull block to piston if also Air do nothing
piston_activate :: proc(pos: [3]i32) {
    piston_block := world_get_block(pos)
    if piston_block.type != .Piston do return
    
    // Prevent spamming piston while it is busy animating (pushing out, spinning, or pulling back)
    if piston_block.data.piston.activation_time > 0 && rl.GetTime() - piston_block.data.piston.activation_time < 0.7 {
        return
    }

    normal := face_to_normal(piston_block.data.facing)
    dir := [3]i32{i32(normal.x), i32(normal.y), i32(normal.z)}
    
    target_pos := pos + dir
    target_block := world_get_block(target_pos)
    
    if target_block.type != .Air {
        next_pos := target_pos + dir
        next_block := world_get_block(next_pos)
        if next_block.type == .Air {
            world_schedule_move(target_pos, next_pos, 0.0, 0.3)
        }
    } else {
        next_pos := target_pos + dir
        next_block := world_get_block(next_pos)
        if next_block.type != .Air {
            world_schedule_move(next_pos, target_pos, 0.4, 0.3)
        }
    }
    
    piston_block.data.piston.activation_time = rl.GetTime()
    world_set_block(pos, piston_block)
}





//GAMEPLAY
Block :: struct {
    type: Block_Type,
    data: Block_Data,
}
Block_Data :: struct {
    direction: Cardinal,
    facing: Block_Face,
    has_wires: bool,
    using uniqe: Block_Data_Uniqe,
}
Block_Data_Uniqe :: struct #raw_union {
    redstone: Redstone,
    piston: Piston_Data,
    torch: Torch_Data,
    button: Button_Data,
}
Button_Data :: struct {
    on: bool,
}
Torch_Data :: struct {
    on: bool,
}
Piston_Data :: struct {
    activation_time: f64,
}
Redstone :: struct {
    on: bool,
    rotation: Block_Face,
    connections: [Cardinal]bool,
}
Wire :: struct {
    to: [3]i32
}

are_blocks_equal :: proc(a, b: Block) -> bool {
    if a.type != b.type do return false
    if a.data.direction != b.data.direction do return false
    if a.data.facing != b.data.facing do return false
    if a.data.has_wires != b.data.has_wires do return false
    
    #partial switch a.type {
    case .Redstone:
        return a.data.redstone == b.data.redstone
    case .Piston:
        return a.data.piston.activation_time == b.data.piston.activation_time
    case .Torch:
        return a.data.torch == b.data.torch
    case .Button:
        return a.data.button == b.data.button
    }
    return true
}

//rework, should be in item.odin
place_base_block :: proc(block: Block) {
    block := block
    info := block_infos[block.type]
    has_cardinal := .HAS_CARDINAL in info.flags
    has_block_face := .HAS_BLOCK_FACE in info.flags

    if has_cardinal && has_block_face {
        block.data.direction = state.place_yaw_dir
        block.data.facing = state.place_half
    } else if has_cardinal {
        block.data.direction = state.place_yaw_dir
    } else if has_block_face {
        block.data.facing = state.place_pitch_face
    }
    
    if block.type == .Torch {
        block.data.torch.on = true
    }
    
    world_set_block(state.place_target, block)
}
place_redstone :: proc() {
    pos1 := state.place_pos
    pos2 := pos1 + state.place_dir_normal
    pos1_i := state.place_target
    pos2_i := from_vec3(pos2)
    dir1 := state.place_dir
    dir2 := normal_to_direction(-state.place_dir_normal_2d)

    redstone := Block{.Redstone, {redstone={true, state.hit_face, {}}}}
    redstone.data.redstone.connections[dir1] = true
    world_set_block(pos1_i, redstone)

    redstone2 := Block{.Redstone, {redstone={true, state.hit_face, {}}}}
    redstone2.data.redstone.connections[dir2] = true
    world_set_block(pos2_i, redstone2)
}