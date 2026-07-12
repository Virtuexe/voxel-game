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
    Deactivate_Wired_Blocks,
    Piston_Activate,
    Piston_Deactivate,
    Button_Activate,
    Button_Deactivate,
    Piston_Deactivate_Off,
    Lever_Activate,
    Lever_Deactivate,
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
    .Lever_Activate = lever_activate,
    .Lever_Deactivate = lever_activate,
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
        on_activate = {.Deactivate_Wired_Blocks, {}},
        on_deactivate = {.Activate_Wired_Blocks, {}},
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

//runs activate function of all block
activate_wired_blocks :: proc(pos: Vec3I, data: Action_Data) {
    block := world_get_block(pos)
    if !block.has_wires do return
    
    if wires, ok := state.world.wires[pos]; ok {
        for wire in wires {
            if tracker, exists := state.world.traked_blocks[wire.to]; exists {
                target_pos := tracker.pos
                target_block := world_get_block(target_pos)
                info := block_infos[target_block.type]
                if info.on_activate.type != .None {
                    block_actions[info.on_activate.type](target_pos, info.on_activate.data)
                }
            }
        }
    }
}

deactivate_wired_blocks :: proc(pos: Vec3I, data: Action_Data) {
    block := world_get_block(pos)
    if !block.has_wires do return
    
    if wires, ok := state.world.wires[pos]; ok {
        for wire in wires {
            if tracker, exists := state.world.traked_blocks[wire.to]; exists {
                target_pos := tracker.pos
                target_block := world_get_block(target_pos)
                info := block_infos[target_block.type]
                if info.on_deactivate.type != .None {
                    block_actions[info.on_deactivate.type](target_pos, info.on_deactivate.data)
                }
            }
        }
    }
}

button_activate :: proc(pos: Vec3I, data: Action_Data) {
    block := world_get_block(pos)
    if block.is_on do return
    block.is_on = true
    world_play_animation(.Button, pos)
    world_set_block(pos, block)
    activate_wired_blocks(pos, {})
    world_schedule_action(.Button_Deactivate, pos, animation_infos[.Button].end)
}

button_deactivate :: proc(pos: Vec3I, data: Action_Data) {
    block := world_get_block(pos)
    if !block.is_on do return
    block.is_on = false
    world_set_block(pos, block)
    deactivate_wired_blocks(pos, {})
}

lever_activate :: proc(pos: Vec3I, data: Action_Data) {
    block := world_get_block(pos)
    block.is_on = !block.is_on
    world_set_block(pos, block)
    if block.is_on {
        activate_wired_blocks(pos, {})
    } else {
        deactivate_wired_blocks(pos, {})
    }
}
piston_activate :: proc(pos: Vec3I, data: Action_Data) {
    piston_block := world_get_block(pos)
    if piston_block.is_on do return

    piston_block.is_on = true
    piston_block.data = piston_block.data
    world_set_block(pos, piston_block)

    v := to_vec3i(face_to_normal(piston_block.facing))
    target_block := world_get_block(pos+v)
    destination_block := world_get_block(pos+v*2)
    if target_block.type != .Air && destination_block.type != .Air do return

    if target_block.type != .Air && destination_block.type == .Air {
        world_move_block(pos+v, pos+v*2)
        world_play_animation(.Move, pos+v*2, pos+v)
        world_schedule_action(.Piston_Deactivate, pos, animation_infos[.Piston_Push].end, {pushed_block = true})
    }
    else {
        world_schedule_action(.Piston_Deactivate, pos, animation_infos[.Piston_Push].end, {pushed_block = false})
    }

    world_play_animation(.Piston_Push, pos)
}
piston_deactivate :: proc(pos: Vec3I, data: Action_Data) {
    piston_block := world_get_block(pos)
    if !piston_block.is_on do return

    world_set_block(pos, piston_block)

    v := to_vec3i(face_to_normal(piston_block.facing))
    destination_block := world_get_block(pos+v)
    target_block := world_get_block(pos+v*2)
    if target_block.type != .Air && destination_block.type == .Air && !data.pushed_block {
        world_move_block(pos+v*2, pos+v)
        world_play_animation(.Move, pos+v, pos+v*2)
    }

    world_schedule_action(.Piston_Deactivate_Off, pos, animation_infos[.Piston_Pull].end)
    world_play_animation(.Piston_Pull, pos)
}
piston_deactivate_off :: proc(pos: Vec3I, data: Action_Data) {
    piston_block := world_get_block(pos)
    piston_block.is_on = false
    world_set_block(pos, piston_block)
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
    
    if block.type == .Torch {
        block.is_on = true
    }
    
    world_set_block(state.place_target, block)
}
