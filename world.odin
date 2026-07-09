package voxel_game
import rl "vendor:raylib"
import "core:math"

World_State :: struct {
    chunks: map[Vec3I]^Chunk,
    wires: map[Vec3I][dynamic]Wire,
    scheduled_actions: [dynamic]Scheduled_Action,
    animations: [dynamic]Animation_Data,
    traked_blocks: map[int]Block_Tracker,
    next_id: int
}

Scheduled_Action :: struct {
    action: Block_Action,
    pos: Vec3I,
    data: Action_Data,
    time_left: f32,
}

Chunk :: struct {
    palette: [dynamic]Block,
    block_keys: [16*16*16]int,
}

world_init :: proc() {
    state.world.chunks = make(map[Vec3I]^Chunk)
    state.world.wires = make(map[Vec3I][dynamic]Wire)
    state.world.scheduled_actions = make([dynamic]Scheduled_Action)
    
    for x in -8..<8 {
        for z in -8..<8 {
            world_set_block({i32(x), 0, i32(z)}, Block{.Stone, {}})
            world_set_block({i32(x), 1, i32(z)}, Block{.Dirt, {}})
        }
    }
}

//Returns the block id from palette. If the block is not present it will get created.
chunk_provide_block_key :: proc(chunk: ^Chunk, block: Block) -> int {
    for search_block, id in chunk.palette {
        if are_blocks_equal(search_block, block) {
            return id
        }
    }
    append(&chunk.palette, block)
    return len(chunk.palette)-1
}

//Return the block id from palette -1 if not found.
chunk_get_block_key :: proc(chunk: ^Chunk, block: Block) -> int {
    for search_block, id in chunk.palette {
        if are_blocks_equal(search_block, block) {
            return id
        }
    }
    return -1
}

// Removes unused blocks from the palette and remaps block keys accordingly
chunk_clean_palette :: proc(chunk: ^Chunk) {
    used := make([]bool, len(chunk.palette))
    defer delete(used)
    
    for key in chunk.block_keys {
        used[key] = true
    }
    
    new_palette := make([dynamic]Block)
    key_map := make([]int, len(chunk.palette))
    defer delete(key_map)
    
    for i in 0..<len(chunk.palette) {
        if used[i] {
            append(&new_palette, chunk.palette[i])
            key_map[i] = len(new_palette) - 1
        } else {
            key_map[i] = -1
        }
    }
    
    for i in 0..<len(chunk.block_keys) {
        chunk.block_keys[i] = key_map[chunk.block_keys[i]]
    }
    
    delete(chunk.palette)
    chunk.palette = new_palette
}

world_get_block :: proc(pos: Vec3I) -> Block {
    c_pos := get_chunk_pos(pos)
    if c_pos in state.world.chunks {
        chunk := state.world.chunks[c_pos]
        l_pos := get_local_pos(pos)
        block_key := chunk.block_keys[flatten(l_pos)]
        return chunk.palette[block_key]
    }
    return {.Air, {}}
}

world_set_block :: proc(pos: Vec3I, block: Block) {
    if !get_block_has_wires(block) && pos in state.world.wires {
        delete(state.world.wires[pos])
        delete_key(&state.world.wires, pos)
    }
    
    c_pos := get_chunk_pos(pos)
    if c_pos not_in state.world.chunks {
        chunk := new(Chunk)
        chunk.palette = make([dynamic]Block)
        append(&chunk.palette, Block{.Air, {}})
        state.world.chunks[c_pos] = chunk
    }
    chunk := state.world.chunks[c_pos]
    l_pos := get_local_pos(pos)
    block_key := chunk_provide_block_key(chunk, block)
    chunk.block_keys[flatten(l_pos)] = block_key
}

world_move_block :: proc(from_pos, to_pos: Vec3I) {
    block := world_get_block(from_pos)
    
    // If the destination block has wires, those wires will be overwritten. We must free them.
    if to_pos in state.world.wires {
        delete(state.world.wires[to_pos])
        delete_key(&state.world.wires, to_pos)
    }
    
    // Transfer wires from from_pos to to_pos
    if get_block_has_wires(block) && from_pos in state.world.wires {
        state.world.wires[to_pos] = state.world.wires[from_pos]
        delete_key(&state.world.wires, from_pos)
    }
    
    world_set_block(to_pos, block)
    world_set_block(from_pos, Block{.Air, {}})
}



world_schedule_action :: proc(action: Block_Action, pos: Vec3I, delay: f32, data: Action_Data = {}) {
    append(&state.world.scheduled_actions, Scheduled_Action{
        action = action,
        pos = pos,
        data = data,
        time_left = delay,
    })
}

update_world :: proc() {
    update_world_scheduled_actions()
    update_world_animations()
}
update_world_scheduled_actions :: proc() {
    delta := f32(rl.GetFrameTime())
    for i := 0; i < len(state.world.scheduled_actions); {
        action := &state.world.scheduled_actions[i]
        action.time_left -= delta
        if action.time_left <= 0 {
            a := action.action
            pos := action.pos
            data := action.data
            unordered_remove(&state.world.scheduled_actions, i)
            if block_actions[a] != nil {
                block_actions[a](pos, data)
            }
        } else {
            i += 1
        }
    }
}

world_play_animation :: proc(data: Animation_Data) {
    append(&state.world.animations, data)
}
update_world_animations :: proc() {
    delta := f32(rl.GetFrameTime())
    for i := 0; i < len(state.world.animations); {
        anim := &state.world.animations[i]
        info := animation_infos[anim.type]
        
        anim.progress += delta
        if anim.progress >= info.end {
            unordered_remove(&state.world.animations, i)
        } else {
            i += 1
        }
    }
}



get_active_animation :: proc(pos: Vec3I) -> (anim: Animation_Data, ok: bool) {
    for a in state.world.animations {
        if a.pos == pos {
            return a, true
        }
    }
    return {}, false
}

Block_Tracker :: struct {
    pos: Vec3I,
}

Player_Block_Iterator :: struct {
    center: Vec3I,
    curr: Vec3I,
}

make_player_block_iterator :: proc(center: Vec3I) -> Player_Block_Iterator {
    return {
        center = center,
        curr = {center.x - 1, center.y - 1, center.z - 1},
    }
}

get_target_block :: proc() -> Block {
    return world_get_block(state.look_target)
}

set_target_block :: proc(block: Block) {
    world_set_block(state.look_target, block)
}

player_block_iterator_next :: proc(it: ^Player_Block_Iterator) -> (block: Block, coords: Vec3I, cond: bool) {
    if it.curr.x > it.center.x + 1 do return {}, {}, false

    coords = it.curr
    block = world_get_block(coords)
    cond = true

    it.curr.z += 1
    if it.curr.z > it.center.z + 1 {
        it.curr.z = it.center.z - 1
        it.curr.y += 1
        if it.curr.y > it.center.y + 2 {
            it.curr.y = it.center.y - 1
            it.curr.x += 1
        }
    }
    return
}