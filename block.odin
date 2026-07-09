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
    Piston_Deactivate,
    Button_Activate,
    Button_Deactivate,
    Piston_Deactivate_Off,
    Torch_Turn_On,
    Torch_Turn_Off,
}
Action_Data :: struct {
    pushed_block: bool,
}

Block_Action_Proc :: proc(pos: Vec3I, data: Action_Data)

block_actions := [Block_Action]Block_Action_Proc {
    .None = nil,
    .Activate_Wired_Blocks = activate_wired_blocks,
    .Deactivate_Wired_Blocks = deactivate_wired_blocks,
    .Piston_Activate = piston_activate,
    .Piston_Deactivate = piston_deactivate,
    .Piston_Deactivate_Off = piston_deactivate_off,
    .Button_Activate = button_activate,
    .Button_Deactivate = button_deactivate,
    .Torch_Turn_On = torch_turn_on,
    .Torch_Turn_Off = torch_turn_off,
}



Call_Action :: struct {
    type: Block_Action,
    data: Action_Data,
}

Block_Info :: struct {
    flags: bit_set[Block_Flag],
    item: Maybe(Item_Type),
    model: Block_Model,
    texture: Block_Texture,
    on_right_click: Call_Action,
    on_activate: Call_Action,
    on_deactivate: Call_Action,
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
        on_activate = {.Activate_Wired_Blocks, {}}
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
        on_activate = {.Piston_Activate, {}},
    },
    .Button = {
        flags = {.HAS_BLOCK_FACE, .NO_COLLISION, .WIRE_INPUT, .STATEFUL},
        item = .Button,
        model = .Button,
        on_right_click = {.Button_Activate, {}}
    },
    .Torch = {
        flags = {.NO_COLLISION, .STATEFUL, .TEXTURE_TRANSPARENT, .WIRE_INPUT, .WIRE_OUTPUT},
        item = .Torch,
        model = .Torch,
        on_activate = {.Torch_Turn_Off, {}},
        on_deactivate = {.Torch_Turn_On, {}},
    }
}



block_init :: proc() {
    init_block_textures()
    init_models()
}
//TODO unload textures

//runs activate function of all block
activate_wired_blocks :: proc(pos: Vec3I, data: Action_Data) {
    block := world_get_block(pos)
    if !block.data.has_wires do return
    
    if wires, ok := state.world.wires[pos]; ok {
        for wire in wires {
            target_pos := wire.to
            target_block := world_get_block(target_pos)
            info := block_infos[target_block.type]
            if info.on_activate.type != .None {
                block_actions[info.on_activate.type](target_pos, info.on_activate.data)
            }
        }
    }
}

deactivate_wired_blocks :: proc(pos: Vec3I, data: Action_Data) {
    block := world_get_block(pos)
    if !block.data.has_wires do return
    
    if wires, ok := state.world.wires[pos]; ok {
        for wire in wires {
            target_pos := wire.to
            target_block := world_get_block(target_pos)
            info := block_infos[target_block.type]
            if info.on_deactivate.type != .None {
                block_actions[info.on_deactivate.type](target_pos, info.on_deactivate.data)
            }
        }
    }
}

button_activate :: proc(pos: Vec3I, data: Action_Data) {
    block := world_get_block(pos)
    if block.data.button.on do return
    block.data.button.on = true
    world_play_animation({type=.Button, pos=pos})
    world_set_block(pos, block)
    activate_wired_blocks(pos, {})
    world_schedule_action(.Button_Deactivate, pos, animation_infos[.Button].end)
}

button_deactivate :: proc(pos: Vec3I, data: Action_Data) {
    block := world_get_block(pos)
    if !block.data.button.on do return
    block.data.button.on = false
    world_set_block(pos, block)
    deactivate_wired_blocks(pos, {})
}

torch_turn_on :: proc(pos: Vec3I, data: Action_Data) {
    block := world_get_block(pos)
    if block.data.torch.on do return
    block.data.torch.on = true
    world_set_block(pos, block)
    activate_wired_blocks(pos, {})
}

torch_turn_off :: proc(pos: Vec3I, data: Action_Data) {
    block := world_get_block(pos)
    if !block.data.torch.on do return
    block.data.torch.on = false
    world_set_block(pos, block)
    deactivate_wired_blocks(pos, {})
}
piston_activate :: proc(pos: Vec3I, data: Action_Data) {
    piston_block := world_get_block(pos)
    if piston_block.data.piston.is_active do return

    piston_block.data.piston.is_active = true
    world_set_block(pos, piston_block)

    v := to_vec3i(face_to_normal(piston_block.data.facing))
    target_block := world_get_block(pos+v)
    destination_block := world_get_block(pos+v*2)
    if target_block.type != .Air && destination_block.type != .Air do return

    if target_block.type != .Air && destination_block.type == .Air {
        world_move_block(pos+v, pos+v*2)
        world_play_animation({type=.Move, pos=pos+v*2, from=pos+v})
        world_schedule_action(.Piston_Deactivate, pos, animation_infos[.Piston_Push].end, {pushed_block = true})
    }
    else {
        world_schedule_action(.Piston_Deactivate, pos, animation_infos[.Piston_Push].end, {pushed_block = false})
    }

    world_play_animation({type=.Piston_Push, pos=pos})
}
piston_deactivate :: proc(pos: Vec3I, data: Action_Data) {
    piston_block := world_get_block(pos)
    if !piston_block.data.piston.is_active do return

    world_set_block(pos, piston_block)

    v := to_vec3i(face_to_normal(piston_block.data.facing))
    destination_block := world_get_block(pos+v)
    target_block := world_get_block(pos+v*2)
    if target_block.type != .Air && destination_block.type == .Air && !data.pushed_block {
        world_move_block(pos+v*2, pos+v)
        world_play_animation({type=.Move, pos=pos+v, from=pos+v*2})
    }

    world_schedule_action(.Piston_Deactivate_Off, pos, animation_infos[.Piston_Pull].end)
    world_play_animation({type=.Piston_Pull, pos=pos})
}
piston_deactivate_off :: proc(pos: Vec3I, data: Action_Data) {
    piston_block := world_get_block(pos)
    piston_block.data.piston.is_active = false
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
    is_active: bool,
}
Redstone :: struct {
    on: bool,
    rotation: Block_Face,
    connections: [Cardinal]bool,
}
Wire :: struct {
    to: Vec3I
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
        return a.data.piston == b.data.piston
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
    pos2_i := to_vec3i(pos2)
    dir1 := state.place_dir
    dir2 := normal_to_direction(-state.place_dir_normal_2d)

    redstone := Block{.Redstone, {redstone={true, state.hit_face, {}}}}
    redstone.data.redstone.connections[dir1] = true
    world_set_block(pos1_i, redstone)

    redstone2 := Block{.Redstone, {redstone={true, state.hit_face, {}}}}
    redstone2.data.redstone.connections[dir2] = true
    world_set_block(pos2_i, redstone2)
}