package voxel_game
import rl "vendor:raylib"
import "core:fmt"





Block_Type :: enum {
    Air, Dirt, Stone, Cobblestone, Glass, Planks,
    Slab, Stairs, Piston, Button, Torch,
    Lever,
}

Block_Action :: enum {
    None,
    Activate_Wired_Blocks,
    On_Off,
    Piston_Activate,
    Piston_Deactivate,
    Button_Activate,
    Button_Deactivate,
    Piston_Deactivate_Off,
    Lever_Activate,
    Torch_Activate,
}
Action_Data :: struct {
    pushed_block: bool,
}

Block_Action_Proc :: proc(pos: Vec3I, block: ^Block, data: Action_Data)

block_actions := [Block_Action]Block_Action_Proc {
    .None = nil,
    .Activate_Wired_Blocks = activate_wired_blocks,
    .On_Off = on_off,
    .Piston_Activate = piston_activate,
    .Piston_Deactivate = piston_deactivate,
    .Piston_Deactivate_Off = piston_deactivate_off,
    .Button_Activate = button_activate,
    .Button_Deactivate = button_deactivate,
    .Lever_Activate = lever_activate,
    .Torch_Activate = torch_activate,
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
}
Block_Flag :: enum {
    TEXTURE_TRANSPARENT,
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
        flags = {.HAS_BLOCK_FACE, .NO_COLLISION, .WIRE_INPUT},
        item = .Button,
        model = .Button,
        on_right_click = {.Button_Activate, {}}
    },
    .Torch = {
        flags = {.NO_COLLISION, .TEXTURE_TRANSPARENT, .WIRE_INPUT, .WIRE_OUTPUT},
        item = .Torch,
        model = .Torch,
        on_activate = {.Torch_Activate, {}},
    },
    .Lever = {
        flags = {.HAS_BLOCK_FACE, .NO_COLLISION, .TEXTURE_TRANSPARENT, .WIRE_INPUT},
        item = .Lever,
        model = .Lever,
        on_right_click = {.Lever_Activate, {}},
    },
}



block_init :: proc() {
    init_block_textures()
    init_models()
}
//TODO unload textures

activate_wired_blocks :: proc(pos: Vec3I, block: ^Block, data: Action_Data) {
    if !block.has_wires do return
    
    if wires, ok := state.world.wires[pos]; ok {
        for wire in wires {
            if tracker, exists := state.world.traked_blocks[wire.to]; exists {
                target_pos := tracker.pos
                target_block := world_get_block(target_pos)
                info := block_infos[target_block.type]
                if info.on_activate.type != .None {
                    block_actions[info.on_activate.type](target_pos, &target_block, info.on_activate.data)
                    world_set_block(target_pos, target_block)
                }
            }
        }
    }
}
on_off :: proc(pos: Vec3I, block: ^Block, data: Action_Data) {
    block.is_on = !block.is_on
}
button_activate :: proc(pos: Vec3I, block: ^Block, data: Action_Data) {
    if block.is_on do return
    block.is_on = true
    world_play_animation(.Button, pos)
    world_schedule_action(.Button_Deactivate, pos, animation_infos[.Button].end)
    activate_wired_blocks(pos, block, {})
}
button_deactivate :: proc(pos: Vec3I, block: ^Block, data: Action_Data) {
    block.is_on = false
}
lever_activate :: proc(pos: Vec3I, block: ^Block, data: Action_Data) {
    block.is_on = !block.is_on
    activate_wired_blocks(pos, block, {})
}
piston_activate :: proc(pos: Vec3I, block: ^Block, data: Action_Data) {
    if block.is_on do return

    v := to_vec3i(face_to_normal(block.facing))
    target_block := world_get_block(pos+v)
    destination_block := world_get_block(pos+v*2)
    if target_block.type != .Air && destination_block.type != .Air do return

    block.is_on = true

    pushed: bool
    if target_block.type != .Air && destination_block.type == .Air {
        world_move_block(pos+v, pos+v*2)
        world_play_animation(.Move, pos+v*2, pos+v)
        pushed = true
    }

    world_schedule_action(.Piston_Deactivate, pos, animation_infos[.Piston_Push].end, {pushed_block = pushed})
    world_play_animation(.Piston_Push, pos)
}
piston_deactivate :: proc(pos: Vec3I, block: ^Block, data: Action_Data) {
    v := to_vec3i(face_to_normal(block.facing))
    destination_block := world_get_block(pos+v)
    target_block := world_get_block(pos+v*2)
    if target_block.type != .Air && destination_block.type == .Air && !data.pushed_block {
        world_move_block(pos+v*2, pos+v)
        world_play_animation(.Move, pos+v, pos+v*2)
    }

    world_schedule_action(.Piston_Deactivate_Off, pos, animation_infos[.Piston_Pull].end)
    world_play_animation(.Piston_Pull, pos)
}
piston_deactivate_off :: proc(pos: Vec3I, block: ^Block, data: Action_Data) {
    block.is_on = false
}
torch_activate :: proc(pos: Vec3I, block: ^Block, data: Action_Data) {
    if !block.is_on {
        block_actions[.Activate_Wired_Blocks](pos, block, data)
    }
    block_actions[.On_Off](pos, block, data)
}





//GAMEPLAY
Block :: struct {
    type: Block_Type,
    facing: Block_Face,
    direction: Cardinal,
    has_wires: bool,
    is_on: bool,
    using data: Block_Data,
}
Block_Data :: struct #raw_union {
}
Wire :: struct {
    to: int
}

are_blocks_equal :: proc(a, b: Block) -> bool {
    if a.type != b.type do return false
    if a.facing != b.facing do return false
    if a.direction != b.direction do return false
    if a.has_wires != b.has_wires do return false
    if a.is_on != b.is_on do return false
    
    return true
}

//rework, should be in item.odin
place_base_block :: proc(block: Block) {
    block := block
    info := block_infos[block.type]
    has_cardinal := .HAS_CARDINAL in info.flags
    has_block_face := .HAS_BLOCK_FACE in info.flags

    if has_cardinal && has_block_face {
        block.direction = state.place_yaw_dir
        block.facing = state.place_half
    } else if has_cardinal {
        block.direction = state.place_yaw_dir
    } else if has_block_face {
        block.facing = state.place_pitch_face
    }
    
    world_set_block(state.place_target, block)
}
