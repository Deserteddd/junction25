package aigame

import rl "vendor:raylib"
import stbi "vendor:stb/image"
import "core:slice"
import "core:strings"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:sort"

dist :: linalg.distance
sin :: math.sin
cos :: math.cos
abs :: math.abs

vec2 :: [2]f32

Rect :: rl.Rectangle

GameState :: struct {
    player:         Player,
    sprite_sheets:  [dynamic]SpriteSheet,
    projectiles:    [dynamic]Projectile,
    enemies:        [dynamic]Enemy,
}

Enemy :: struct {
    position:  vec2,
    radius:    f32,
    speed:     f32,
    direction: Direction,
    sheet:     ^SpriteSheet
}

Direction :: enum u8 {
    DOWN  = 0,
    RIGHT = 1,
    UP    = 2,
    LEFT  = 3,
}

Projectile :: struct {
    position:   vec2,
    radius:     f32,
    speed:      f32,
    direction:  f32,
    damage:     f32,
    sheet:      ^SpriteSheet
}

Player :: struct {
    sprite:         rl.Texture2D,
    attack_speed:   f32,
    attack_radius:  f32
}

SpriteSheet :: struct {
    texture: rl.Texture2D,
    rects:   []Rect
}

Globals :: struct {
    frame:          u64,
    t_since_attack: f32,
    win_size:       vec2,
    current_wave:   i32
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
                if non_empty_streak > 10 {
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
                if non_empty_streak > 10 {
                    segment: [2]i32 = {start, col}
                    fmt.println("Yess")
                    append(&vertical_segments, segment)
                }
                non_empty_streak = 0
            }
        }
    }
    fmt.println(horizontal_segments)
    fmt.println(vertical_segments)
    rects: [dynamic]Rect
    for vertical, i in vertical_segments {
        for horizontal, j in horizontal_segments {
            rect := Rect {
                f32(vertical.x),
                f32(horizontal.x), 
                f32(vertical.y - vertical.x),
                f32(horizontal.y - horizontal.x),
            }
            append(&rects, rect)
        }
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
    assert(size != 0)
    assert(pixel_data != nil)
    pixels = slice.bytes_from_ptr(pixel_data, int(size.x * size.y * 4))
    assert(pixels != nil)
    return
}

toggle_fullscreen :: proc() {
    rl.ToggleBorderlessWindowed()
    screen_h := f32(rl.GetScreenHeight())
    screen_w := f32(rl.GetScreenWidth())
    g.win_size = {screen_w, screen_h}
}

init :: proc() -> GameState {
    state: GameState
    using state
    // Init player
    {
        using player
        anton := rl.LoadTexture("assets/pixelanton.jpg")
        attack_speed = 10
        sprite = anton
        attack_radius = 350
    }
    append(&state.sprite_sheets, load_sprite_sheet("assets/gpt_test1.png"))
    append(&state.sprite_sheets, load_sprite_sheet("assets/zimbo.png"))
    return state
}

main :: proc() {
    rl.InitWindow(1280, 720, "Odin + raylib window")
    g.win_size = {1280, 720}
    defer rl.CloseWindow()

    state := init()

    rl.SetTargetFPS(60)
    rl.SetTraceLogLevel(.WARNING)
    for !rl.WindowShouldClose() {
        defer g.frame += 1
        if !update(&state) do break

        rl.BeginDrawing()
        rl.ClearBackground(20)
        draw(state)
        rl.EndDrawing()
    }
}

update :: proc(state: ^GameState) -> bool {
    if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyDown(.C) do return false
    if rl.IsKeyPressed(.F) do toggle_fullscreen()
    dt := rl.GetFrameTime()

    // if rl.IsKeyDown(.W) do g.player_pos.y -= dt * 100
    // if rl.IsKeyDown(.S) do g.player_pos.y += dt * 100
    // if rl.IsKeyDown(.A) do g.player_pos.x -= dt * 100
    // if rl.IsKeyDown(.D) do g.player_pos.x += dt * 100

    if rl.GetRandomValue(1, 10) == 10 do spawn_enemy(state)
    g.t_since_attack += dt
    if g.t_since_attack >= 1/state.player.attack_speed {
        g.t_since_attack = 0
        shoot(state)
    }
    for &p, i in state.projectiles {
        if p.position.x > g.win_size.x || p.position.x < 0 || p.position.y > g.win_size.y || p.position.y < 0 {
            unordered_remove(&state.projectiles, i)
        }

        dx := cos(p.direction);
        dy := sin(p.direction);

        p.position.x += dx * p.speed * dt;
        p.position.y -= dy * p.speed * dt;
    }
    center := g.win_size/2
    for &e in state.enemies {
        dir := center - e.position
        len := math.sqrt(dir.x*dir.x + dir.y*dir.y);
        if len > 0 {
            dir /= len;
        }
        e.position += dir * e.speed * dt;
    }
    for e, i in state.enemies {
        for p, j in state.projectiles {
            if circle_intersect(e.position, e.radius, p.position, p.radius) {
                unordered_remove(&state.enemies, i)
                unordered_remove(&state.projectiles, j)
                break
            }
        }
    }
    return true
}

circle_intersect :: proc(p1: vec2, r1: f32, p2: vec2, r2: f32) -> bool {
    return dist(p1, p2) < (r1+r2)*0.5
}

spawn_enemy :: proc(state: ^GameState) {
    margin   := f32(32) // Distance outside screen bounds
    side := rl.GetRandomValue(0, 3) // 0=left, 1=right, 2=top, 3=bottom
    enemy_pos: vec2
    enemy: Enemy
    enemy.speed = 100
    enemy.radius = 32
    enemy.sheet = &state.sprite_sheets[1]
    switch side {
    case 0: // Left
        enemy.position = {
            -margin,
            f32(rl.GetRandomValue(0, i32(g.win_size.y))),
        }
        enemy.direction = .RIGHT
    case 1: // Right
        enemy.position = {
            g.win_size.x + margin,
            f32(rl.GetRandomValue(0, i32(g.win_size.y))),
        }
        enemy.direction = .LEFT
    case 2: // Top
        enemy.position = {
            f32(rl.GetRandomValue(0, i32(g.win_size.x))),
            -margin,
        }
        enemy.direction = .DOWN
    case 3: // Bottom
        enemy.position = {
            f32(rl.GetRandomValue(0, i32(g.win_size.x))),
            g.win_size.y + margin,
        }
        enemy.direction = .UP
    }



    append(&state.enemies, enemy);
}

dir_to_closest_enemy :: proc(state: ^GameState) -> (shoot: bool, dir: f32) {

    slice.sort_by(state.enemies[:], 
        proc(e1, e2: Enemy) -> bool {
            centre := g.win_size/2
            return dist(e1.position, centre) < dist(e2.position, centre)
        }
    )

    centre := g.win_size/2
    if len(state.projectiles) >= len(state.enemies) {
        return false, 0
    }
    target := state.enemies[len(state.projectiles)]
    if dist(target.position, centre) > state.player.attack_radius do return false, 0
    dir_vec := vec2 {
        target.position.x - centre.x,
        centre.y - target.position.y
    }
    dir = math.atan2(dir_vec.y, dir_vec.x);

    return true, dir
}

shoot :: proc(state: ^GameState) {
    origin := g.win_size/2;
    shoot, dir := dir_to_closest_enemy(state)
    if !shoot {
        return
    } 
    sheet := &state.sprite_sheets[0]
    max_size: f32
    for frame in sheet.rects {
        size := math.min(frame.height, frame.width)
        if size > max_size do max_size = size
    }
    projectile: Projectile = {
        position    = g.win_size/2,
        radius      = max_size/8,
        speed       = 500,
        direction   = dir,
        damage      = 1,
        sheet       = sheet
    }
    append(&state.projectiles, projectile)
}

draw :: proc(state: GameState) {

    rl.DrawCircleLinesV(g.win_size/2, state.player.attack_radius, rl.BLUE)

    for p in state.projectiles {
        frame := g.frame%u64(len(p.sheet.rects))
        dst_rect := Rect {
            p.position.x, 
            p.position.y, 
            p.sheet.rects[frame].width/4, 
            p.sheet.rects[frame].height/4
        }
        rl.DrawTexturePro(
            p.sheet.texture,
            p.sheet.rects[frame],
            dst_rect,
            {dst_rect.width/2, dst_rect.height/2},
            -math.to_degrees(p.direction)+180,
            255
        )
    }
    for e in state.enemies {
        frame := u8(e.direction) + 4*u8((g.frame/10)%4)
        dst_rect := Rect {
            e.position.x, 
            e.position.y, 
            e.sheet.rects[frame].width/2, 
            e.sheet.rects[frame].height/2
        }
        rl.DrawTexturePro(
            e.sheet.texture,
            e.sheet.rects[frame],
            dst_rect,
            {dst_rect.width/2, dst_rect.height/2},
            0,
            255
        )
    }
    // Player
    {
        player_sprite := state.player.sprite
        scale: f32 = 0.1
        centre := g.win_size/2
        rl.DrawTextureEx(
            player_sprite, 
            {centre.x-f32(player_sprite.width)*scale/2, centre.y-f32(player_sprite.height)*scale/2},
            0,
            scale,
            255
        )
    }

    rl.DrawFPS(10, 10)
}