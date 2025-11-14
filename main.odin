package aigame

import rl "vendor:raylib"
import stbi "vendor:stb/image"
import "core:slice"
import "core:strings"
import "core:fmt"

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

Globals :: struct {
    frame: u64
}

g: Globals

load_sprite_sheet :: proc(path: string) -> SpriteSheet {
    pixels, size := load_pixels(path)
    defer stbi.image_free(raw_data(pixels))
    width  := size.x
    height := size.y

    horizontal_segments,
    vertical_segments: [dynamic][2]i32
    defer delete(horizontal_segments)
    defer delete(vertical_segments)
    {
        non_empty_streak: i32
        start: i32
        for row: i32 = 0; row < height; row += 1 {
            row_is_empty := true

            row_start := row * width * 4

            for col: i32 = 0; col < width; col += 1 {
                alpha := pixels[row_start + col*4 + 3]

                if alpha > 2 {
                    row_is_empty = false
                    break
                }
            }

            if !row_is_empty {
                if non_empty_streak == 0 do start = row
                non_empty_streak += 1
            } else {
                if non_empty_streak > height/8 {
                    segment: [2]i32 = {start, row}
                    append(&horizontal_segments, segment)
                }
                non_empty_streak = 0
            }
        }
    }
    {
        non_empty_streak: i32
        start: i32

        for col: i32 = 0; col < width; col += 1 {
            col_is_empty := true

            for row: i32 = 0; row < height; row += 1 {
                pixel_index := row * width * 4 + col * 4
                alpha := pixels[pixel_index + 3]

                if alpha > 2 {
                    col_is_empty = false
                    break
                }
            }

            if !col_is_empty {
                if non_empty_streak == 0 do start = col
                non_empty_streak += 1
            } else {
                if non_empty_streak > width/8 {
                    segment: [2]i32 = {start, col}
                    append(&vertical_segments, segment)
                }
                non_empty_streak = 0
            }
        }
    }
    rects: [dynamic]rl.Rectangle
    for vertical, i in vertical_segments {
        for horizontal, j in horizontal_segments {
            rect := rl.Rectangle {
                f32(vertical.x),
                f32(horizontal.x), 
                f32(vertical.y - vertical.x),
                f32(horizontal.y - horizontal.x),
            }
            append(&rects, rect)
        }
    }
    for rect in rects {
        fmt.println(rect)

    }
    rl_img: rl.Image = {
        data = raw_data(pixels),
        width = size.x,
        height = size.y,
        mipmaps = 1,
        format = .UNCOMPRESSED_R8G8B8A8
    }

    sheet: SpriteSheet
    sheet.texture = rl.LoadTextureFromImage(rl_img)
    sheet.rects = rects[:]
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
        defer g.frame += 1
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
    // rl.DrawTextureEx(state.player.sprite, state.player.position, 0, 0.25, 255)

    sprite_count := u64(len(state.sprite_sheet.rects))
    rl.DrawTextureRec(
        state.sprite_sheet.texture, 
        state.sprite_sheet.rects[g.frame/4%sprite_count],
        state.player.position,
        255
    )
    
    rl.EndDrawing()
}