package voxel_game
Block :: union {
    Stateless_Block, Redstone
}
Stateless_Block :: enum {
    Air, Dirt, Stone
}
Redstone :: struct {
    rotation: Side,
    connections: [Direction]bool
}

World_State :: struct {
    //palette: [dynamic]Block,
    blocks: [16*16*16]Stateless_Block,
}
world: ^World_State

world_init :: proc() {
    world = &state.world
    for i in 0..<16*16 {
        x: i32 = i32(i/16)
        z: i32 = i32(i%16)
        world.blocks[flatten({x, 0, z})] = .Stone
        world.blocks[flatten({x, 1, z})] = .Dirt
    }
}