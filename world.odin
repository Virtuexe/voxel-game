package voxel_game
import rl "vendor:raylib"
import "core:math"

World_State :: struct {
    chunks: map[[3]i32]^Chunk,
    wires: map[[3]i32][dynamic]Wire,
    pending_moves: [dynamic]Pending_Move,
}

Pending_Move :: struct {
    from_pos: [3]i32,
    to_pos: [3]i32,
    start_time: f64,
    duration: f64,
}
Chunk :: struct {
    palette: [dynamic]Block,
    block_keys: [16*16*16]int,
}

world_init :: proc() {
    state.world.chunks = make(map[[3]i32]^Chunk)
    state.world.wires = make(map[[3]i32][dynamic]Wire)
    state.world.pending_moves = make([dynamic]Pending_Move)
    
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

world_get_block :: proc(pos: [3]i32) -> Block {
    c_pos := get_chunk_pos(pos)
    if c_pos in state.world.chunks {
        chunk := state.world.chunks[c_pos]
        l_pos := get_local_pos(pos)
        block_key := chunk.block_keys[flatten(l_pos)]
        return chunk.palette[block_key]
    }
    return {.Air, {}}
}

world_set_block :: proc(pos: [3]i32, block: Block) {
    if !block.data.has_wires && pos in state.world.wires {
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

world_move_block :: proc(from_pos, to_pos: [3]i32) {
    block := world_get_block(from_pos)
    
    // If the destination block has wires, those wires will be overwritten. We must free them.
    if to_pos in state.world.wires {
        delete(state.world.wires[to_pos])
        delete_key(&state.world.wires, to_pos)
    }
    
    // Transfer wires from from_pos to to_pos
    if block.data.has_wires && from_pos in state.world.wires {
        state.world.wires[to_pos] = state.world.wires[from_pos]
        delete_key(&state.world.wires, from_pos)
    }
    
    world_set_block(to_pos, block)
    world_set_block(from_pos, Block{.Air, {}})
}

world_schedule_move :: proc(from_pos, to_pos: [3]i32, delay: f64, duration: f64) {
    append(&state.world.pending_moves, Pending_Move{
        from_pos = from_pos,
        to_pos = to_pos,
        start_time = rl.GetTime() + delay,
        duration = duration,
    })
}

world_update_moves :: proc() {
    time := rl.GetTime()
    for i := 0; i < len(state.world.pending_moves); {
        move := state.world.pending_moves[i]
        if time >= move.start_time + move.duration {
            world_move_block(move.from_pos, move.to_pos)
            unordered_remove(&state.world.pending_moves, i)
        } else {
            i += 1
        }
    }
}

get_pending_move_offset :: proc(pos: [3]i32) -> rl.Vector3 {
    time := rl.GetTime()
    for move in state.world.pending_moves {
        if pos == move.from_pos {
            t := f32((time - move.start_time) / move.duration)
            t = math.clamp(t, 0.0, 1.0)
            return (to_vec3(move.to_pos) - to_vec3(move.from_pos)) * t
        }
    }
    return {0, 0, 0}
}

Player_Block_Iterator :: struct {
    center: [3]i32,
    curr: [3]i32,
}

make_player_block_iterator :: proc(center: [3]i32) -> Player_Block_Iterator {
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

player_block_iterator_next :: proc(it: ^Player_Block_Iterator) -> (block: Block, coords: [3]i32, cond: bool) {
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