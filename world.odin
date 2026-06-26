package voxel_game

World_State :: struct {
    palette: [dynamic]Block,
    chunks: map[[3]i32]^Chunk,
}
Chunk :: struct {
    block_keys: [16*16*16]int,
}
world: ^World_State

world_init :: proc() {
    world = &state.world
    world.palette = init_palette()
    world.chunks = make(map[[3]i32]^Chunk)
    stone := palette_provide_block_key({.Stone, {}})
    dirt := palette_provide_block_key({.Dirt, {}})
    
    chunk := new(Chunk)
    world.chunks[{0, 0, 0}] = chunk
    for i in 0..<16*16 {
        x: i32 = i32(i/16)
        z: i32 = i32(i%16)
        chunk.block_keys[flatten({x, 0, z})] = stone
        chunk.block_keys[flatten({x, 1, z})] = dirt
    }
}

init_palette :: proc() -> [dynamic]Block {
    palette := make([dynamic]Block)
    append(&palette, Block{.Air, {}})
    return palette
}
//Returns the block id from palette. If the block is not present it will get created.
palette_provide_block_key :: proc(block: Block) -> int {
    for search_block, id in world.palette {
        if search_block == block {
            return id
        }
    }
    append(&world.palette, block)
    return len(world.palette)-1
}

//Return the block id from palette -1 if not found.
palette_get_block_key :: proc(block: Block) -> int {
    for search_block, id in world.palette {
        if search_block == block {
            return id
        }
    }
    return -1
}

world_get_block :: proc(pos: [3]i32) -> int {
    c_pos := get_chunk_pos(pos)
    if c_pos in world.chunks {
        l_pos := get_local_pos(pos)
        return world.chunks[c_pos].block_keys[flatten(l_pos)]
    }
    return 0
}

world_set_block :: proc(pos: [3]i32, block_key: int) {
    c_pos := get_chunk_pos(pos)
    if c_pos not_in world.chunks {
        world.chunks[c_pos] = new(Chunk)
    }
    l_pos := get_local_pos(pos)
    world.chunks[c_pos].block_keys[flatten(l_pos)] = block_key
}