package voxel_game
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

//RENDER
block_model: rl.Model
decal_model: rl.Model
redstone_render_texture: [(1<<len(Direction))*2]rl.RenderTexture2D
block_cube_textures: [Block_Type]rl.Texture2D
is_texture_cube :: proc(block: Block_Type) -> bool {
    switch block {
    case .Dirt, .Stone:
        return true
    case .Air, .Redstone:
        return false
    }
    return {}
}
is_texture_decal :: proc(block: Block_Type) -> bool {
    #partial switch block {
    case .Redstone:
        return true
    case:
        return false
    }
}
is_texture_transparent :: proc(block: Block_Type) -> bool {
    #partial switch block {
    case .Redstone:
        return true
    case:
        return false
    }
}

//GAMEPLAY
Block :: struct {
    type: Block_Type,
    data: Block_Data,
}
Block_Type :: enum {
    Air, Dirt, Stone,
    Redstone,
}
Block_Data :: struct #raw_union {
    redstone: Redstone,
}
is_block_stateless :: proc(block: Block) -> bool {
    switch block.type {
    case .Air, .Dirt, .Stone:
        return true
    case .Redstone: 
        return false
    }
    return false
}
Redstone :: struct {
    on: bool,
    rotation: Face,
    connections: [Direction]bool,
}

block_place :: proc() {
    block := state.block_in_hand
    if is_overlapping(state.cam.position, unflatten(state.place_block_index), block) {
        return
    }
    #partial switch block.type {
    case .Redstone:
        place_redstone()
    case:
        place_base_block(block)
    }
    raycast()
}
place_base_block :: proc(block: Block) {
    world.block_keys[state.place_block_index] = palette_provide_block_key(block)
}
place_redstone :: proc() {
    pos1 := state.place_block
    pos2 := pos1 + state.place_block_direction_normal
    pos1_i := state.place_block_index
    pos2_i := flatten(from_vec3(pos2))
    dir1 := state.place_block_direction
    dir2 := normal_to_direction(-state.place_block_direction_normal_2d)

    redstone := Block{.Redstone, {redstone={true, state.place_block_face, {}}}}
    redstone.data.redstone.connections[dir1] = true
    world.block_keys[pos1_i] = palette_provide_block_key(redstone)

    redstone2 := Block{.Redstone, {redstone={true, state.place_block_face, {}}}}
    redstone2.data.redstone.connections[dir2] = true
    world.block_keys[pos2_i] = palette_provide_block_key(redstone2)
}