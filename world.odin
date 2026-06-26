package voxel_game

World_State :: struct {
    chunks: map[[3]i32]^Chunk,
}
Chunk :: struct {
    palette: [dynamic]Block,
    block_keys: [16*16*16]int,
}
world: ^World_State

world_init :: proc() {
    world = &state.world
    world.chunks = make(map[[3]i32]^Chunk)
    
    chunk := new(Chunk)
    chunk.palette = make([dynamic]Block)
    append(&chunk.palette, Block{.Air, {}})
    stone := chunk_provide_block_key(chunk, {.Stone, {}})
    dirt := chunk_provide_block_key(chunk, {.Dirt, {}})
    
    world.chunks[{0, 0, 0}] = chunk
    for i in 0..<16*16 {
        x: i32 = i32(i/16)
        z: i32 = i32(i%16)
        chunk.block_keys[flatten({x, 0, z})] = stone
        chunk.block_keys[flatten({x, 1, z})] = dirt
    }
}

//Returns the block id from palette. If the block is not present it will get created.
chunk_provide_block_key :: proc(chunk: ^Chunk, block: Block) -> int {
    for search_block, id in chunk.palette {
        if search_block == block {
            return id
        }
    }
    append(&chunk.palette, block)
    return len(chunk.palette)-1
}

//Return the block id from palette -1 if not found.
chunk_get_block_key :: proc(chunk: ^Chunk, block: Block) -> int {
    for search_block, id in chunk.palette {
        if search_block == block {
            return id
        }
    }
    return -1
}

world_get_block :: proc(pos: [3]i32) -> Block {
    c_pos := get_chunk_pos(pos)
    if c_pos in world.chunks {
        chunk := world.chunks[c_pos]
        l_pos := get_local_pos(pos)
        block_key := chunk.block_keys[flatten(l_pos)]
        return chunk.palette[block_key]
    }
    return {.Air, {}}
}

world_set_block :: proc(pos: [3]i32, block: Block) {
    c_pos := get_chunk_pos(pos)
    if c_pos not_in world.chunks {
        chunk := new(Chunk)
        chunk.palette = make([dynamic]Block)
        append(&chunk.palette, Block{.Air, {}})
        world.chunks[c_pos] = chunk
    }
    chunk := world.chunks[c_pos]
    l_pos := get_local_pos(pos)
    block_key := chunk_provide_block_key(chunk, block)
    chunk.block_keys[flatten(l_pos)] = block_key
}