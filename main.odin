package aigame

import rl "vendor:raylib"
import "core:slice"
import "core:strings"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:mem"

dist :: linalg.distance
sin :: math.sin
cos :: math.cos

vec2 :: [2]f32

Rect :: rl.Rectangle

// Each tile fills the entire game window
MAX_TILES :: 1  // Only 1 tile visible at a time
// TILE_SIZE will be set to window dimensions so each tile fills the screen

// Room types for castle-themed rooms
Room_Type :: enum {
    THRONE_ROOM,      // Royal throne room
    DUNGEON,          // Dark dungeon
    ARMORY,           // Weapon storage
    LIBRARY,          // Castle library
    BARRACKS,         // Soldier quarters
    KITCHEN,          // Castle kitchen
    CHAPEL,           // Castle chapel
}

NUM_ROOM_TYPES :: 7  // Number of different room types

ENEMIES_PER_WAVE :: 10  // Number of enemies per wave
WAVE_SPAWN_INTERVAL :: 0.5  // Seconds between enemy spawns in a wave
BOSS_HEALTH :: 100  // Base boss health (scales with room number)
BASE_ENEMY_HEALTH :: 1  // Base enemy health (scales with room number)
PLAYER_MAX_HP :: 100  // Player maximum health points
ENEMY_DAMAGE :: 10  // Damage enemies deal to player per hit
BOSS_PROJECTILE_DAMAGE :: 15  // Damage boss projectiles deal to player
INVULNERABLE_DURATION :: 1.0  // Seconds of invulnerability after being hit
BOSS_SHOOT_INTERVAL :: 2.0  // Seconds between boss shots
BASE_ENEMY_SPEED :: 50.0  // Base enemy speed (scales with room number)
BASE_BOSS_SPEED :: 30.0  // Base boss speed (scales with room number)
HEALTH_SCALE_PER_ROOM :: 1.5  // Health multiplier per room (50% increase - more aggressive)
SPEED_SCALE_PER_ROOM :: 1.2  // Speed multiplier per room (20% increase - more aggressive)
ENEMY_SEPARATION_DISTANCE :: 50.0  // Minimum distance enemies try to maintain from each other
ENEMY_SEPARATION_FORCE :: 200.0  // Force applied to separate overlapping enemies
WEAPON_DROP_CHANCE :: 0.3  // 30% chance for enemies to drop weapons
WEAPON_PICKUP_DISTANCE :: 40.0  // Distance player needs to be to pick up a weapon

GameState :: struct {
    player:           Player,
    sprite_sheets:    [dynamic]SpriteSheet,
    player_sprite_sheet: SpriteSheet,  // Sprite sheet for player (optional)
    enemy_sprite_sheet: SpriteSheet,  // Sprite sheet for enemies (optional)
    projectiles:      [dynamic]Projectile,
    enemy_projectiles: [dynamic]Projectile,  // Projectiles shot by enemies/bosses
    enemies:          [dynamic]Enemy,
    dropped_weapons:  [dynamic]DroppedWeapon,  // Weapons dropped by enemies
    active_sheet:     i32,
    board:            Board,
    room_textures:    [NUM_ROOM_TYPES]rl.Texture2D,  // Textures for each room type
    weapon_textures:  [5]rl.Texture2D,  // Textures for each weapon type (PISTOL, SHOTGUN, RIFLE, SNIPER, MACHINE_GUN)
    background_music: rl.Music,  // Background music
    music_enabled:    bool,      // Whether music is enabled
    is_game_over:     bool,      // True if player is dead
    is_start_screen:  bool,      // True if on start screen
    // Wave system
    enemies_in_wave:  i32,      // Total enemies that should spawn this wave
    enemies_spawned:  i32,       // Enemies spawned so far this wave
    enemies_killed:   i32,       // Enemies killed this wave
    wave_spawn_timer: f32,       // Timer for spawning enemies
    wave_complete:   bool,       // True when wave is complete
    room_number:      i32,       // Current room number
}

Enemy :: struct {
    position: vec2,
    radius:   f32,
    speed:    f32,
    is_boss:  bool,   // True if this is a boss enemy
    health:   i32,    // Health points (1 for regular, BOSS_HEALTH for bosses)
    max_health: i32,  // Maximum health (for HP bar)
    sprite_sheet: ^SpriteSheet,  // Sprite sheet for enemy animation (nil if using default circle)
    animation_frame: u64,  // Current animation frame
    shoot_timer: f32,  // Timer for boss shooting
}

Projectile :: struct {
    position:     vec2,
    radius:       f32,
    speed:        f32,
    direction:    f32,
    damage:       f32,
    sheet:        ^SpriteSheet
}

Weapon_Type :: enum {
    PISTOL,        // Fast, low damage, no spread
    SHOTGUN,       // Slow, high damage, wide spread
    RIFLE,         // Medium speed, medium damage, tight spread
    SNIPER,        // Very slow, very high damage, no spread
    MACHINE_GUN,   // Very fast, low damage, small spread
}

Weapon :: struct {
    weapon_type:  Weapon_Type,
    fire_rate:    f32,      // Shots per second
    spread:       f32,      // Spread angle in radians (0 = no spread)
    damage:       f32,      // Damage per projectile
    projectile_speed: f32,  // Speed of projectiles
    num_projectiles: i32,   // Number of projectiles per shot (for shotguns)
    name:         string,   // Weapon name for display
    texture:      rl.Texture2D,  // Texture for the weapon
}

DroppedWeapon :: struct {
    position:     vec2,
    weapon:       Weapon,
    pickup_timer: f32,  // Time since dropped (for visual effects)
}

Player :: struct {
    sprite:           rl.Texture2D,  // Fallback static texture
    sprite_sheet:     ^SpriteSheet,  // Sprite sheet for animation (nil if using static texture)
    animation_frame:  u64,  // Current animation frame
    attack_speed:     f32,  // Deprecated - use current_weapon.fire_rate instead
    position:         vec2,  // Player position in world space
    velocity:         vec2,  // Current velocity (for acceleration)
    speed:            f32,   // Maximum movement speed
    acceleration:     f32,   // Acceleration rate
    friction:         f32,   // Friction/drag coefficient
    max_hp:           i32,   // Maximum health points
    hp:               i32,   // Current health points
    invulnerable_time: f32,  // Time remaining of invulnerability after being hit
    current_weapon:   Weapon,  // Currently equipped weapon
    aim_direction:    f32,  // Direction player is aiming (in radians)
}

SpriteSheet :: struct {
    texture: rl.Texture2D,
    rects:   []Rect
}

Globals :: struct {
    frame:            u64,
    t_since_attack:   f32,
    win_size:         vec2,
    camera_offset:    vec2,  // Camera offset to follow player
}

g: Globals

load_sprite_sheet :: proc(path: string) -> SpriteSheet {
    path_cstr := strings.clone_to_cstring(path, context.temp_allocator)
    rl_img := rl.LoadImage(path_cstr)
    defer rl.UnloadImage(rl_img)
    width  := i32(rl_img.width)
    height := i32(rl_img.height)
    pixels := slice.bytes_from_ptr(rl_img.data, int(rl_img.width * rl_img.height * 4))

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
    for rect in rects {
        fmt.println(rect)

    }
    // LoadTextureFromImage copies the data, so we can safely unload the image
    sheet: SpriteSheet
    sheet.texture = rl.LoadTextureFromImage(rl_img)
    // Convert dynamic array to a persistent slice by cloning
    // We need to allocate new memory since the dynamic array will be freed
    if len(rects) > 0 {
        // Allocate slice with context allocator to ensure it persists
        allocated_rects := make([]Rect, len(rects), context.allocator)
        for i in 0..<len(rects) {
            allocated_rects[i] = rects[i]
        }
        sheet.rects = allocated_rects
    } else {
        sheet.rects = nil
    }
    return sheet
}


toggle_fullscreen :: proc() {
    rl.ToggleBorderlessWindowed()
    screen_h := f32(rl.GetScreenHeight())
    screen_w := f32(rl.GetScreenWidth())
    g.win_size = {screen_w, screen_h}
}

// Load a PNG texture for a room type
// Maps room types to PNG file paths in the assets folder
load_room_texture :: proc(room_type: Room_Type) -> rl.Texture2D {
    // Map room types to PNG file names
    // You can change these file names to match your actual PNG files
    room_texture_paths := [NUM_ROOM_TYPES]string{
        "assets/throne_room.png",   // THRONE_ROOM
        "assets/dungeon.png",        // DUNGEON
        "assets/armory.png",         // ARMORY
        "assets/library.png",        // LIBRARY
        "assets/barracks.png",       // BARRACKS
        "assets/kitchen.png",        // KITCHEN
        "assets/chapel.png",         // CHAPEL
    }
    
    path := room_texture_paths[int(room_type)]
    path_cstr := strings.clone_to_cstring(path, context.temp_allocator)
    
    // Try to load the texture
    texture := rl.LoadTexture(path_cstr)
    
    // If texture failed to load (ID 0), create a fallback colored texture
    if texture.id == 0 {
        fmt.printf("Warning: Could not load texture '%s', using fallback color\n", path)
        
        // Fallback: Create a simple colored texture
        width := 1280
        height := 720
        pixels := make([]u8, width * height * 4, context.temp_allocator)
        
        // Fallback colors for each room type
        fallback_colors := [NUM_ROOM_TYPES][3]u8{
            {180, 160, 140},  // THRONE_ROOM
            {40, 30, 35},     // DUNGEON
            {100, 80, 70},    // ARMORY
            {120, 100, 80},   // LIBRARY
            {90, 85, 75},     // BARRACKS
            {150, 120, 100},  // KITCHEN
            {140, 130, 120},  // CHAPEL
        }
        
        color := fallback_colors[int(room_type)]
        for y in 0..<height {
            for x in 0..<width {
                idx := (y * width + x) * 4
                pixels[idx + 0] = color[0]
                pixels[idx + 1] = color[1]
                pixels[idx + 2] = color[2]
                pixels[idx + 3] = 255
            }
        }
        
        img := rl.Image{
            data = raw_data(pixels),
            width = i32(width),
            height = i32(height),
            mipmaps = 1,
            format = .UNCOMPRESSED_R8G8B8A8,
        }
        
        texture = rl.LoadTextureFromImage(img)
    }
    
    return texture
}

init :: proc() -> GameState {
    state: GameState
    using state
    // Init player
    {
        using player
        anton := rl.LoadTexture("assets/pixelanton.jpg")
        player.attack_speed = 5
        player.sprite = anton
        player.position = {0, 0}  // Start at center of room
        player.velocity = {0, 0}  // Start with no velocity
        player.speed = 300.0  // Maximum movement speed
        player.acceleration = 950.0  // Acceleration rate
        player.friction = 12.0  // Friction coefficient
        player.max_hp = PLAYER_MAX_HP
        player.hp = PLAYER_MAX_HP
        player.invulnerable_time = 0.0
        // Weapon textures will be loaded later, use empty array for now (will be updated after textures load)
        // Create a temporary weapon that will be replaced after textures are loaded
        temp_weapon := Weapon{
            weapon_type = .PISTOL,
            fire_rate = 3.0,
            spread = 0.0,
            damage = 1.0,
            projectile_speed = 500.0,
            num_projectiles = 1,
            name = "Pistol",
            texture = {},  // Will be set after textures load
        }
        player.current_weapon = temp_weapon
        player.aim_direction = 0.0  // Start aiming right
        player.animation_frame = 0
        player.sprite_sheet = nil  // Will be set if sprite sheet is found
    }
    
    // Try to load player sprite sheet (try common names)
    player_sheet_paths := []string{"assets/player_sheet.png", "assets/player.png", "assets/player_sprite.png"}
    player_sheet_loaded := false
    for path in player_sheet_paths {
        path_cstr := strings.clone_to_cstring(path, context.temp_allocator)
        // Try to load the image to check if file exists
        test_img := rl.LoadImage(path_cstr)
        // Check if image loaded successfully (width and height > 0)
        if test_img.width > 0 && test_img.height > 0 {
            rl.UnloadImage(test_img)
            // Try to load as sprite sheet
            player_sheet := load_sprite_sheet(path)
            fmt.printf("Player sprite sheet '%s': found %d sprites\n", path, len(player_sheet.rects))
            if len(player_sheet.rects) > 0 {
                // Debug: print first frame info
                if len(player_sheet.rects) > 0 {
                    first_frame := player_sheet.rects[0]
                    fmt.printf("First frame: x=%.1f, y=%.1f, w=%.1f, h=%.1f\n", first_frame.x, first_frame.y, first_frame.width, first_frame.height)
                }
                // Store the sprite sheet separately (like enemy_sprite_sheet) to avoid pointer invalidation
                state.player_sprite_sheet = player_sheet
                state.player.sprite_sheet = &state.player_sprite_sheet
                player_sheet_loaded = true
                fmt.printf("Player sprite sheet loaded successfully from '%s' (texture ID: %d, %d frames)\n", path, player_sheet.texture.id, len(player_sheet.rects))
                break
            } else {
                // If no sprites detected, treat the entire image as a single sprite
                fmt.printf("No individual sprites detected in '%s', using entire image as single sprite\n", path)
                
                // Create a single rect covering the entire texture
                // Allocate with context.allocator to ensure it persists
                full_rect := Rect{0, 0, f32(player_sheet.texture.width), f32(player_sheet.texture.height)}
                single_rect := make([]Rect, 1, context.allocator)
                single_rect[0] = full_rect
                
                // Verify the texture is valid before updating
                if player_sheet.texture.id != 0 {
                    // Update the sprite sheet with the single rect
                    // Note: player_sheet.rects should already be nil from load_sprite_sheet
                    player_sheet.rects = single_rect
                    
                    // Store the sprite sheet (copy the struct, which includes the slice reference)
                    state.player_sprite_sheet = player_sheet
                    state.player.sprite_sheet = &state.player_sprite_sheet
                    player_sheet_loaded = true
                    fmt.printf("Player sprite sheet loaded as single sprite from '%s' (texture ID: %d, size: %dx%d, rects: %d)\n", 
                        path, player_sheet.texture.id, player_sheet.texture.width, player_sheet.texture.height, len(single_rect))
                    break
                } else {
                    // Texture invalid, unload and try next path
                    rl.UnloadTexture(player_sheet.texture)
                    delete(single_rect)  // Free the allocated slice
                    fmt.printf("Warning: Player sprite sheet texture invalid (ID: %d)\n", player_sheet.texture.id)
                }
            }
        } else {
            rl.UnloadImage(test_img)
        }
    }
    if !player_sheet_loaded {
        fmt.printf("No player sprite sheet found, using fallback texture\n")
    }
    append(&state.sprite_sheets, load_sprite_sheet("assets/gpt_test1.png"))
    
    // Try to load enemy sprite sheet (from GIF converted to sprite sheet or individual frames)
    // Try common names: enemy.png, enemy_sheet.png, enemies.png
    enemy_sheet_paths := []string{"assets/enemy.png", "assets/enemy_sheet.png", "assets/enemies.png", "assets/enemy.gif"}
    enemy_sheet_loaded := false
    for path in enemy_sheet_paths {
        path_cstr := strings.clone_to_cstring(path, context.temp_allocator)
        // Check if file exists by trying to load it
        test_img := rl.LoadImage(path_cstr)
        if test_img.data != nil {
            rl.UnloadImage(test_img)
            state.enemy_sprite_sheet = load_sprite_sheet(path)
            if len(state.enemy_sprite_sheet.rects) > 0 {
                enemy_sheet_loaded = true
                break
            }
        }
    }
    
    // Initialize game states
    state.is_game_over = false
    state.is_start_screen = true
    state.music_enabled = true
    
    // Load room textures from PNG files for each room type
    for i in 0..<NUM_ROOM_TYPES {
        room_type := Room_Type(i)
        state.room_textures[i] = load_room_texture(room_type)
    }
    
    // Load weapon textures
    weapon_texture_paths := [5]string{
        "assets/pistol.png",      // PISTOL
        "assets/shotgun.png",     // SHOTGUN
        "assets/rifle.png",       // RIFLE
        "assets/sniper.png",      // SNIPER
        "assets/machine_gun.png", // MACHINE_GUN
    }
    
    for i in 0..<5 {
        path := weapon_texture_paths[i]
        path_cstr := strings.clone_to_cstring(path, context.temp_allocator)
        texture := rl.LoadTexture(path_cstr)
        
        // If texture failed to load, create a fallback colored texture
        if texture.id == 0 {
            // Create a simple colored rectangle as fallback
            img := rl.GenImageColor(32, 32, rl.GRAY)
            texture = rl.LoadTextureFromImage(img)
            rl.UnloadImage(img)
        }
        
        state.weapon_textures[i] = texture
    }
    
    // Update player's starting weapon with proper texture
    state.player.current_weapon = create_weapon(.PISTOL, state.weapon_textures)
    state.player.aim_direction = 0.0  // Initialize aim direction
    
    // Load background music (tries .mp3, .ogg, then .wav)
    music_path := "assets/background_music.mp3"  // Try .mp3 first
    music_path_cstr := strings.clone_to_cstring(music_path, context.temp_allocator)
    state.background_music = rl.LoadMusicStream(music_path_cstr)
    
    // If .mp3 doesn't exist, try .ogg
    if state.background_music.frameCount == 0 {
        music_path_ogg := "assets/background_music.ogg"
        music_path_ogg_cstr := strings.clone_to_cstring(music_path_ogg, context.temp_allocator)
        state.background_music = rl.LoadMusicStream(music_path_ogg_cstr)
    }
    
    // If .ogg doesn't exist, try .wav
    if state.background_music.frameCount == 0 {
        music_path_wav := "assets/background_music.wav"
        music_path_wav_cstr := strings.clone_to_cstring(music_path_wav, context.temp_allocator)
        state.background_music = rl.LoadMusicStream(music_path_wav_cstr)
    }
    
    // Set music volume (but don't play yet - wait for start screen)
    if state.background_music.frameCount > 0 {
        rl.SetMusicVolume(state.background_music, 0.5)  // 50% volume
        // Music will start when player presses play on start screen
    }
    
    // Initialize wave system
    state.room_number = 1
    state.enemies_spawned = 0
    state.enemies_killed = 0
    state.wave_spawn_timer = 0.0
    state.wave_complete = false
    
    // --- Room Generation Initialization ---
    state.board = generate_room(MAX_TILES)
    
    // Start first wave (will check if it's a throne room)
    start_wave(&state)
    
    return state
}

start_wave :: proc(state: ^GameState) {
    // Clear any remaining enemies and projectiles
    resize(&state.enemies, 0)
    resize(&state.projectiles, 0)
    resize(&state.enemy_projectiles, 0)
    
    // Reset wave counters
    state.enemies_spawned = 0
    state.enemies_killed = 0
    state.wave_spawn_timer = 0.0
    state.wave_complete = false
    
    // Check if current room is a throne room (boss room)
    is_throne_room := state.board.room_type == 0  // THRONE_ROOM is enum value 0
    
    // Calculate enemies for this wave
    if is_throne_room {
        // Throne rooms only spawn 1 boss
        state.enemies_in_wave = 1
    } else {
        // Regular rooms scale with room number
        state.enemies_in_wave = ENEMIES_PER_WAVE + (state.room_number - 1) * 5
    }
}

start_next_room :: proc(state: ^GameState) {
    state.room_number += 1
    // Reset player position to center when entering new room
    state.player.position = {0, 0}
    // Clear dropped weapons when entering new room
    resize(&state.dropped_weapons, 0)
    // Use room number to get different room types (cycles through all types)
    state.board = generate_room(MAX_TILES + state.room_number)
    start_wave(state)
}

main :: proc() {
    rl.InitWindow(1280, 720, "Odin + raylib window")
    g.win_size = {1280, 720}
    defer rl.CloseWindow()
    
    // Initialize audio device
    rl.InitAudioDevice()
    defer rl.CloseAudioDevice()

    state := init()
    defer rl.UnloadMusicStream(state.background_music)

    rl.SetTargetFPS(60)
    rl.SetTraceLogLevel(.WARNING)
    for !rl.WindowShouldClose() {
        defer g.frame += 1
        if !update(&state) do break
        
        // Update music stream (must be called every frame)
        // Music streams loop automatically in raylib
        if state.background_music.frameCount > 0 && state.music_enabled {
            rl.UpdateMusicStream(state.background_music)
            // Restart music if it stopped (shouldn't happen with looping, but just in case)
            if !rl.IsMusicStreamPlaying(state.background_music) {
                rl.PlayMusicStream(state.background_music)
            }
        }

        rl.BeginDrawing()
        rl.ClearBackground(20)
        // Only draw game board if not on start screen
        if !state.is_start_screen {
            draw_board(state.board, state.room_textures) // <-- DRAW BOARD FIRST
        }
        draw(state)
        rl.EndDrawing()
    }
}

// Calculate room bounds and camera offset to center room on screen
// Since each tile fills the entire window, we only need to center the single tile
calculate_room_camera :: proc(board: Board) -> (camera_offset: vec2, min_x: i32, max_x: i32, min_y: i32, max_y: i32) {
    // Find the bounds of the room
    min_x_val, max_x_val, min_y_val, max_y_val: i32 = 0, 0, 0, 0
    first := true
    
    for pos, cell in board.cells {
        if !cell.is_occupied {
            continue
        }
        if first {
            min_x_val = pos.x
            max_x_val = pos.x
            min_y_val = pos.y
            max_y_val = pos.y
            first = false
        } else {
            if pos.x < min_x_val do min_x_val = pos.x
            if pos.x > max_x_val do max_x_val = pos.x
            if pos.y < min_y_val do min_y_val = pos.y
            if pos.y > max_y_val do max_y_val = pos.y
        }
    }
    
    // For single tile filling screen, just center it at (0,0)
    // Tile size will be window size, so offset is 0
    camera_offset = {0, 0}
    
    min_x = min_x_val
    max_x = max_x_val
    min_y = min_y_val
    max_y = max_y_val
    
    return
}

// --- NEW DRAW BOARD PROCEDURE ---
// Draws the current state of the board using raylib functions
// Room background scrolls with camera
draw_board :: proc(board: Board, room_textures: [NUM_ROOM_TYPES]rl.Texture2D) {
    // Get the room type and draw the appropriate texture
    room_type_idx := board.room_type
    if room_type_idx < 0 || room_type_idx >= NUM_ROOM_TYPES {
        room_type_idx = 0  // Default to first room type if invalid
    }
    
    room_texture := room_textures[room_type_idx]
    
    // Draw the room texture with camera offset (so it scrolls with player)
    // The texture is tiled/repeated to fill the visible area
    tile_width := f32(room_texture.width)
    tile_height := f32(room_texture.height)
    
    // Calculate how many tiles we need to cover the screen + some padding
    tiles_x := i32(g.win_size.x / tile_width) + 2
    tiles_y := i32(g.win_size.y / tile_height) + 2
    
    // Draw tiled background
    start_x := i32(g.camera_offset.x / tile_width) - 1
    start_y := i32(g.camera_offset.y / tile_height) - 1
    
    for ty in 0..<tiles_y {
        for tx in 0..<tiles_x {
            world_x := f32(start_x + tx) * tile_width
            world_y := f32(start_y + ty) * tile_height
            screen_x := world_x + g.camera_offset.x
            screen_y := world_y + g.camera_offset.y
            
            // Only draw if visible on screen
            if screen_x + tile_width > 0 && screen_x < g.win_size.x &&
               screen_y + tile_height > 0 && screen_y < g.win_size.y {
                rl.DrawTexturePro(
                    room_texture,
                    {0, 0, tile_width, tile_height},
                    {screen_x, screen_y, tile_width, tile_height},
                    {0, 0},
                    0,
                    rl.WHITE
                )
            }
        }
    }
    
    // Draw room type name
    room_type_names := [NUM_ROOM_TYPES]string{
        "Throne Room",
        "Dungeon",
        "Armory",
        "Library",
        "Barracks",
        "Kitchen",
        "Chapel",
    }
    
    if room_type_idx < len(room_type_names) {
        room_name := room_type_names[room_type_idx]
        name_cstr := strings.clone_to_cstring(room_name, context.temp_allocator)
        font_size := i32(g.win_size.y / 25)  // Scale font with window size
        rl.DrawText(
            name_cstr,
            20, 
            20, 
            font_size, 
            rl.WHITE
        );
    }
}
// --- END NEW DRAW BOARD PROCEDURE ---


update :: proc(state: ^GameState) -> bool {
    if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyDown(.C) do return false
    if rl.IsKeyPressed(.F) do toggle_fullscreen()
    
    // Handle start screen
    if state.is_start_screen {
        // Toggle music with M key
        if rl.IsKeyPressed(.M) {
            state.music_enabled = !state.music_enabled
            if state.music_enabled {
                if state.background_music.frameCount > 0 {
                    rl.PlayMusicStream(state.background_music)
                }
            } else {
                if state.background_music.frameCount > 0 {
                    rl.StopMusicStream(state.background_music)
                }
            }
        }
        
        // Start game with Enter or Space
        if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.SPACE) {
            state.is_start_screen = false
            // Start music if enabled
            if state.music_enabled && state.background_music.frameCount > 0 {
                rl.PlayMusicStream(state.background_music)
            }
        }
        return true
    }
    
    // Restart game if dead and R is pressed
    if state.is_game_over && rl.IsKeyPressed(.R) {
        new_state := init()
        state^ = new_state
        return true
    }
    
    // Toggle music during gameplay
    if rl.IsKeyPressed(.M) {
        state.music_enabled = !state.music_enabled
        if state.music_enabled {
            if state.background_music.frameCount > 0 {
                rl.PlayMusicStream(state.background_music)
            }
        } else {
            if state.background_music.frameCount > 0 {
                rl.StopMusicStream(state.background_music)
            }
        }
    }
    
    // Don't update game logic if game over
    if state.is_game_over {
        return true
    }
    
    dt := rl.GetFrameTime()
    
    // Player movement with acceleration (WASD or Arrow keys)
    move_dir := vec2{0, 0}
    if rl.IsKeyDown(.W) || rl.IsKeyDown(.UP) do move_dir.y -= 1
    if rl.IsKeyDown(.S) || rl.IsKeyDown(.DOWN) do move_dir.y += 1
    if rl.IsKeyDown(.A) || rl.IsKeyDown(.LEFT) do move_dir.x -= 1
    if rl.IsKeyDown(.D) || rl.IsKeyDown(.RIGHT) do move_dir.x += 1
    
    // Normalize movement direction
    move_len := math.sqrt(move_dir.x*move_dir.x + move_dir.y*move_dir.y)
    if move_len > 0 {
        move_dir /= move_len
    }
    
    // Update invulnerability timer
    if state.player.invulnerable_time > 0 {
        state.player.invulnerable_time -= dt
        if state.player.invulnerable_time < 0 {
            state.player.invulnerable_time = 0
        }
    }
    
    // Update player velocity with acceleration (only if not dead)
    if !state.is_game_over {
        // Apply acceleration in movement direction
        target_velocity := move_dir * state.player.speed
        velocity_diff := target_velocity - state.player.velocity
        
        // Accelerate towards target velocity
        accel_vec := velocity_diff
        accel_len := math.sqrt(accel_vec.x*accel_vec.x + accel_vec.y*accel_vec.y)
        if accel_len > 0 {
            accel_vec /= accel_len
            accel_magnitude := math.min(state.player.acceleration * dt, accel_len)
            state.player.velocity += accel_vec * accel_magnitude
        }
        
        // Apply friction when not moving
        if move_len == 0 {
            friction_force := state.player.friction * dt
            vel_len := math.sqrt(state.player.velocity.x*state.player.velocity.x + state.player.velocity.y*state.player.velocity.y)
            if vel_len > 0 {
                friction_vec := state.player.velocity / vel_len
                friction_magnitude := math.min(friction_force, vel_len)
                state.player.velocity -= friction_vec * friction_magnitude
            }
        }
        
        // Update position based on velocity
        state.player.position += state.player.velocity * dt
        
        // Update player animation frame (only if moving)
        move_len := math.sqrt(state.player.velocity.x*state.player.velocity.x + state.player.velocity.y*state.player.velocity.y)
        if move_len > 10.0 {  // Only animate when moving (threshold to avoid jitter)
            state.player.animation_frame += 1
        }
    }
    
    // Update camera to follow player (center player on screen)
    g.camera_offset = g.win_size / 2.0 - state.player.position
    
    // Wave spawning logic
    if !state.wave_complete && state.enemies_spawned < state.enemies_in_wave {
        state.wave_spawn_timer += dt
        if state.wave_spawn_timer >= WAVE_SPAWN_INTERVAL {
            state.wave_spawn_timer = 0.0
            spawn_enemy(state)
            state.enemies_spawned += 1
        }
    }
    
    // Check if wave is complete (all enemies spawned and killed)
    if !state.wave_complete && state.enemies_spawned >= state.enemies_in_wave && len(state.enemies) == 0 {
        state.wave_complete = true
        // Automatically transition to next room after a short delay
        // (You can press a key to transition immediately if desired)
    }
    
    // Manual room transition (press N for next room when wave is complete)
    if state.wave_complete && rl.IsKeyPressed(.N) {
        start_next_room(state)
    }
    
    // Update weapon pickup timers and check for pickups
    for &dw, i in state.dropped_weapons {
        dw.pickup_timer += dt
        
        // Check if player is close enough to pick up
        distance_to_weapon := dist(state.player.position, dw.position)
        if distance_to_weapon < WEAPON_PICKUP_DISTANCE {
            // Player picks up weapon
            state.player.current_weapon = dw.weapon
            unordered_remove(&state.dropped_weapons, i)
            break  // Only pick up one weapon per frame
        }
    }
    
    // Shooting based on weapon fire rate
    g.t_since_attack += dt
    weapon_fire_rate := state.player.current_weapon.fire_rate
    if weapon_fire_rate > 0 && g.t_since_attack >= 1.0/weapon_fire_rate {
        g.t_since_attack = 0
        shoot(state)
    }
    for &p, i in state.projectiles {
        // Remove projectiles that are too far from player
        if dist(p.position, state.player.position) > 2000 do unordered_remove(&state.projectiles, i)
        dx := cos(p.direction);
        dy := sin(p.direction);

        p.position.x += dx * p.speed * dt;
        p.position.y -= dy * p.speed * dt;
    }
    // Enemies move toward player position (only if player is alive)
    if !state.is_game_over {
        // First pass: move enemies toward player
        for &e in state.enemies {
            dir := state.player.position - e.position
            dir_len := math.sqrt(dir.x*dir.x + dir.y*dir.y);
            if dir_len > 0 {
                dir /= dir_len;
            }
            e.position += dir * e.speed * dt;
            
            // Update enemy animation frame
            e.animation_frame += 1
            
            // Boss shooting logic
            if e.is_boss {
                e.shoot_timer += dt
                if e.shoot_timer >= BOSS_SHOOT_INTERVAL {
                    e.shoot_timer = 0.0
                    // Shoot projectile towards player
                    shoot_dir := state.player.position - e.position
                    shoot_len := math.sqrt(shoot_dir.x*shoot_dir.x + shoot_dir.y*shoot_dir.y)
                    if shoot_len > 0 {
                        shoot_dir /= shoot_len
                        shoot_angle := math.atan2(-shoot_dir.y, shoot_dir.x)
                        
                        // Create enemy projectile
                        if len(state.sprite_sheets) > 0 && state.active_sheet >= 0 && state.active_sheet < i32(len(state.sprite_sheets)) {
                            sheet := &state.sprite_sheets[state.active_sheet]
                            max_size: f32 = 32
                            if sheet.rects != nil && len(sheet.rects) > 0 {
                                for frame in sheet.rects {
                                    size := math.min(frame.height, frame.width)
                                    if size > max_size do max_size = size
                                }
                            }
                            
                            enemy_proj := Projectile{
                                position = e.position,
                                radius = max_size/8,
                                speed = 300.0,  // Slower than player projectiles
                                direction = shoot_angle,
                                damage = f32(BOSS_PROJECTILE_DAMAGE),
                                sheet = sheet,
                            }
                            append(&state.enemy_projectiles, enemy_proj)
                        }
                    }
                }
            }
        }
        
        // Second pass: separate enemies to prevent stacking
        for &e, i in state.enemies {
            separation_force := vec2{0, 0}
            separation_count := 0
            
            // Check all other enemies
            for other, j in state.enemies {
                if i == j do continue  // Skip self
                
                // Calculate distance to other enemy
                diff := e.position - other.position
                distance := math.sqrt(diff.x*diff.x + diff.y*diff.y)
                min_distance := e.radius + other.radius + ENEMY_SEPARATION_DISTANCE
                
                // If too close, apply separation force
                if distance > 0 && distance < min_distance {
                    // Normalize direction away from other enemy
                    if distance > 0 {
                        separation_dir := diff / distance
                        // Force strength based on how close they are (stronger when closer)
                        force_strength := ENEMY_SEPARATION_FORCE * (1.0 - distance / min_distance)
                        separation_force += separation_dir * force_strength
                        separation_count += 1
                    }
                }
            }
            
            // Apply separation force (average if multiple enemies nearby)
            if separation_count > 0 {
                separation_force /= f32(separation_count)
                e.position += separation_force * dt
            }
        }
    }
    
    // Update enemy projectiles
    for &p, i in state.enemy_projectiles {
        // Remove projectiles that are too far from player
        if dist(p.position, state.player.position) > 2000 do unordered_remove(&state.enemy_projectiles, i)
        dx := cos(p.direction);
        dy := sin(p.direction);
        p.position.x += dx * p.speed * dt;
        p.position.y -= dy * p.speed * dt;
    }
    
    // Enemy projectile-player collision
    if !state.is_game_over && state.player.invulnerable_time <= 0 {
        player_radius: f32 = 20.0
        for ep, i in state.enemy_projectiles {
            if circle_intersect(state.player.position, player_radius, ep.position, ep.radius) {
                // Player takes damage
                state.player.hp -= i32(ep.damage)
                state.player.invulnerable_time = INVULNERABLE_DURATION
                
                // Remove projectile
                unordered_remove(&state.enemy_projectiles, i)
                
                // Check if player is dead
                if state.player.hp <= 0 {
                    state.player.hp = 0
                    state.is_game_over = true
                }
                break
            }
        }
    }
    
    // Enemy-player collision detection
    if !state.is_game_over && state.player.invulnerable_time <= 0 {
        player_radius: f32 = 20.0  // Player collision radius
        for e, i in state.enemies {
            if circle_intersect(state.player.position, player_radius, e.position, e.radius) {
                // Player takes damage
                state.player.hp -= ENEMY_DAMAGE
                state.player.invulnerable_time = INVULNERABLE_DURATION
                
                // Check if player is dead
                if state.player.hp <= 0 {
                    state.player.hp = 0
                    state.is_game_over = true
                }
                break  // Only take damage from one enemy per frame
            }
        }
    }
    
    // Projectile-enemy collision
    for e, i in state.enemies {
        for p, j in state.projectiles {
            if circle_intersect(e.position, e.radius, p.position, p.radius) {
                // Remove projectile
                unordered_remove(&state.projectiles, j)
                
                // Deal damage to enemy (use projectile damage)
                state.enemies[i].health -= i32(p.damage)
                
                // If enemy is dead, remove it
                if state.enemies[i].health <= 0 {
                    enemy_pos := state.enemies[i].position
                    is_boss := state.enemies[i].is_boss
                    
                    // Chance to drop weapon
                    drop_chance := f32(rl.GetRandomValue(0, 100)) / 100.0
                    if drop_chance < WEAPON_DROP_CHANCE {
                        weapon_type := get_random_weapon_type(is_boss)
                        dropped_weapon := DroppedWeapon{
                            position = enemy_pos,
                            weapon = create_weapon(weapon_type, state.weapon_textures),
                            pickup_timer = 0.0,
                        }
                        append(&state.dropped_weapons, dropped_weapon)
                    }
                    
                    if state.enemies[i].is_boss {
                        // Track boss kill separately if needed
                    }
                    unordered_remove(&state.enemies, i)
                    state.enemies_killed += 1
                }
                break
            }
        }
    }
    return true
}

circle_intersect :: proc(p1: vec2, r1: f32, p2: vec2, r2: f32) -> bool {
    return dist(p1, p2) <(r1+r2)/2
}

// Create weapon based on type (requires weapon_textures array from GameState)
create_weapon :: proc(weapon_type: Weapon_Type, weapon_textures: [5]rl.Texture2D) -> Weapon {
    texture_idx: i32 = 0
    switch weapon_type {
        case .PISTOL:
            texture_idx = 0
            return Weapon{
                weapon_type = .PISTOL,
                fire_rate = 3.0,  // 3 shots per second
                spread = 0.0,  // No spread
                damage = 1.0,
                projectile_speed = 500.0,
                num_projectiles = 1,
                name = "Pistol",
                texture = weapon_textures[0],
            }
        case .SHOTGUN:
            texture_idx = 1
            return Weapon{
                weapon_type = .SHOTGUN,
                fire_rate = 0.8,  // Slow fire rate
                spread = 0.5,  // Wide spread (about 30 degrees)
                damage = 2.0,  // High damage per pellet
                projectile_speed = 400.0,
                num_projectiles = 5,  // 5 pellets per shot
                name = "Shotgun",
                texture = weapon_textures[1],
            }
        case .RIFLE:
            texture_idx = 2
            return Weapon{
                weapon_type = .RIFLE,
                fire_rate = 2.0,  // Medium fire rate
                spread = 0.1,  // Small spread
                damage = 1.5,
                projectile_speed = 600.0,
                num_projectiles = 1,
                name = "Rifle",
                texture = weapon_textures[2],
            }
        case .SNIPER:
            texture_idx = 3
            return Weapon{
                weapon_type = .SNIPER,
                fire_rate = 0.5,  // Very slow fire rate
                spread = 0.0,  // No spread
                damage = 5.0,  // Very high damage
                projectile_speed = 800.0,
                num_projectiles = 1,
                name = "Sniper",
                texture = weapon_textures[3],
            }
        case .MACHINE_GUN:
            texture_idx = 4
            return Weapon{
                weapon_type = .MACHINE_GUN,
                fire_rate = 8.0,  // Very fast fire rate
                spread = 0.15,  // Small spread
                damage = 0.8,  // Low damage
                projectile_speed = 550.0,
                num_projectiles = 1,
                name = "Machine Gun",
                texture = weapon_textures[4],
            }
    }
    // Default to pistol
    return create_weapon(.PISTOL, weapon_textures)
}

// Get random weapon type (weighted towards better weapons for bosses)
get_random_weapon_type :: proc(is_boss: bool) -> Weapon_Type {
    rand_val := f32(rl.GetRandomValue(0, 100)) / 100.0
    if is_boss {
        // Bosses drop better weapons
        if rand_val < 0.1 do return .PISTOL
        if rand_val < 0.4 do return .SHOTGUN
        if rand_val < 0.7 do return .RIFLE
        if rand_val < 0.9 do return .SNIPER
        return .MACHINE_GUN
    } else {
        // Regular enemies drop more common weapons
        if rand_val < 0.4 do return .PISTOL
        if rand_val < 0.6 do return .SHOTGUN
        if rand_val < 0.8 do return .RIFLE
        if rand_val < 0.9 do return .SNIPER
        return .MACHINE_GUN
    }
}

spawn_enemy :: proc(state: ^GameState) {
    // Spawn enemies at a distance from player, outside visible area
    spawn_distance: f32 = 800.0  // Distance from player to spawn
    angle: f32 = f32(rl.GetRandomValue(0, 359)) * f32(math.PI) / 180.0  // Random angle
    
    // Calculate spawn position relative to player
    cos_val := f32(math.cos(f64(angle)))
    sin_val := f32(math.sin(f64(angle)))
    enemy_pos := state.player.position + vec2{
        cos_val * spawn_distance,
        -sin_val * spawn_distance,
    }

    // Check if current room is a throne room (boss room)
    is_throne_room := state.board.room_type == 0  // THRONE_ROOM is enum value 0
    is_boss := is_throne_room  // Only spawn bosses in throne rooms

    // Calculate scaling factors based on room number (room 1 = no scaling, room 2 = 1x scaling, etc.)
    // Room 1 has no scaling, room 2 has 1 level of scaling, etc.
    room_scaling_level := f64(state.room_number - 1)
    
    // Calculate scaled health (exponential scaling)
    health_scale := f32(math.pow(f64(HEALTH_SCALE_PER_ROOM), room_scaling_level))
    base_health := is_boss ? f32(BOSS_HEALTH) : f32(BASE_ENEMY_HEALTH)
    scaled_health := i32(base_health * health_scale)
    
    // Calculate scaled speed (exponential scaling)
    speed_scale := f32(math.pow(f64(SPEED_SCALE_PER_ROOM), room_scaling_level))
    base_speed: f32 = is_boss ? BASE_BOSS_SPEED : BASE_ENEMY_SPEED
    scaled_speed: f32 = base_speed * speed_scale

    // Set sprite sheet pointer if available
    enemy_sheet: ^SpriteSheet = nil
    if len(state.enemy_sprite_sheet.rects) > 0 {
        enemy_sheet = &state.enemy_sprite_sheet
    }
    
    enemy := Enemy{
        speed     = scaled_speed,
        position  = enemy_pos,
        radius    = is_boss ? 64 : 32,  // Bosses are larger
        is_boss   = is_boss,
        health    = scaled_health,
        max_health = scaled_health,  // Store max health for HP bar
        sprite_sheet = enemy_sheet,
        animation_frame = 0,
        shoot_timer = 0.0,
    };

    append(&state.enemies, enemy);
}

dir_to_closest_enemy :: proc(state: ^GameState) -> f32 {
    player_pos := state.player.position
    min_dist: f32 = 1e12
    min_pos: vec2 = player_pos + {100, 0} // Default direction if no enemies
    for e in state.enemies {
        distance := dist(e.position, player_pos)
        if distance < min_dist {
            min_dist = distance
            min_pos = e.position
        }
    }
    dir := min_pos - player_pos
    dir_vec := vec2{
        min_pos.x - player_pos.x,
        player_pos.y - min_pos.y
    };
    direction := math.atan2(dir_vec.y, dir_vec.x);

    return direction
}

shoot :: proc(state: ^GameState) {
    origin := state.player.position;
    weapon := state.player.current_weapon

    base_direction := dir_to_closest_enemy(state)
    state.player.aim_direction = base_direction  // Store aim direction for weapon rendering
    
    if len(state.sprite_sheets) == 0 || state.active_sheet < 0 || state.active_sheet >= i32(len(state.sprite_sheets)) {
        return // Safety check
    }
    sheet := &state.sprite_sheets[state.active_sheet]
    max_size: f32
    if sheet.rects == nil || len(sheet.rects) == 0 {
        max_size = 32 // Default size if no rects
    } else {
        for frame in sheet.rects {
            size := math.min(frame.height, frame.width)
            if size > max_size do max_size = size
        }
    }
    
    // Fire multiple projectiles for shotguns
    for i in 0..<weapon.num_projectiles {
        // Calculate spread direction
        direction := base_direction
        if weapon.spread > 0 && weapon.num_projectiles > 1 {
            // Spread projectiles evenly across spread angle
            spread_offset := (f32(i) - f32(weapon.num_projectiles - 1) / 2.0) * (weapon.spread / f32(weapon.num_projectiles - 1))
            direction += spread_offset
        } else if weapon.spread > 0 {
            // Single projectile with random spread
            spread_offset := (f32(rl.GetRandomValue(0, 100)) / 100.0 - 0.5) * weapon.spread
            direction += spread_offset
        }
        
        projectile: Projectile = {
            position    = origin,
            radius      = max_size/8,
            speed       = weapon.projectile_speed,
            direction   = direction,
            damage      = weapon.damage,
            sheet       = sheet
        }
        append(&state.projectiles, projectile)
    }
}

draw :: proc(state: GameState) {
    // Note: draw_board is called before draw() in main loop to be the background layer.

    // Draw player projectiles with camera offset
    for p in state.projectiles {
        if p.sheet == nil || p.sheet.rects == nil || len(p.sheet.rects) == 0 {
            continue // Skip invalid projectiles
        }
        frame := g.frame/2%u64(len(p.sheet.rects))
        screen_pos := p.position + g.camera_offset
        dst_rect := Rect {
            screen_pos.x, 
            screen_pos.y, 
            p.sheet.rects[frame].width/8,  // Smaller projectiles
            p.sheet.rects[frame].height/8
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
    
    // Draw enemy projectiles with camera offset (red tint)
    for p in state.enemy_projectiles {
        if p.sheet == nil || p.sheet.rects == nil || len(p.sheet.rects) == 0 {
            continue // Skip invalid projectiles
        }
        frame := g.frame/2%u64(len(p.sheet.rects))
        screen_pos := p.position + g.camera_offset
        dst_rect := Rect {
            screen_pos.x, 
            screen_pos.y, 
            p.sheet.rects[frame].width/8,  // Smaller projectiles
            p.sheet.rects[frame].height/8
        }
        rl.DrawTexturePro(
            p.sheet.texture,
            p.sheet.rects[frame],
            dst_rect,
            {dst_rect.width/2, dst_rect.height/2},
            -math.to_degrees(p.direction)+180,
            rl.RED  // Red tint for enemy projectiles
        )
    }
    
    // Draw dropped weapons
    for dw in state.dropped_weapons {
        screen_pos := dw.position + g.camera_offset
        
        // Draw weapon texture with pulsing effect
        pulse := math.sin(dw.pickup_timer * 3.0) * 0.2 + 1.0  // Pulse between 0.8 and 1.2
        weapon_size: f32 = 40.0 * pulse
        
        // Draw weapon texture
        if dw.weapon.texture.id != 0 {
            src_rect := Rect{0, 0, f32(dw.weapon.texture.width), f32(dw.weapon.texture.height)}
            dst_rect := Rect{
                screen_pos.x - weapon_size/2,
                screen_pos.y - weapon_size/2,
                weapon_size,
                weapon_size,
            }
            rl.DrawTexturePro(
                dw.weapon.texture,
                src_rect,
                dst_rect,
                {weapon_size/2, weapon_size/2},
                0,  // No rotation for dropped weapons
                rl.WHITE
            )
        } else {
            // Fallback to colored circle if texture not loaded
            weapon_color := rl.GRAY
            rl.DrawCircleV(screen_pos, weapon_size/2, weapon_color)
        }
        
        // Draw weapon name above
        name_cstr := strings.clone_to_cstring(dw.weapon.name, context.temp_allocator)
        text_width := rl.MeasureText(name_cstr, 12)
        rl.DrawText(name_cstr, i32(screen_pos.x) - text_width/2, i32(screen_pos.y - weapon_size/2 - 20), 12, rl.WHITE)
    }
    
    // Draw enemies with camera offset (scaled down)
    for e in state.enemies {
        screen_pos := e.position + g.camera_offset
        
        // Try to draw enemy sprite if available
        if e.sprite_sheet != nil && e.sprite_sheet.rects != nil && len(e.sprite_sheet.rects) > 0 {
            // Use sprite sheet animation
            frame_idx := (e.animation_frame / 8) % u64(len(e.sprite_sheet.rects))  // Slow down animation
            frame := e.sprite_sheet.rects[frame_idx]
            enemy_size: f32 = e.radius * 2.0  // Scale based on radius
            dst_rect := Rect {
                screen_pos.x - enemy_size/2,
                screen_pos.y - enemy_size/2,
                enemy_size,
                enemy_size,
            }
            rl.DrawTexturePro(
                e.sprite_sheet.texture,
                frame,
                dst_rect,
                {enemy_size/2, enemy_size/2},
                0,
                rl.WHITE
            )
        } else {
            // Fallback to circle drawing
            if e.is_boss {
                // Draw outer ring for boss
                rl.DrawCircleV(screen_pos, e.radius, rl.PURPLE)
                rl.DrawCircleLines(i32(screen_pos.x), i32(screen_pos.y), e.radius, rl.MAGENTA)
            } else {
                rl.DrawCircleV(screen_pos, e.radius, rl.RED)
            }
        }
        
        // Draw boss HP bar above boss
        if e.is_boss {
            bar_width: f32 = e.radius * 2.0
            bar_height: f32 = 8.0
            bar_x := screen_pos.x - bar_width/2
            bar_y := screen_pos.y - e.radius - 20.0
            
            // Background (red)
            rl.DrawRectangle(i32(bar_x), i32(bar_y), i32(bar_width), i32(bar_height), rl.RED)
            
            // Health fill (green)
            hp_percent := f32(e.health) / f32(e.max_health)
            if hp_percent < 0 do hp_percent = 0
            fill_width := bar_width * hp_percent
            rl.DrawRectangle(i32(bar_x), i32(bar_y), i32(fill_width), i32(bar_height), rl.GREEN)
            
            // Border
            rl.DrawRectangleLines(i32(bar_x), i32(bar_y), i32(bar_width), i32(bar_height), rl.WHITE)
        }
    }

    // Player (centered on screen)
    {
        screen_center := g.win_size / 2.0
        
        // Flash player when invulnerable
        alpha: u8 = 255
        if state.player.invulnerable_time > 0 {
            // Flash effect: alternate between visible and semi-transparent
            flash_rate: f32 = 10.0  // Flashes per second
            flash_cycle := math.sin(state.player.invulnerable_time * flash_rate * 2 * math.PI)
            if flash_cycle > 0 {
                alpha = 128  // Semi-transparent
            } else {
                alpha = 255  // Fully visible
            }
        }
        
        // Draw player sprite sheet (must be loaded)
        // Use the same pattern as enemy drawing for safety
        // Access via state.player_sprite_sheet directly to avoid pointer issues
        if state.player_sprite_sheet.texture.id != 0 && 
           state.player_sprite_sheet.rects != nil && 
           len(state.player_sprite_sheet.rects) > 0 {
            // Use sprite sheet animation (same approach as enemies)
            frame_idx := (state.player.animation_frame / 8) % u64(len(state.player_sprite_sheet.rects))
            frame := state.player_sprite_sheet.rects[frame_idx]
            
            // Use a fixed size for player sprite (similar to enemy approach)
            player_size: f32 = 60.0  // Fixed size in pixels
            
            dst_rect := Rect {
                screen_center.x - player_size/2,
                screen_center.y - player_size/2,
                player_size,
                player_size,
            }
            
            // Draw the sprite using the frame (exactly like enemies do)
            rl.DrawTexturePro(
                state.player_sprite_sheet.texture,
                frame,
                dst_rect,
                {player_size/2, player_size/2},
                0,
                rl.WHITE
            )
        }
        
        // Draw weapon in player's hand, rotated to face aim direction
        if state.player.current_weapon.texture.id != 0 {
            weapon_size: f32 = 35.0  // Weapon size
            player_size: f32 = 60.0  // Same as player sprite size
            // Position weapon slightly offset from player center (in front of player)
            weapon_offset: f32 = player_size/2 + 5.0  // Offset from player center
            weapon_pos := screen_center + vec2{
                math.cos(state.player.aim_direction) * weapon_offset,
                -math.sin(state.player.aim_direction) * weapon_offset,  // Negative because screen Y is inverted
            }
            
            src_rect := Rect{0, 0, f32(state.player.current_weapon.texture.width), f32(state.player.current_weapon.texture.height)}
            dst_rect := Rect{
                weapon_pos.x - weapon_size/2,
                weapon_pos.y - weapon_size/2,
                weapon_size,
                weapon_size,
            }
            
            // Convert angle from radians to degrees, and adjust for screen coordinates
            weapon_angle := -math.to_degrees(state.player.aim_direction) + 90.0  // +90 to point right initially
            
            rl.DrawTexturePro(
                state.player.current_weapon.texture,
                src_rect,
                dst_rect,
                {weapon_size/2, weapon_size/2},
                weapon_angle,
                rl.WHITE
            )
        }
    }
    
    // Draw HP bar
    {
        bar_width: f32 = 300.0
        bar_height: f32 = 30.0
        bar_x: f32 = g.win_size.x - bar_width - 20.0
        bar_y: f32 = 20.0
        
        // Background (red)
        rl.DrawRectangle(i32(bar_x), i32(bar_y), i32(bar_width), i32(bar_height), rl.RED)
        
        // Health fill (green)
        hp_percent := f32(state.player.hp) / f32(state.player.max_hp)
        if hp_percent < 0 do hp_percent = 0
        fill_width := bar_width * hp_percent
        rl.DrawRectangle(i32(bar_x), i32(bar_y), i32(fill_width), i32(bar_height), rl.GREEN)
        
        // Border
        rl.DrawRectangleLines(i32(bar_x), i32(bar_y), i32(bar_width), i32(bar_height), rl.WHITE)
        
        // HP text
        hp_text := fmt.aprintf("HP: %d/%d", state.player.hp, state.player.max_hp)
        hp_text_cstr := strings.clone_to_cstring(hp_text, context.temp_allocator)
        text_x := i32(bar_x + bar_width/2 - 50)
        text_y := i32(bar_y + bar_height/2 - 10)
        rl.DrawText(hp_text_cstr, text_x, text_y, 20, rl.WHITE)
    }

    rl.DrawFPS(10, 10)
    
    // Draw current weapon info
    weapon_text := fmt.aprintf("Weapon: %s", state.player.current_weapon.name)
    weapon_cstr := strings.clone_to_cstring(weapon_text, context.temp_allocator)
    rl.DrawText(weapon_cstr, 10, 10, 20, rl.SKYBLUE)
    
    // Draw wave/room info
    room_text := fmt.aprintf("Room: %d", state.room_number)
    room_cstr := strings.clone_to_cstring(room_text, context.temp_allocator)
    rl.DrawText(room_cstr, 10, 40, 20, rl.WHITE)
    
    if !state.wave_complete {
        wave_text := fmt.aprintf("Wave: %d/%d enemies", state.enemies_killed, state.enemies_in_wave)
        wave_cstr := strings.clone_to_cstring(wave_text, context.temp_allocator)
        rl.DrawText(wave_cstr, 10, 70, 20, rl.WHITE)
        
        active_text := fmt.aprintf("Active: %d", len(state.enemies))
        active_cstr := strings.clone_to_cstring(active_text, context.temp_allocator)
        rl.DrawText(active_cstr, 10, 100, 20, rl.YELLOW)
    } else {
        complete_text := fmt.aprintf("Wave Complete! Press N for next room")
        complete_cstr := strings.clone_to_cstring(complete_text, context.temp_allocator)
        rl.DrawText(complete_cstr, 10, 70, 24, rl.GREEN)
    }
    
    // Draw start screen
    if state.is_start_screen {
        overlay_color := rl.Color{20, 20, 30, 255}  // Dark background
        rl.DrawRectangle(0, 0, i32(g.win_size.x), i32(g.win_size.y), overlay_color)
        
        title_text := "CASTLE DEFENDER"
        title_cstr := strings.clone_to_cstring(title_text, context.temp_allocator)
        title_width := rl.MeasureText(title_cstr, 80)
        rl.DrawText(title_cstr, i32(g.win_size.x/2 - f32(title_width)/2), i32(g.win_size.y/2 - 150), 80, rl.GOLD)
        
        play_text := "Press ENTER or SPACE to Play"
        play_cstr := strings.clone_to_cstring(play_text, context.temp_allocator)
        play_width := rl.MeasureText(play_cstr, 40)
        rl.DrawText(play_cstr, i32(g.win_size.x/2 - f32(play_width)/2), i32(g.win_size.y/2 - 20), 40, rl.WHITE)
        
        music_text := fmt.aprintf("Music: %s (Press M to toggle)", state.music_enabled ? "ON" : "OFF")
        music_cstr := strings.clone_to_cstring(music_text, context.temp_allocator)
        music_width := rl.MeasureText(music_cstr, 30)
        rl.DrawText(music_cstr, i32(g.win_size.x/2 - f32(music_width)/2), i32(g.win_size.y/2 + 40), 30, rl.LIGHTGRAY)
    }
    
    // Draw game over screen
    if state.is_game_over {
        overlay_color := rl.Color{0, 0, 0, 200}  // Semi-transparent black
        rl.DrawRectangle(0, 0, i32(g.win_size.x), i32(g.win_size.y), overlay_color)
        
        game_over_text := "GAME OVER"
        game_over_cstr := strings.clone_to_cstring(game_over_text, context.temp_allocator)
        text_width := rl.MeasureText(game_over_cstr, 60)
        rl.DrawText(game_over_cstr, i32(g.win_size.x/2 - f32(text_width)/2), i32(g.win_size.y/2 - 50), 60, rl.RED)
        
        restart_text := "Press R to restart"
        restart_cstr := strings.clone_to_cstring(restart_text, context.temp_allocator)
        restart_width := rl.MeasureText(restart_cstr, 30)
        rl.DrawText(restart_cstr, i32(g.win_size.x/2 - f32(restart_width)/2), i32(g.win_size.y/2 + 20), 30, rl.WHITE)
    }
}