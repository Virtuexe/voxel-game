package voxel_game
import rl "vendor:raylib"

Input :: struct {
    btn: Btn,
    double_tap: Maybe(Double_Tap),
}
Double_Tap :: struct {
    last_pressed_at: f64,
    tapped_this_frame: bool,
}
Btn :: union {Keyboard_Btn, Mouse_Btn}
Keyboard_Btn :: rl.KeyboardKey
Mouse_Btn :: rl.MouseButton
Action :: enum {
    Menu, Inventory, Debug,
    Forward, Backward, Left, Right,
    Jump, Crouch, Sprint,
    Hotbar_1, Hotbar_2, Hotbar_3, Hotbar_4, Hotbar_5, Hotbar_6, Hotbar_7, Hotbar_8, Hotbar_9,
    Attack, Use, Code, Fly
}

bindings := [Action]Input{
    .Menu = {btn = Keyboard_Btn.ESCAPE},
    .Inventory = {btn = Keyboard_Btn.E},
    .Debug = {btn = Keyboard_Btn.F3},
    .Forward = {btn = Keyboard_Btn.W},
    .Backward = {btn = Keyboard_Btn.S},
    .Left = {btn = Keyboard_Btn.A},
    .Right = {btn = Keyboard_Btn.D},
    .Jump = {btn = Keyboard_Btn.SPACE},
    .Crouch = {btn = Keyboard_Btn.LEFT_SHIFT},
    .Sprint = {btn = Keyboard_Btn.LEFT_CONTROL},
    .Hotbar_1 = {btn = Keyboard_Btn.ONE},
    .Hotbar_2 = {btn = Keyboard_Btn.TWO},
    .Hotbar_3 = {btn = Keyboard_Btn.THREE},
    .Hotbar_4 = {btn = Keyboard_Btn.FOUR},
    .Hotbar_5 = {btn = Keyboard_Btn.FIVE},
    .Hotbar_6 = {btn = Keyboard_Btn.SIX},
    .Hotbar_7 = {btn = Keyboard_Btn.SEVEN},
    .Hotbar_8 = {btn = Keyboard_Btn.EIGHT},
    .Hotbar_9 = {btn = Keyboard_Btn.NINE},
    .Attack = {btn = Mouse_Btn.LEFT},
    .Use = {btn = Mouse_Btn.RIGHT},
    .Code = {btn = Keyboard_Btn.C},
    .Fly = {btn = Keyboard_Btn.SPACE, double_tap = Double_Tap{}},
}

is_pressed_raw :: proc(btn: Btn) -> bool {
    switch b in btn {
    case Keyboard_Btn:
        return rl.IsKeyPressed(b)
    case Mouse_Btn:
        return rl.IsMouseButtonPressed(b)
    }
    return false
}

is_pressed :: proc(action: Action) -> bool {
    input_data := bindings[action]
    if dt, ok := input_data.double_tap.?; ok {
        return dt.tapped_this_frame
    }
    return is_pressed_raw(input_data.btn)
}

is_down :: proc(action: Action) -> bool {
    input_data := bindings[action]
    switch b in input_data.btn {
    case Keyboard_Btn:
        return rl.IsKeyDown(b)
    case Mouse_Btn:
        return rl.IsMouseButtonDown(b)
    }
    return false
}

update_input :: proc() {
    now := rl.GetTime()
    DOUBLE_TAP_DELAY :: 0.3
    
    for &input_data, action in bindings {
        dt, ok := input_data.double_tap.?
        if !ok do continue
        
        dt.tapped_this_frame = false
        if is_pressed_raw(input_data.btn) {
            if now - dt.last_pressed_at <= DOUBLE_TAP_DELAY {
                dt.tapped_this_frame = true
                dt.last_pressed_at = 0
            } else {
                dt.last_pressed_at = now
            }
        }
        input_data.double_tap = dt
    }
}