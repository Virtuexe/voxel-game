package voxel_game

World_State :: struct {
    palette: [dynamic]Block,
    block_keys: [16*16*16]int,
}
world: ^World_State

world_init :: proc() {
    world = &state.world
    world.palette = init_palette()
    stone := palette_provide_block_key({.Stone, {}})
    dirt := palette_provide_block_key({.Dirt, {}})
    for i in 0..<16*16 {
        x: i32 = i32(i/16)
        z: i32 = i32(i%16)
        world.block_keys[flatten({x, 0, z})] = stone
        world.block_keys[flatten({x, 1, z})] = dirt
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