package voxel_game
import rl "vendor:raylib"
import "core:math"
import "core:fmt"

World_State :: struct {
    chunks: map[Vec3I]^Chunk,
    wires: map[Vec3I][dynamic]Wire,
    scheduled_actions: [dynamic]Scheduled_Action,
    animations: map[int]Block_Animations,
    traked_blocks: map[int]Block_Tracker,
    next_id: int
}

Block_Animations :: struct {
    count: int,
    list: [4]Animation_Data,
}

Scheduled_Action :: struct {
    action: Block_Action,
    block_id: int,
    data: Action_Data,
    time_left: f32,
}

Chunk :: struct {
    palette: [dynamic]Block,
    block_keys: [16*16*16]int,
    dynamic_blocks: [dynamic]int,
    model: rl.Model,
    is_dirty: bool,
    has_model: bool,
}

world_init :: proc() {
    state.world.chunks = make(map[Vec3I]^Chunk)
    state.world.wires = make(map[Vec3I][dynamic]Wire)
    state.world.scheduled_actions = make([dynamic]Scheduled_Action)
    state.world.traked_blocks = make(map[int]Block_Tracker)
    state.world.animations = make(map[int]Block_Animations)
    
    size := 256
    for x in -size..<size {
        for z in -size..<size {
            world_set_block({i32(x), 0, i32(z)}, Block{type = .Stone})
            world_set_block({i32(x), 1, i32(z)}, Block{type = .Dirt})
        }
    }
    world_set_block({0, 1, 0}, Block{type = .Cobblestone})
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
    if pos.y < 0 || pos.y >= CHUNK.y do return Block{type = .Air}
    return Block{type = .Air}
}

world_set_block :: proc(pos: Vec3I, block: Block) {
    c_pos := get_chunk_pos(pos)
    if c_pos not_in state.world.chunks {
        chunk := new(Chunk)
        chunk.palette = make([dynamic]Block)
        chunk.dynamic_blocks = make([dynamic]int)
        append(&chunk.palette, Block{type = .Air})
        state.world.chunks[c_pos] = chunk
    }
    chunk := state.world.chunks[c_pos]
    chunk.is_dirty = true
    l_pos := get_local_pos(pos)
    block_key := chunk_provide_block_key(chunk, block)
    chunk.block_keys[flatten(l_pos)] = block_key

    // Invalidate neighbors if on boundary
    if l_pos.x == 0 && (c_pos - {1, 0, 0}) in state.world.chunks do state.world.chunks[c_pos - {1, 0, 0}].is_dirty = true
    if l_pos.x == 15 && (c_pos + {1, 0, 0}) in state.world.chunks do state.world.chunks[c_pos + {1, 0, 0}].is_dirty = true
    if l_pos.y == 0 && (c_pos - {0, 1, 0}) in state.world.chunks do state.world.chunks[c_pos - {0, 1, 0}].is_dirty = true
    if l_pos.y == 15 && (c_pos + {0, 1, 0}) in state.world.chunks do state.world.chunks[c_pos + {0, 1, 0}].is_dirty = true
    if l_pos.z == 0 && (c_pos - {0, 0, 1}) in state.world.chunks do state.world.chunks[c_pos - {0, 0, 1}].is_dirty = true
    if l_pos.z == 15 && (c_pos + {0, 0, 1}) in state.world.chunks do state.world.chunks[c_pos + {0, 0, 1}].is_dirty = true
}

world_delete_block :: proc(pos: Vec3I) {
    if id, ok := world_get_tracker_id(pos); ok {
        delete_key(&state.world.traked_blocks, id)
    }
    
    if wires, ok := state.world.wires[pos]; ok {
        for wire in wires {
            world_untrack_block(wire.to)
        }
        delete(state.world.wires[pos])
        delete_key(&state.world.wires, pos)
    }
    
    world_set_block(pos, Block{type = .Air})
}

world_move_block :: proc(from_pos, to_pos: Vec3I) {
    block := world_get_block(from_pos)
    
    // If the destination block has wires, those wires will be overwritten. We must free them.
    if to_pos in state.world.wires {
        delete(state.world.wires[to_pos])
        delete_key(&state.world.wires, to_pos)
    }
    
    // Transfer wires from from_pos to to_pos
    if block.has_wires && from_pos in state.world.wires {
        state.world.wires[to_pos] = state.world.wires[from_pos]
        delete_key(&state.world.wires, from_pos)
    }
    
    // Update pos of active tracker if this block is tracked
    for id, &t in state.world.traked_blocks {
        if t.pos == from_pos {
            t.pos = to_pos
        }
    }
    
    world_set_block(to_pos, block)
    world_delete_block(from_pos)
}



world_schedule_action :: proc(action: Block_Action, pos: Vec3I, delay: f32, data: Action_Data = {}) {
    id := world_track_block(pos)
    append(&state.world.scheduled_actions, Scheduled_Action{
        action = action,
        block_id = id,
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
            id := action.block_id
            data := action.data
            unordered_remove(&state.world.scheduled_actions, i)
            if block_actions[a] != nil {
                if id in state.world.traked_blocks {
                    block_actions[a](state.world.traked_blocks[id].pos, data)
                }
            }
            world_untrack_block(id)
        } else {
            i += 1
        }
    }
}

world_play_animation :: proc(type: Animation_Type, pos: Vec3I, from: Vec3I = {}) {
    id := world_track_block(pos)
    
    if id not_in state.world.animations {
        state.world.animations[id] = Block_Animations{}
    }
    
    anims := state.world.animations[id]
    if anims.count < 4 {
        anims.list[anims.count] = Animation_Data{
            type = type,
            block_id = id,
            progress = 0,
            from = from,
        }
        anims.count += 1
        state.world.animations[id] = anims
    }
}
update_world_animations :: proc() {
    delta := f32(rl.GetFrameTime())
    
    untrack_list := make([dynamic]int, context.temp_allocator)
    
    for id, &anims in state.world.animations {
        for i := 0; i < anims.count; {
            anim := &anims.list[i]
            info := animation_infos[anim.type]
            
            anim.progress += delta
            if anim.progress >= info.end {
                anims.list[i] = anims.list[anims.count - 1]
                anims.count -= 1
                append(&untrack_list, id)
            } else {
                i += 1
            }
        }
    }
    
    for id in untrack_list {
        world_untrack_block(id)
        if state.world.animations[id].count == 0 {
            delete_key(&state.world.animations, id)
        }
    }
}

Block_Tracker :: struct {
    pos: Vec3I,
    ref_count: int,
}

world_track_block :: proc(pos: Vec3I) -> int {
    for id, &t in state.world.traked_blocks {
        if t.pos == pos {
            t.ref_count += 1
            return id
        }
    }
    
    state.world.next_id += 1
    id := state.world.next_id
    state.world.traked_blocks[id] = Block_Tracker{pos = pos, ref_count = 1}
    return id
}

world_get_tracker_id :: proc(pos: Vec3I) -> (id: int, ok: bool) {
    for tracker_id, t in state.world.traked_blocks {
        if t.pos == pos {
            return tracker_id, true
        }
    }
    return 0, false
}

world_untrack_block :: proc(id: int) {
    if id not_in state.world.traked_blocks do return
    t := state.world.traked_blocks[id]
    t.ref_count -= 1
    if t.ref_count <= 0 {
        delete_key(&state.world.traked_blocks, id)
    } else {
        state.world.traked_blocks[id] = t
    }
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
    if it.curr.x > it.center.x + 1 do return Block{type = .Air}, {}, false

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