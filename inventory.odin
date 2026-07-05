package voxel_game

init_hotbar :: proc() {
    state.hotbar = {
        {.Dirt, {}},
        {.Stone, {}},
        {.Cobblestone, {}},
        {.Glass, {}},
        {.Planks, {}},
        {.Redstone, {}},
        {.Slab, {}},
        {.Stairs, {}},
        {.Air, {}},
    }
    state.held_block = state.hotbar[0]
}

init_inventory :: proc() {
    init_hotbar()
    for type in Item_Type {
        if block, ok := items[type].block.?; ok {
            if block == .Redstone {
                items[type].texture = get_redstone_texture(false, {}).texture
            } else {
                tex_type := block_infos[block].textures[.Top]
                items[type].texture = block_textures[tex_type]
            }
        }
    }
}
