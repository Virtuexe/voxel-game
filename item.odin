package voxel_game

import ui "raylib-ui"

Item_Type :: enum {
    Dirt, Stone, Cobblestone, Glass, Planks,
    Redstone, Slab, Stairs, Piston,
    Wire, Button, Torch
}

Item_Data :: struct {
    selected_block: Maybe(Vec3I),
}

Item :: struct {
    type: Item_Type,
    data: Item_Data,
}

Item_Flag :: enum {
    WIRES_VISIBLE,
}

Item_Action :: enum {
    None,
    Block_Place,
    Wire_Item_Right_Click,
    Wire_Item_Left_Click,
}
Item_Action_Proc :: proc(item: ^Item)

item_actions := [Item_Action]Item_Action_Proc {
    .None = nil,
    .Block_Place = block_place,
    .Wire_Item_Right_Click = wire_item_right_click,
    .Wire_Item_Left_Click = wire_item_left_click,
}

Item_Info :: struct {
    flags: bit_set[Item_Flag],
    block: Maybe(Block_Type),
    name: string,
    texture: Texture_Type,
    on_right_click: Item_Action,
    on_left_click: Item_Action,
}
items := [Item_Type]Item_Info{
    .Dirt = {
        block = .Dirt,
        name = "Dirt",
        texture = .Dirt,
        on_right_click = .Block_Place,
    },
    .Stone = {
        block = .Stone,
        name = "Stone",
        texture = .Stone,
        on_right_click = .Block_Place,
    },
    .Cobblestone = {
        block = .Cobblestone,
        name = "Cobblestone",
        texture = .Cobblestone,
        on_right_click = .Block_Place,
    },
    .Glass = {
        block = .Glass,
        name = "Glass",
        texture = .Glass,
        on_right_click = .Block_Place,
    },
    .Planks = {
        block = .Planks,
        name = "Planks",
        texture = .Planks,
        on_right_click = .Block_Place,
    },
    .Redstone = {
        block = .Redstone,
        name = "Redstone",
        texture = .Wire,
        on_right_click = .Block_Place,
    },
    .Slab = {
        block = .Slab,
        name = "Slab",
        texture = .Slab_Top,
        on_right_click = .Block_Place,
    },
    .Stairs = {
        block = .Stairs,
        name = "Stairs",
        texture = .Planks,
        on_right_click = .Block_Place,
    },
    .Piston = {
        block = .Piston,
        name = "Piston",
        texture = .Piston_Top,
        on_right_click = .Block_Place,
    },
    .Wire = {
        flags = {.WIRES_VISIBLE},
        name = "Wire",
        texture = .Wire,
        on_right_click = .Wire_Item_Right_Click,
        on_left_click = .Wire_Item_Left_Click,
    },
    .Button = {
        block = .Button,
        name = "Button",
        texture = .Stone,
        on_right_click = .Block_Place,
    },
    .Torch = {
        block = .Torch,
        name = "Torch",
        texture = .Torch_On,
        on_right_click = .Block_Place,
    }
}

wire_item_right_click :: proc(item: ^Item) {
    if !state.looking_at_block do return
    if pos, ok := item.data.selected_block.?; ok {
        if pos == state.look_target do return
        
        source_block := world_get_block(pos)
        target_block := world_get_block(state.look_target)
        
        source_info := block_infos[source_block.type]
        target_info := block_infos[target_block.type]
        
        if !(.WIRE_INPUT in source_info.flags) || !(.WIRE_OUTPUT in target_info.flags) {
            item.data.selected_block = nil
            return
        }
        
        if pos not_in state.world.wires {
            state.world.wires[pos] = make([dynamic]Wire)
        }
        
        target_wire := Wire{state.look_target}
        found_idx := -1
        for a, i in state.world.wires[pos] {
            if a == target_wire {
                found_idx = i
                break
            }
        }
        
        if found_idx >= 0 {
            unordered_remove(&state.world.wires[pos], found_idx)
            if len(state.world.wires[pos]) == 0 {
                set_block_has_wires(&source_block, false)
                world_set_block(pos, source_block)
            }
        } else {
            append(&state.world.wires[pos], target_wire)
            if !get_block_has_wires(source_block) {
                set_block_has_wires(&source_block, true)
                world_set_block(pos, source_block)
            }
        }
    } else {
        target_block := world_get_block(state.look_target)
        target_info := block_infos[target_block.type]
        if .WIRE_INPUT in target_info.flags {
            item.data.selected_block = state.look_target
        }
    }
}

wire_item_left_click :: proc(item: ^Item) {
    item.data.selected_block = nil
}

block_place :: proc(item: ^Item) {
    if state.held_item == nil do return
    block_type, ok := items[item.type].block.?
    if !ok do return
    block := Block{type=block_type}
    if is_overlapping(state.position, state.place_target, block) do return
    if world_get_block(state.place_target).type != .Air do return
    #partial switch block.type {
    case .Redstone:
        place_redstone()
    case:
        place_base_block(block)
    }
    raycast()
}