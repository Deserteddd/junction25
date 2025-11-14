package aigame

import rl "vendor:raylib"
import stb ""
import "core:fmt"
import "core:mem"

vec2 :: [2]f32

GameState :: struct {
    player: Player,
    sprite_sheet: SpriteSheet
}

Player :: struct {
    position: vec2,
    speed: f32,
    sprite: rl.Texture2D
}

SpriteSheet :: struct {
    texture: rl.Texture2D,
    rects: []rl.Rectangle
}

load_sprite_sheet :: proc(path: cstring) -> SpriteSheet {
    sheet: SpriteSheet
    using sheet

    img := rl.LoadImage(path)
    assert(img.format == .UNCOMPRESSED_R8G8B8A8)

    bytes := mem.byte_slice(img.data, img.height*img.width*4)
    for i: i32; i < img.height*img.width; i += 4 {
        pixel: [4]byte = {bytes[i], bytes[i+1], bytes[i+2], bytes[i+3]}
        if pixel.a != 0 do fmt.println(pixel)
    }

    return sheet
}

load_pixels :: proc(path: string) -> (pixels: []byte, size: [2]i32) {
    path_cstr := strings.clone_to_cstring(path, context.temp_allocator);
    pixel_data := stbi.load(path_cstr, &size.x, &size.y, nil, 4)
    assert(pixel_data != nil)
    pixels = slice.bytes_from_ptr(pixel_data, int(size.x * size.y * 4))
    assert(pixels != nil)
    return
}

init :: proc() -> GameState {
    state: GameState
    using state
    // Init player
    {
        using player
        anton := rl.LoadTexture("assets/pixelanton.jpg")
        player.speed = 5
        player.sprite = anton
    }
    
    sprite_sheet = load_sprite_sheet("assets/gpt_test1.png")
    return state
}

main :: proc() {
    rl.InitWindow(1280, 720, "Odin + raylib window")
    defer rl.CloseWindow()

    state := init()

    rl.SetTargetFPS(60)
    rl.SetTraceLogLevel(.WARNING)
    for !rl.WindowShouldClose() {
        
        if !update(&state) do break
        draw(state)
    }
}

update :: proc(state: ^GameState) -> bool {
    if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyDown(.C) do return false
    if rl.IsKeyDown(.F) do rl.ToggleBorderlessWindowed()
    {
        using state.player
        if rl.IsKeyDown(.W) do position.y -= speed
        if rl.IsKeyDown(.A) do position.x -= speed
        if rl.IsKeyDown(.S) do position.y += speed
        if rl.IsKeyDown(.D) do position.x += speed
    }
    return true
}

draw :: proc(state: GameState) {
    rl.BeginDrawing()
    rl.ClearBackground(20)
    win_x := rl.GetScreenWidth()
    win_y := rl.GetScreenHeight()

    // Draw player
    rl.DrawTextureEx(state.player.sprite, state.player.position, 0, 0.25, 255)
    
    rl.EndDrawing()
}