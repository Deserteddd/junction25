package aigame

import rl "vendor:raylib"
import "core:slice"
import "core:strings"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:encoding/json"
import "core:mem"
import "core:os"
import "core:io"

// FFI for process execution using popen
foreign import libc "system:c"

FILE :: struct {}  // Opaque FILE type from C

foreign libc {
    popen :: proc(command: cstring, mode: cstring) -> ^FILE ---
    pclose :: proc(stream: ^FILE) -> i32 ---
    fread :: proc(ptr: rawptr, size: uint, nmemb: uint, stream: ^FILE) -> uint ---
    feof :: proc(stream: ^FILE) -> i32 ---
    setenv :: proc(name: cstring, value: cstring, overwrite: i32) -> i32 ---
    unsetenv :: proc(name: cstring) -> i32 ---
}

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
BOSS_HEALTH :: 200  // Base boss health (increased from 100, scales with room number)
BASE_ENEMY_HEALTH :: 1  // Base enemy health (scales with room number)
PLAYER_MAX_HP :: 100  // Player maximum health points
ENEMY_DAMAGE :: 10  // Damage enemies deal to player per hit
BOSS_PROJECTILE_DAMAGE :: 25  // Damage boss projectiles deal to player (increased from 15)
INVULNERABLE_DURATION :: 1.0  // Seconds of invulnerability after being hit
BOSS_SHOOT_INTERVAL :: 0.4  // Seconds between boss shots (3x faster than 1.2)
BASE_ENEMY_SPEED :: 50.0  // Base enemy speed (scales with room number)
BASE_BOSS_SPEED :: 50.0  // Base boss speed (increased from 30.0, scales with room number)
HEALTH_SCALE_PER_ROOM :: 1.5  // Health multiplier per room (50% increase - more aggressive)
SPEED_SCALE_PER_ROOM :: 1.2  // Speed multiplier per room (20% increase - more aggressive)
ENEMY_SEPARATION_DISTANCE :: 50.0  // Minimum distance enemies try to maintain from each other
ENEMY_SEPARATION_FORCE :: 200.0  // Force applied to separate overlapping enemies
WEAPON_DROP_CHANCE :: 0.3  // 30% chance for enemies to drop weapons
WEAPON_PICKUP_DISTANCE :: 40.0  // Distance player needs to be to pick up a weapon
NPC_INTERACTION_DISTANCE :: 80.0  // Distance player needs to be to interact with NPC
GEMINI_API_URL :: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent"
CHEESE_PRICE :: 50  // Price of cheese in coins
CHEESE_DAMAGE_BOOST :: 0.15  // +15% damage per cheese
CHEESE_SPEED_BOOST :: 0.10   // +10% speed per cheese
CHEESE_HP_BOOST :: 15        // +15 HP per cheese
COIN_DROP_CHANCE :: 0.4  // 40% chance for enemies to drop coins
COIN_DROP_AMOUNT :: 10  // Coins dropped per enemy

GameState :: struct {
    player:           Player,
    sprite_sheets:    [dynamic]SpriteSheet,
    player_sprite_sheet: SpriteSheet,  // Sprite sheet for player (optional)
    enemy_sprite_sheet: SpriteSheet,  // Sprite sheet for enemies (optional)
    npc_sprite_sheet: SpriteSheet,  // Sprite sheet for NPC (optional)
    projectiles:      [dynamic]Projectile,
    enemy_projectiles: [dynamic]Projectile,  // Projectiles shot by enemies/bosses
    enemies:          [dynamic]Enemy,
    dropped_weapons:  [dynamic]DroppedWeapon,  // Weapons dropped by enemies
    text_popups:      [dynamic]TextPopup,  // Text pop-ups above player
    active_sheet:     i32,
    board:            Board,
    room_textures:    [NUM_ROOM_TYPES]rl.Texture2D,  // Textures for each room type (deprecated, using background_textures)
    background_textures: [3]rl.Texture2D,  // Three large background images
    background_scale: f32,  // Scale factor for backgrounds (makes them larger)
    world_bounds:    vec2,  // World boundaries (width, height) - edges of the background images
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
    // NPC system
    npc:             NPC,        // NPC character
    dialogue_ui:     DialogueUI, // Dialogue UI state
    shop_items:      [dynamic]ShopItem,  // Shop items available for purchase
    dropped_coins:   [dynamic]Coin,  // Coins dropped by enemies
}

Coin :: struct {
    position: vec2,  // Coin position in world space
    amount: i32,     // Coin value
    pickup_timer: f32,  // Time since dropped
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
    // Upgrades
    damage_multiplier: f32,  // Damage multiplier from upgrades
    speed_multiplier: f32,   // Speed multiplier from upgrades
    hp_bonus: i32,           // Additional HP from upgrades
    // Shop/Currency
    coins: i32,              // Player's currency for buying items
}

TextPopup :: struct {
    text:      string,
    position:  vec2,  // World position
    timer:     f32,   // Time remaining
    color:     rl.Color,
}

NPC :: struct {
    position:      vec2,  // NPC position in world space
    name:          string,  // NPC name
    sprite:        rl.Texture2D,  // NPC sprite/texture (fallback)
    sprite_sheet:  ^SpriteSheet,  // Sprite sheet for animation (nil if using static texture)
    animation_frame: u64,  // Current animation frame
    interaction_distance: f32,  // Distance player needs to be to interact
    is_talking:    bool,  // Whether NPC is currently in dialogue
    dialogue_history: [dynamic]string,  // Conversation history
    current_response: string,  // Current AI response
    is_loading:    bool,  // Whether waiting for API response
    api_key:       string,  // Gemini API key (should be loaded from env or config)
    is_shop:       bool,  // Whether this NPC is a shopkeeper
}

ShopItem :: struct {
    name:        string,  // Item name
    description: string,  // Item description
    price:       i32,     // Price in coins
    effect_type: i32,     // 0 = damage, 1 = speed, 2 = hp
    effect_value: f32,    // Effect value (multiplier for damage/speed, amount for HP)
}

DialogueUI :: struct {
    is_visible:    bool,  // Whether dialogue UI is shown
    player_input:  string,  // Current player input text
    npc_response: string,  // Current NPC response
    input_focused: bool,  // Whether input field is focused
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

// Load the 3 large background images
load_background_textures :: proc() -> ([3]rl.Texture2D, vec2) {
    // Three background image paths - try multiple fallback options for each
    // Update these to match your actual image file names
    background_path_options := [3][3]string{
        {"assets/dungeon_bg1.png", "assets/dungeon1.png", "assets/dungeon.png"},  // Background 1 - tries multiple names
        {"assets/dungeon_bg2.png", "assets/dungeon2.png", "assets/dungeon.png"},  // Background 2 - tries multiple names
        {"assets/dungeon_bg3.png", "assets/dungeon3.png", "assets/dungeon.png"},  // Background 3 - tries multiple names
    }
    
    textures: [3]rl.Texture2D
    max_width: f32 = 0
    max_height: f32 = 0
    
    for path_options, i in background_path_options {
        texture: rl.Texture2D
        loaded := false
        
        // Try each path option until one works
        for path in path_options {
            path_cstr := strings.clone_to_cstring(path, context.temp_allocator)
            test_texture := rl.LoadTexture(path_cstr)
            
            if test_texture.id != 0 {
                texture = test_texture
                loaded = true
                fmt.printf("Loaded background %d from '%s'\n", i + 1, path)
                break
            }
        }
        
        // If none of the paths worked, create a fallback
        if !loaded {
            fmt.printf("Warning: Could not load background texture %d, using fallback\n", i + 1)
            img := rl.GenImageColor(1024, 1024, rl.DARKGRAY)
            texture = rl.LoadTextureFromImage(img)
            rl.UnloadImage(img)
        }
        
        textures[i] = texture
        
        // Track maximum dimensions
        if f32(texture.width) > max_width do max_width = f32(texture.width)
        if f32(texture.height) > max_height do max_height = f32(texture.height)
    }
    
    // Scale factor to make backgrounds larger (2x scale - half of previous 4x)
    scale: f32 = 2.0
    // World bounds are smaller than the full image to create a border inset from the edges
    // Using 85% of image size leaves 15% as border (7.5% on each side)
    border_margin: f32 = 0.85  // Use 85% of the image size, leaving 15% as border
    world_bounds := vec2{max_width * scale * border_margin, max_height * scale * border_margin}
    
    return textures, world_bounds
}

load_sprite_sheet :: proc(path: string) -> SpriteSheet {
    path_cstr := strings.clone_to_cstring(path, context.temp_allocator)
    rl_img := rl.LoadImage(path_cstr)
    
    if rl_img.data == nil || rl_img.width == 0 || rl_img.height == 0 {
        // Return empty sprite sheet if image failed to load
        empty_sheet: SpriteSheet
        empty_sheet.texture = {}
        empty_sheet.rects = nil
        return empty_sheet
    }
    
    // Extract pixel data
    width := i32(rl_img.width)
    height := i32(rl_img.height)
    pixels := slice.bytes_from_ptr(rl_img.data, int(width * height * 4))

    horizontal_segments,
    vertical_segments: [dynamic][2]i32
    defer delete(horizontal_segments)
    defer delete(vertical_segments)
    
    // Find horizontal segments (rows with content)
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
    
    // Find vertical segments (columns with content)
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
                    append(&vertical_segments, segment)
                }
                non_empty_streak = 0
            }
        }
    }
    
    // Create rects from segments
    rects: [dynamic]Rect
    for vertical in vertical_segments {
        for horizontal in horizontal_segments {
            rect := Rect {
                f32(vertical.x),
                f32(horizontal.x), 
                f32(vertical.y - vertical.x),
                f32(horizontal.y - horizontal.x),
            }
            append(&rects, rect)
        }
    }
    
    // Load texture from image
    texture := rl.LoadTextureFromImage(rl_img)
    rl.UnloadImage(rl_img)  // Free image data after loading texture
    
    // Allocate rects with context.allocator to ensure they persist
    sheet: SpriteSheet
    if len(rects) > 0 {
        allocated_rects := make([]Rect, len(rects), context.allocator)
        for i in 0..<len(rects) {
            allocated_rects[i] = rects[i]
        }
        sheet.rects = allocated_rects
    } else {
        sheet.rects = nil
    }
    sheet.texture = texture
    
    return sheet
}

// Load environment variable from .env file
load_env_var :: proc(key: string) -> (value: string, found: bool) {
    // First try system environment variable
    env_value := os.get_env(key)
    if len(env_value) > 0 {
        return env_value, true
    }
    
    // Try to read .env file
    file, err := os.open(".env")
    if err != os.ERROR_NONE {
        return "", false
    }
    defer os.close(file)
    
    // Read file content manually
    buffer: [4096]u8
    bytes_read, read_err := os.read(file, buffer[:])
    if read_err != os.ERROR_NONE || bytes_read == 0 {
        return "", false
    }
    
    // Parse .env file (simple parser - looks for KEY=value format)
    content := string(buffer[:bytes_read])
    lines := strings.split(content, "\n", context.temp_allocator)
    
    for line in lines {
        // Remove whitespace
        trimmed_line := strings.trim_space(line)
        
        // Skip empty lines and comments
        if len(trimmed_line) == 0 || trimmed_line[0] == '#' {
            continue
        }
        
        // Find the key
        eq_index := strings.index(trimmed_line, "=")
        if eq_index == -1 {
            continue
        }
        
        line_key := strings.trim_space(trimmed_line[:eq_index])
        if line_key == key {
            // Found the key, extract value
            line_value := strings.trim_space(trimmed_line[eq_index+1:])
            // Remove quotes if present
            if len(line_value) >= 2 && line_value[0] == '"' && line_value[len(line_value)-1] == '"' {
                line_value = line_value[1:len(line_value)-1]
            } else if len(line_value) >= 2 && line_value[0] == '\'' && line_value[len(line_value)-1] == '\'' {
                line_value = line_value[1:len(line_value)-1]
            }
            // Remove any trailing whitespace, newlines, or control characters
            line_value = strings.trim_right(line_value, " \t\r\n")
            // Remove any control characters (non-printable ASCII) and ensure clean string
            cleaned_value := strings.builder_make(context.temp_allocator)
            for c in line_value {
                // Only keep printable ASCII characters (32-126)
                // This excludes control characters like \x7f (DEL)
                if c >= 32 && c <= 126 {
                    strings.write_rune(&cleaned_value, c)
                }
            }
            final_value := strings.to_string(cleaned_value)
            // Additional safety: trim again after cleaning
            final_value = strings.trim_space(final_value)
            return final_value, true
        }
    }
    
    return "", false
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
        player.position = {0, 0}  // Start at center of world (will be clamped to bounds after textures load)
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
        // Initialize upgrades
        player.damage_multiplier = 1.0
        player.speed_multiplier = 1.0
        player.hp_bonus = 0
        player.coins = 0  // Start with 0 coins
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
    state.text_popups = {}  // Initialize text popups array
    
    // Initialize NPC (will be positioned after world_bounds is loaded)
    {
        using state.npc
        position = {0, 0}  // Temporary, will be set below
        name = "Drunkard Rat Merchant"
        sprite = {}  // Will load a texture or use a default
        interaction_distance = NPC_INTERACTION_DISTANCE
        is_talking = false
        dialogue_history = {}
        current_response = "Loading greeting..."  // Will be replaced by Gemini API
        is_loading = false
        is_shop = true  // This NPC is a shopkeeper
        
        // Initialize sprite sheet fields first
        sprite_sheet = nil
        animation_frame = 0
        
        // Load cheese merchant sprite sheet
        merchant_sprite_path := "assets/cheese_merchant.png"
        merchant_path_cstr := strings.clone_to_cstring(merchant_sprite_path, context.temp_allocator)
        merchant_img := rl.LoadImage(merchant_path_cstr)
        
        if merchant_img.data != nil && merchant_img.width > 0 && merchant_img.height > 0 {
            // Cheese merchant sprite sheet: 4 rows × 12 frames = 48 frames
            // Texture is 3584x1024, so each sprite is approximately 298x256
            texture := rl.LoadTextureFromImage(merchant_img)
            rl.UnloadImage(merchant_img)
            
            if texture.id != 0 {
                // Manually create sprite sheet with known layout: 4 rows, 12 columns
                sprite_width: f32 = f32(texture.width) / 12.0  // 12 frames per row
                sprite_height: f32 = f32(texture.height) / 4.0  // 4 rows
                
                // Create rects for all 48 frames (4 rows × 12 columns)
                num_rows := 4
                num_cols := 12
                total_frames := num_rows * num_cols
                allocated_rects := make([]Rect, total_frames, context.allocator)
                
                for row in 0..<num_rows {
                    for col in 0..<num_cols {
                        frame_idx := row * num_cols + col
                        allocated_rects[frame_idx] = Rect{
                            f32(col) * sprite_width,
                            f32(row) * sprite_height,
                            sprite_width,
                            sprite_height,
                        }
                    }
                }
                
                state.npc_sprite_sheet.texture = texture
                state.npc_sprite_sheet.rects = allocated_rects
                sprite_sheet = &state.npc_sprite_sheet
                animation_frame = 0
                
                fmt.printf("Loaded cheese merchant sprite sheet from '%s' (%d frames, %dx%d per frame, texture: %dx%d)\n", 
                    merchant_sprite_path, total_frames, i32(sprite_width), i32(sprite_height), texture.width, texture.height)
            } else {
                sprite_sheet = nil
                animation_frame = 0
                fmt.printf("Warning: Could not load cheese merchant texture from '%s'\n", merchant_sprite_path)
            }
        } else {
            sprite_sheet = nil
            animation_frame = 0
            fmt.printf("Warning: Could not load cheese merchant image from '%s'\n", merchant_sprite_path)
        }
        
        // Load API key from .env file for Gemini API
        api_key_value, found := load_env_var("API_KEY")
        if found {
            api_key = api_key_value
            fmt.printf("Loaded API key for Cheese Merchant\n")
        } else {
            api_key = ""
            fmt.printf("Warning: API_KEY not found - NPC will use fallback greeting\n")
        }
    }
    
    // Initialize shop items
    {
        state.shop_items = {}
        // Add cheese items
        cheese_damage := ShopItem{
            name = "Power Cheese",
            description = "+15% Damage",
            price = CHEESE_PRICE,
            effect_type = 0,  // Damage
            effect_value = CHEESE_DAMAGE_BOOST,
        }
        cheese_speed := ShopItem{
            name = "Speed Cheese",
            description = "+10% Speed",
            price = CHEESE_PRICE,
            effect_type = 1,  // Speed
            effect_value = CHEESE_SPEED_BOOST,
        }
        cheese_hp := ShopItem{
            name = "Health Cheese",
            description = "+15 Max HP",
            price = CHEESE_PRICE,
            effect_type = 2,  // HP
            effect_value = f32(CHEESE_HP_BOOST),
        }
        append(&state.shop_items, cheese_damage)
        append(&state.shop_items, cheese_speed)
        append(&state.shop_items, cheese_hp)
    }
    
    // Initialize dropped coins array
    state.dropped_coins = {}
    
    // Initialize dialogue UI
    {
        using state.dialogue_ui
        is_visible = false
        player_input = ""
        npc_response = ""
        input_focused = false
    }
    
    // Load room textures from PNG files for each room type (kept for compatibility)
    for i in 0..<NUM_ROOM_TYPES {
        room_type := Room_Type(i)
        state.room_textures[i] = load_room_texture(room_type)
    }
    
    // Load the 3 large background images
    state.background_textures, state.world_bounds = load_background_textures()
    state.background_scale = 2.0  // Make backgrounds 2x larger
    
    // Set NPC position to bottom-left corner of map
    {
        half_bounds := state.world_bounds / 2.0
        state.npc.position = {-half_bounds.x + 100, half_bounds.y - 100}  // Bottom-left corner with offset
    }
    
    // Generate NPC greeting using Gemini API (if available)
    if state.npc.is_shop && state.npc.api_key != "" {
        fmt.printf("=== Testing Gemini API ===\n")
        fmt.printf("Attempting to call Gemini API for NPC greeting...\n")
        
        // Generate initial greeting with drunkard rat prompt
        greeting, ok := call_gemini_api(&state.npc, "greet your customer and apologize for being so drunk because you have been drinking too much beer at the local pub")
        
        if ok {
            fmt.printf("✓ Gemini API call successful!\n")
            fmt.printf("Response: %s\n", greeting)
            state.npc.current_response = greeting
        } else {
            fmt.printf("✗ Gemini API call failed\n")
            fmt.printf("Error: %s\n", greeting)
            // Fallback greeting if API fails - show error in message
            state.npc.current_response = fmt.tprintf("*hic* Welcome, traveler! *burp* I'm... I'm sorry, I've had too much beer at the pub. But I still have the finest cheese! Press 'E' to shop!\n\n[API Status: %s]", greeting)
        }
        fmt.printf("=== End API Test ===\n\n")
    } else if state.npc.is_shop {
        // Fallback greeting if no API key
        fmt.printf("No API key found. Using fallback greeting.\n")
        fmt.printf("To enable Gemini API:\n")
        fmt.printf("  1. Create a .env file in the project root\n")
        fmt.printf("  2. Add: API_KEY=your_actual_api_key_here\n")
        fmt.printf("  3. Or set the API_KEY environment variable\n\n")
        state.npc.current_response = "*hic* Welcome, traveler! *burp* I'm... I'm sorry, I've had too much beer at the pub. But I still have the finest cheese! Press 'E' to shop!"
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

// Give player a random upgrade
give_player_upgrade :: proc(state: ^GameState) {
    upgrade_type := rl.GetRandomValue(0, 2)  // 0 = damage, 1 = speed, 2 = hp
    
    switch upgrade_type {
        case 0:  // Damage upgrade
            state.player.damage_multiplier += 0.2  // +20% damage
            popup := TextPopup{
                text = "+20% Damage!",
                position = state.player.position,
                timer = 2.0,
                color = rl.YELLOW,
            }
            append(&state.text_popups, popup)
        case 1:  // Speed upgrade
            state.player.speed_multiplier += 0.15  // +15% speed
            popup := TextPopup{
                text = "+15% Speed!",
                position = state.player.position,
                timer = 2.0,
                color = rl.SKYBLUE,
            }
            append(&state.text_popups, popup)
        case 2:  // HP upgrade
            hp_gain: i32 = 20
            state.player.hp_bonus += hp_gain
            state.player.max_hp += hp_gain
            state.player.hp += hp_gain  // Also heal the player
            popup := TextPopup{
                text = fmt.tprintf("+%d Max HP!", hp_gain),
                position = state.player.position,
                timer = 2.0,
                color = rl.GREEN,
            }
            append(&state.text_popups, popup)
    }
}

// Call Gemini API using Python bridge script
// This is a simple and reliable approach that uses a Python script to handle HTTPS
call_gemini_via_python :: proc(api_key: string, message: string) -> (response: string, ok: bool) {
    // Build the Python command
    python_script := "gemini_api_bridge.py"
    
    // Validate API key before using it
    if len(api_key) == 0 {
        return "API key is empty", false
    }
    
    // Check for control characters in API key and clean if needed
    cleaned_api_key := api_key
    has_control_chars := false
    for c in api_key {
        if c < 32 || c > 126 {
            has_control_chars = true
            break
        }
    }
    if has_control_chars {
        fmt.printf("Warning: API key contains control characters, filtering them out\n")
        // Filter out control characters
        cleaned_key_builder := strings.builder_make(context.temp_allocator)
        for c in api_key {
            if c >= 32 && c <= 126 {
                strings.write_rune(&cleaned_key_builder, c)
            }
        }
        cleaned_api_key = strings.to_string(cleaned_key_builder)
    }
    
    // Use environment variables to pass arguments, avoiding shell escaping issues
    api_key_cstr := strings.clone_to_cstring(cleaned_api_key, context.temp_allocator)
    message_cstr := strings.clone_to_cstring(message, context.temp_allocator)
    
    // Set environment variables
    setenv("GEMINI_API_KEY", api_key_cstr, 1)
    setenv("GEMINI_MESSAGE", message_cstr, 1)
    
    // Build simple command that reads from environment variables
    cmd := fmt.tprintf("python3 %s", python_script)
    cmd_cstr := strings.clone_to_cstring(cmd, context.temp_allocator)
    
    fmt.printf("Executing: python3 %s (using env vars)\n", python_script)
    
    // Use popen to execute the command and read output
    pipe := popen(cmd_cstr, "r")
    if pipe == nil {
        // Clean up environment variables
        unsetenv("GEMINI_API_KEY")
        unsetenv("GEMINI_MESSAGE")
        return "Failed to execute Python script: popen returned nil", false
    }
    defer {
        pclose(pipe)
        unsetenv("GEMINI_API_KEY")
        unsetenv("GEMINI_MESSAGE")
    }
    
    // Read output from pipe using fread
    buffer: [8192]u8
    total_read: uint = 0
    
    for {
        if feof(pipe) != 0 {
            break
        }
        bytes_read := fread(rawptr(&buffer[total_read]), 1, 8192 - total_read, pipe)
        if bytes_read == 0 {
            break
        }
        total_read += bytes_read
        if total_read >= 8192 {
            break  // Buffer full
        }
    }
    
    response_text := ""
    if total_read > 0 {
        response_text = string(buffer[:total_read])
    }
    
    // Trim whitespace
    response_text = strings.trim_space(response_text)
    
    if len(response_text) == 0 {
        return "Empty response from API", false
    }
    
    // Check if response is an error
    if strings.has_prefix(response_text, "HTTP Error") || strings.has_prefix(response_text, "Error:") {
        return response_text, false
    }
    
    // Filter text to ASCII-only characters for Raylib font compatibility
    // Raylib's default font only supports ASCII, so we need to convert UTF-8 to ASCII
    filtered_text := strings.builder_make(context.temp_allocator)
    for c in response_text {
        // Keep ASCII printable characters (32-126)
        if c >= 32 && c <= 126 {
            strings.write_rune(&filtered_text, c)
        } else if c == '\n' || c == '\t' {
            // Keep newlines and tabs
            strings.write_rune(&filtered_text, c)
        } else if c == 8217 || c == 8216 {
            // Convert smart quotes to regular quotes
            strings.write_rune(&filtered_text, '\'')
        } else if c == 8220 || c == 8221 {
            // Convert smart double quotes to regular quotes
            strings.write_rune(&filtered_text, '"')
        } else if c == 8212 || c == 8211 {
            // Convert em dashes to regular dashes
            strings.write_rune(&filtered_text, '-')
        } else if c == 8230 {
            // Convert ellipsis to three dots
            strings.write_string(&filtered_text, "...")
        } else if c > 127 {
            // Replace other non-ASCII characters with a space or skip
            // (This includes emojis and other Unicode characters)
            strings.write_rune(&filtered_text, ' ')
        }
    }
    response_text = strings.to_string(filtered_text)
    
    return response_text, true
}

// Call Gemini API to get NPC response
call_gemini_api :: proc(npc: ^NPC, player_message: string) -> (response: string, ok: bool) {
    if npc.api_key == "" {
        // Fallback responses when API key is not set
        if npc.is_shop {
            // Shop-specific fallback (drunkard rat)
            if strings.contains(strings.to_lower(player_message, context.temp_allocator), "greet") || strings.contains(strings.to_lower(player_message, context.temp_allocator), "apologize") {
                return "*hic* Welcome, brave adventurer! *burp* I'm... I'm sorry, I'm a bit drunk. Had too much beer at the pub, you see. But my cheeses are still the finest! How may I assist you today?", true
            }
            return "*hic* Ah yes, my cheeses are the finest in the land! *burp* They'll make you stronger, faster, and more powerful! Sorry about the... the drunkenness.", true
        } else {
            // Generic fallback
            message_lower := strings.to_lower(player_message, context.temp_allocator)
            if strings.contains(message_lower, "hello") || strings.contains(message_lower, "hi") {
                return "Greetings, traveler! I am the Wise Sage. How may I assist you on your quest?", true
            } else if strings.contains(message_lower, "help") {
                return "I can offer guidance on your journey. What troubles you, brave adventurer?", true
            } else {
                return fmt.tprintf("Ah, you speak of '%s'. That is an interesting topic. Tell me more about your journey.", player_message), true
            }
        }
    }
    
    // Build the prompt based on NPC type
    prompt: string
    if npc.is_shop {
        if strings.contains(strings.to_lower(player_message, context.temp_allocator), "greet") || strings.contains(strings.to_lower(player_message, context.temp_allocator), "apologize") {
            prompt = "You are a drunkard rat and a cheese merchant, greet your customer and apologize for being so drunk because you have been drinking too much beer at the local pub"
        } else {
            prompt = fmt.tprintf("You are a drunkard rat and a cheese merchant in a castle-themed game. You've been drinking too much beer at the local pub. The player says: \"%s\". Respond as the drunkard rat cheese merchant would, keeping responses brief (1-2 sentences) and include your drunkenness.", player_message)
        }
    } else {
        prompt = fmt.tprintf("You are a wise sage in a castle-themed game. The player says: \"%s\". Respond as the sage would, keeping responses brief (1-2 sentences).", player_message)
    }
    
    // Call Gemini API using Python bridge
    response_text, api_ok := call_gemini_via_python(npc.api_key, prompt)
    if !api_ok {
        return response_text, false  // response_text contains error message
    }
    
    return response_text, true
}

// Buy an item from the shop
buy_item :: proc(state: ^GameState, item_index: i32) {
    if item_index < 0 || item_index >= i32(len(state.shop_items)) {
        return
    }
    
    item := state.shop_items[item_index]
    
    // Check if player has enough coins
    if state.player.coins < item.price {
        state.dialogue_ui.npc_response = fmt.tprintf("Not enough coins! You need %d, but you have %d.", item.price, state.player.coins)
        return
    }
    
    // Deduct coins
    state.player.coins -= item.price
    
    // Apply effect
    switch item.effect_type {
        case 0:  // Damage
            state.player.damage_multiplier += item.effect_value
            popup := TextPopup{
                text = fmt.tprintf("+%.0f%% Damage!", item.effect_value * 100.0),
                position = state.player.position,
                timer = 2.0,
                color = rl.YELLOW,
            }
            append(&state.text_popups, popup)
        case 1:  // Speed
            state.player.speed_multiplier += item.effect_value
            popup := TextPopup{
                text = fmt.tprintf("+%.0f%% Speed!", item.effect_value * 100.0),
                position = state.player.position,
                timer = 2.0,
                color = rl.SKYBLUE,
            }
            append(&state.text_popups, popup)
        case 2:  // HP
            hp_gain := i32(item.effect_value)
            state.player.hp_bonus += hp_gain
            state.player.max_hp += hp_gain
            state.player.hp += hp_gain  // Also heal
            popup := TextPopup{
                text = fmt.tprintf("+%d Max HP!", hp_gain),
                position = state.player.position,
                timer = 2.0,
                color = rl.GREEN,
            }
            append(&state.text_popups, popup)
    }
    
    state.dialogue_ui.npc_response = fmt.tprintf("Thank you! You bought %s. Press 1, 2, or 3 for more!", item.name)
}

start_next_room :: proc(state: ^GameState) {
    state.room_number += 1
    
    // Give player an upgrade every 2 rooms
    if state.room_number > 1 && state.room_number % 2 == 0 {
        give_player_upgrade(state)
    }
    
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
            draw_board(state.board, state.room_textures, state.background_textures, state.background_scale, state.world_bounds) // <-- DRAW BOARD FIRST
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
draw_board :: proc(board: Board, room_textures: [NUM_ROOM_TYPES]rl.Texture2D, background_textures: [3]rl.Texture2D, background_scale: f32, world_bounds: vec2) {
    // Select which background to use based on room number (cycles through 3 backgrounds)
    background_idx := board.room_type % 3
    if background_idx < 0 || background_idx >= 3 {
        background_idx = 0
    }
    
    background_texture := background_textures[background_idx]
    
    if background_texture.id == 0 {
        return  // Skip if texture not loaded
    }
    
    // Calculate scaled size of background
    scaled_width := f32(background_texture.width) * background_scale
    scaled_height := f32(background_texture.height) * background_scale
    
    // Calculate world position (centered at origin)
    world_x := -scaled_width / 2.0
    world_y := -scaled_height / 2.0
    
    // Convert to screen coordinates with camera offset
    screen_x := world_x + g.camera_offset.x
    screen_y := world_y + g.camera_offset.y
    
    // Draw the large background texture
    rl.DrawTexturePro(
        background_texture,
        {0, 0, f32(background_texture.width), f32(background_texture.height)},
        {screen_x, screen_y, scaled_width, scaled_height},
        {0, 0},
        0,
        rl.WHITE
    )
    }


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
        // Apply acceleration in movement direction (with speed multiplier)
        effective_speed := state.player.speed * state.player.speed_multiplier
        target_velocity := move_dir * effective_speed
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
        new_position := state.player.position + state.player.velocity * dt
        
        // Clamp player position to world boundaries (edges of background images)
        if state.world_bounds.x > 0 && state.world_bounds.y > 0 {
            player_radius: f32 = 30.0  // Player collision radius
            half_bounds := state.world_bounds / 2.0
            new_position.x = math.clamp(new_position.x, -half_bounds.x + player_radius, half_bounds.x - player_radius)
            new_position.y = math.clamp(new_position.y, -half_bounds.y + player_radius, half_bounds.y - player_radius)
        }
        
        state.player.position = new_position
        
        // Update player animation frame (only if moving)
        move_len := math.sqrt(state.player.velocity.x*state.player.velocity.x + state.player.velocity.y*state.player.velocity.y)
        if move_len > 10.0 {  // Only animate when moving (threshold to avoid jitter)
            state.player.animation_frame += 1
        }
    }
    
    // Update text popups
    for &popup, i in state.text_popups {
        popup.timer -= dt
        // Make popup float upward
        popup.position.y -= 30.0 * dt
        // Remove expired popups
        if popup.timer <= 0 {
            unordered_remove(&state.text_popups, i)
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
    
    // NPC interaction
    if !state.is_start_screen && !state.is_game_over {
        distance_to_npc := dist(state.player.position, state.npc.position)
        
        // Check if player is close enough to interact
        if distance_to_npc < state.npc.interaction_distance {
            // Press E to start dialogue/shop
            if rl.IsKeyPressed(.E) && !state.dialogue_ui.is_visible {
                // Start dialogue/shop
                state.dialogue_ui.is_visible = true
                state.dialogue_ui.input_focused = false  // Shop doesn't need text input
                if state.npc.is_shop {
                    // Use the Gemini-generated greeting (or fallback)
                    state.dialogue_ui.npc_response = state.npc.current_response
                } else {
                    state.dialogue_ui.npc_response = state.npc.current_response
                    state.dialogue_ui.input_focused = true
                }
                state.npc.is_talking = true
            }
            
            // Shop purchase logic
            if state.dialogue_ui.is_visible && state.npc.is_shop {
                // Press 1, 2, or 3 to buy items
                if rl.IsKeyPressed(.ONE) && len(state.shop_items) > 0 {
                    buy_item(state, 0)
                } else if rl.IsKeyPressed(.TWO) && len(state.shop_items) > 1 {
                    buy_item(state, 1)
                } else if rl.IsKeyPressed(.THREE) && len(state.shop_items) > 2 {
                    buy_item(state, 2)
                }
            }
            
            // Send message with ENTER when dialogue is open (only for non-shop NPCs)
            if state.dialogue_ui.is_visible && !state.npc.is_shop && (rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.KP_ENTER)) {
                if len(state.dialogue_ui.player_input) > 0 {
                    // Add player message to history
                    player_msg := fmt.tprintf("Player: %s", state.dialogue_ui.player_input)
                    append(&state.npc.dialogue_history, player_msg)
                    
                    // Call Gemini API (synchronous for now - could be made async)
                    state.npc.is_loading = true
                    npc_response, ok := call_gemini_api(&state.npc, state.dialogue_ui.player_input)
                    state.npc.is_loading = false
                    
                    if ok {
                        state.npc.current_response = npc_response
                        state.dialogue_ui.npc_response = npc_response
                        npc_msg := fmt.tprintf("Sage: %s", npc_response)
                        append(&state.npc.dialogue_history, npc_msg)
                    } else {
                        state.dialogue_ui.npc_response = npc_response  // Error message
                    }
                    
                    // Clear input
                    state.dialogue_ui.player_input = ""
                }
            }
            
            // Close dialogue with ESC
            if state.dialogue_ui.is_visible && rl.IsKeyPressed(.ESCAPE) {
                state.dialogue_ui.is_visible = false
                state.dialogue_ui.input_focused = false
                state.npc.is_talking = false
            }
            
            // Handle text input when dialogue is open
            if state.dialogue_ui.is_visible && state.dialogue_ui.input_focused {
                // Get typed characters
                key := rl.GetCharPressed()
                for key > 0 {
                    if key >= 32 && key <= 125 {  // Printable ASCII
                        state.dialogue_ui.player_input = fmt.tprintf("%s%c", state.dialogue_ui.player_input, key)
                    }
                    key = rl.GetCharPressed()
                }
                
                // Backspace
                if rl.IsKeyPressed(.BACKSPACE) && len(state.dialogue_ui.player_input) > 0 {
                    state.dialogue_ui.player_input = state.dialogue_ui.player_input[:len(state.dialogue_ui.player_input)-1]
                }
            }
        } else {
            // Close dialogue if player moves away
            if state.dialogue_ui.is_visible {
                state.dialogue_ui.is_visible = false
                state.dialogue_ui.input_focused = false
                state.npc.is_talking = false
            }
        }
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
    
    // Update coin pickup timers and check for pickups
    for &coin, i in state.dropped_coins {
        coin.pickup_timer += dt
        
        // Check if player is close enough to pick up
        distance_to_coin := dist(state.player.position, coin.position)
        if distance_to_coin < WEAPON_PICKUP_DISTANCE {
            // Player picks up coin
            state.player.coins += coin.amount
            popup := TextPopup{
                text = fmt.tprintf("+%d Coins!", coin.amount),
                position = coin.position,
                timer = 1.5,
                color = rl.GOLD,
            }
            append(&state.text_popups, popup)
            unordered_remove(&state.dropped_coins, i)
            break  // Only pick up one coin per frame
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
        
        // Update NPC animation frame
        // Access via state.npc_sprite_sheet directly to avoid pointer issues
        if state.npc_sprite_sheet.texture.id != 0 && 
           state.npc_sprite_sheet.rects != nil && 
           len(state.npc_sprite_sheet.rects) > 0 {
            state.npc.animation_frame += 1
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
                    
                    // Chance to drop coins
                    coin_drop_chance := f32(rl.GetRandomValue(0, 100)) / 100.0
                    if coin_drop_chance < COIN_DROP_CHANCE {
                        coin_amount: i32 = COIN_DROP_AMOUNT
                        if is_boss {
                            coin_amount = COIN_DROP_AMOUNT * 3  // Bosses drop more coins
                        }
                        dropped_coin := Coin{
                            position = enemy_pos,
                            amount = coin_amount,
                            pickup_timer = 0.0,
                        }
                        append(&state.dropped_coins, dropped_coin)
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
            damage      = weapon.damage * state.player.damage_multiplier,  // Apply damage multiplier
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
    
    // Draw dropped coins
    for coin in state.dropped_coins {
        screen_pos := coin.position + g.camera_offset
        
        // Draw coin as a gold circle
        coin_size: f32 = 20.0
        rl.DrawCircleV(screen_pos, coin_size/2, rl.GOLD)
        rl.DrawCircleLines(i32(screen_pos.x), i32(screen_pos.y), coin_size/2, rl.YELLOW)
        
        // Draw coin amount
        amount_text := fmt.tprintf("%d", coin.amount)
        amount_cstr := strings.clone_to_cstring(amount_text, context.temp_allocator)
        text_width := rl.MeasureText(amount_cstr, 12)
        rl.DrawText(amount_cstr, i32(screen_pos.x) - text_width/2, i32(screen_pos.y - coin_size/2 - 15), 12, rl.WHITE)
    }
    
    // Draw dropped weapons
    for dw in state.dropped_weapons {
        screen_pos := dw.position + g.camera_offset
        
        // Draw weapon texture with pulsing effect
        pulse := math.sin(dw.pickup_timer * 3.0) * 0.2 + 1.0  // Pulse between 0.8 and 1.2
        weapon_size: f32 = 80.0 * pulse  // Increased from 40.0
        
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

    // Draw text popups above player
    for popup in state.text_popups {
        screen_pos := popup.position + g.camera_offset
        // Fade out as timer decreases
        alpha := u8((popup.timer / 2.0) * 255.0)  // Fade from full to transparent
        if alpha > 255 do alpha = 255
        popup_color := popup.color
        popup_color.a = alpha
        
        text_cstr := strings.clone_to_cstring(popup.text, context.temp_allocator)
        text_width := rl.MeasureText(text_cstr, 20)
        rl.DrawText(text_cstr, i32(screen_pos.x) - text_width/2, i32(screen_pos.y - 40), 20, popup_color)
    }
    
    // Draw NPC
    {
        npc_screen_pos := state.npc.position + g.camera_offset
        npc_size: f32 = 80.0  // Increased size for better visibility
        
        // Draw NPC with animation if sprite sheet is available
        // Access via state.npc_sprite_sheet directly to avoid pointer issues (like player sprite sheet)
        if state.npc_sprite_sheet.texture.id != 0 && 
           state.npc_sprite_sheet.rects != nil && 
           len(state.npc_sprite_sheet.rects) > 0 {
            // Draw animated sprite sheet
            num_frames := u64(len(state.npc_sprite_sheet.rects))
            if num_frames > 0 {
                frame_idx := (state.npc.animation_frame / 8) % num_frames  // Slow down animation
                if frame_idx < num_frames {
                    frame := state.npc_sprite_sheet.rects[frame_idx]
                    
                    // Ensure frame rect is valid
                    if frame.width > 0 && frame.height > 0 {
                        // Calculate aspect ratio to maintain sprite proportions
                        aspect_ratio := frame.width / frame.height
                        draw_width := npc_size
                        draw_height := npc_size / aspect_ratio
                        
                        rl.DrawTexturePro(
                            state.npc_sprite_sheet.texture,
                            frame,
                            Rect{npc_screen_pos.x - draw_width/2, npc_screen_pos.y - draw_height/2, draw_width, draw_height},
                            {0, 0},
                            0,
                            rl.WHITE
                        )
                    }
                }
            }
        } else if state.npc.sprite.id != 0 {
            // Draw static sprite if loaded
            rl.DrawTexturePro(
                state.npc.sprite,
                Rect{0, 0, f32(state.npc.sprite.width), f32(state.npc.sprite.height)},
                Rect{npc_screen_pos.x - npc_size/2, npc_screen_pos.y - npc_size/2, npc_size, npc_size},
                {0, 0},
                0,
                rl.WHITE
            )
        } else {
            // Fallback: draw as a blue circle
            rl.DrawCircleV(npc_screen_pos, npc_size/2, rl.BLUE)
        }
        
        // Draw NPC name above
        name_cstr := strings.clone_to_cstring(state.npc.name, context.temp_allocator)
        name_width := rl.MeasureText(name_cstr, 16)
        rl.DrawText(name_cstr, i32(npc_screen_pos.x) - name_width/2, i32(npc_screen_pos.y - npc_size/2 - 25), 16, rl.WHITE)
        
        // Draw interaction prompt if player is close
        distance_to_npc := dist(state.player.position, state.npc.position)
        if distance_to_npc < state.npc.interaction_distance {
            prompt_text := "Press E to talk"
            prompt_cstr := strings.clone_to_cstring(prompt_text, context.temp_allocator)
            prompt_width := rl.MeasureText(prompt_cstr, 14)
            rl.DrawText(prompt_cstr, i32(npc_screen_pos.x) - prompt_width/2, i32(npc_screen_pos.y + npc_size/2 + 10), 14, rl.YELLOW)
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
            frame_idx := (state.player.animation_frame / 8) % u64(len(state.player_sprite_sheet.rects))

            player_size: f32 = 64.0  // Fixed size in pixels
            
            dst_rect := Rect {
                g.win_size.x/2 - player_size/2+30,
                g.win_size.y/2 - player_size/2+20,
                player_size,
                player_size,
            }
            rl.DrawTexturePro(
                state.player_sprite_sheet.texture,
                state.player_sprite_sheet.rects[frame_idx],
                dst_rect,
                {dst_rect.width/2, dst_rect.height/2},
                0,
                255
            )
        }
        
        // Draw weapon in player's hand, rotated to face aim direction
        if state.player.current_weapon.texture.id != 0 {
            weapon_size: f32 = 70.0  // Weapon size (increased from 35.0)
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
    
    // Draw dialogue UI / Shop (drawn after player so it appears on top)
    if state.dialogue_ui.is_visible {
        // Draw dialogue box background (larger shop UI)
        box_width: f32 = 800.0  // Increased from 600.0
        box_height: f32 = 500.0  // Increased from 400.0
        box_x := (g.win_size.x - box_width) / 2.0
        box_y := (g.win_size.y - box_height) / 2.0
        
        // Background
        rl.DrawRectangle(i32(box_x), i32(box_y), i32(box_width), i32(box_height), rl.Color{20, 20, 30, 240})
        rl.DrawRectangleLines(i32(box_x), i32(box_y), i32(box_width), i32(box_height), rl.WHITE)
        
        // NPC name (larger) - with clipping to prevent overflow
        npc_name_cstr := strings.clone_to_cstring(state.npc.name, context.temp_allocator)
        npc_name_max_width := box_width - 200.0  // Leave space for coins
        npc_name_width := f32(rl.MeasureText(npc_name_cstr, 28))
        if npc_name_width > npc_name_max_width {
            rl.BeginScissorMode(i32(box_x + 15), i32(box_y + 15), i32(npc_name_max_width), 35)
            rl.DrawText(npc_name_cstr, i32(box_x + 15), i32(box_y + 15), 28, rl.YELLOW)
            rl.EndScissorMode()
        } else {
            rl.DrawText(npc_name_cstr, i32(box_x + 15), i32(box_y + 15), 28, rl.YELLOW)
        }
        
        // Show coins (larger) - with clipping to prevent overflow
        coins_text := fmt.tprintf("Coins: %d", state.player.coins)
        coins_cstr := strings.clone_to_cstring(coins_text, context.temp_allocator)
        coins_width := f32(rl.MeasureText(coins_cstr, 24))
        coins_max_width: f32 = 200.0  // Max width for coins text
        if coins_width > coins_max_width {
            rl.BeginScissorMode(i32(box_x + box_width - coins_max_width - 15), i32(box_y + 15), i32(coins_max_width), 30)
            rl.DrawText(coins_cstr, i32(box_x + box_width - coins_max_width - 15), i32(box_y + 15), 24, rl.GOLD)
            rl.EndScissorMode()
        } else {
            rl.DrawText(coins_cstr, i32(box_x + box_width - coins_width - 15), i32(box_y + 15), 24, rl.GOLD)
        }
        
        if state.npc.is_shop {
            // Draw shop items with clipping to prevent overflow
            // Calculate available space for items (leave room for header, message, and instructions)
            items_start_y: f32 = box_y + 60.0
            items_end_y: f32 = box_y + box_height - 100.0  // Leave space for message and instructions
            items_available_height: f32 = items_end_y - items_start_y
            
            y_offset: f32 = 60.0
            item_height: f32 = 70.0  // Increased item height for larger text
            
            // Use scissor mode to clip all items to the available area
            rl.BeginScissorMode(i32(box_x + 15), i32(items_start_y), i32(box_width - 30), i32(items_available_height))
            
            for item, i in state.shop_items {
                item_y := box_y + y_offset
                
                // Skip drawing if item is outside the visible area
                if item_y > items_end_y do break
                
                // Item background
                can_afford := state.player.coins >= item.price
                item_color: rl.Color
                if can_afford {
                    item_color = rl.Color{40, 40, 50, 255}
                } else {
                    item_color = rl.Color{30, 20, 20, 255}
                }
                rl.DrawRectangle(i32(box_x + 15), i32(item_y), i32(box_width - 30), i32(item_height), item_color)
                rl.DrawRectangleLines(i32(box_x + 15), i32(item_y), i32(box_width - 30), i32(item_height), rl.WHITE)
                
                // Item number and name (larger, with word wrap)
                item_num_text := fmt.tprintf("%d. %s", i + 1, item.name)
                item_num_cstr := strings.clone_to_cstring(item_num_text, context.temp_allocator)
                max_text_width := box_width - 200.0  // Leave space for price
                text_width := f32(rl.MeasureText(item_num_cstr, 22))
                if text_width > max_text_width {
                    // Clip text if too long using scissor mode
                    rl.BeginScissorMode(i32(box_x + 25), i32(item_y + 8), i32(max_text_width), 30)
                    rl.DrawText(item_num_cstr, i32(box_x + 25), i32(item_y + 8), 22, rl.WHITE)
                    rl.EndScissorMode()
                } else {
                    rl.DrawText(item_num_cstr, i32(box_x + 25), i32(item_y + 8), 22, rl.WHITE)
                }
                
                // Description (larger, with clipping)
                desc_cstr := strings.clone_to_cstring(item.description, context.temp_allocator)
                desc_max_width := box_width - 200.0
                desc_text_width := f32(rl.MeasureText(desc_cstr, 18))
                if desc_text_width > desc_max_width {
                    rl.BeginScissorMode(i32(box_x + 25), i32(item_y + 35), i32(desc_max_width), 30)
                    rl.DrawText(desc_cstr, i32(box_x + 25), i32(item_y + 35), 18, rl.GRAY)
                    rl.EndScissorMode()
                } else {
                    rl.DrawText(desc_cstr, i32(box_x + 25), i32(item_y + 35), 18, rl.GRAY)
                }
                
                // Price (larger) - with clipping to prevent overflow
                price_text := fmt.tprintf("%d coins", item.price)
                price_cstr := strings.clone_to_cstring(price_text, context.temp_allocator)
                price_width := f32(rl.MeasureText(price_cstr, 20))
                price_max_width: f32 = 180.0  // Max width for price
                price_color: rl.Color
                if can_afford {
                    price_color = rl.GOLD
                } else {
                    price_color = rl.RED
                }
                if price_width > price_max_width {
                    rl.BeginScissorMode(i32(box_x + box_width - price_max_width - 25), i32(item_y + 25), i32(price_max_width), 25)
                    rl.DrawText(price_cstr, i32(box_x + box_width - price_max_width - 25), i32(item_y + 25), 20, price_color)
                    rl.EndScissorMode()
                } else {
                    rl.DrawText(price_cstr, i32(box_x + box_width - price_width - 25), i32(item_y + 25), 20, price_color)
                }
                
                y_offset += item_height + 10.0
            }
            
            rl.EndScissorMode()  // End clipping for items area
            
            // Instructions (larger) - with clipping to prevent overflow
            inst_text := "Press 1, 2, or 3 to buy | ESC to close"
            inst_cstr := strings.clone_to_cstring(inst_text, context.temp_allocator)
            inst_width := f32(rl.MeasureText(inst_cstr, 18))
            inst_max_width := box_width - 30.0
            if inst_width > inst_max_width {
                rl.BeginScissorMode(i32(box_x + 15), i32(box_y + box_height - 30), i32(inst_max_width), 25)
                rl.DrawText(inst_cstr, i32(box_x + box_width/2 - inst_width/2), i32(box_y + box_height - 30), 18, rl.GRAY)
                rl.EndScissorMode()
            } else {
                rl.DrawText(inst_cstr, i32(box_x + box_width/2 - inst_width/2), i32(box_y + box_height - 30), 18, rl.GRAY)
            }
            
            // NPC message (from Gemini API) - larger with word wrap and clipping
            msg_text := state.dialogue_ui.npc_response
            msg_cstr := strings.clone_to_cstring(msg_text, context.temp_allocator)
            msg_max_width := box_width - 30.0
            msg_text_width := f32(rl.MeasureText(msg_cstr, 20))
            msg_y := box_y + box_height - 80.0
            msg_max_height: f32 = 50.0  // Maximum height for message area (2 lines)
            
            // Use scissor mode to clip the entire message area
            rl.BeginScissorMode(i32(box_x + 15), i32(msg_y), i32(msg_max_width), i32(msg_max_height))
            
            // Simple word wrap: split by spaces and draw line by line
            msg_words := strings.split(msg_text, " ", context.temp_allocator)
            current_line := ""
            line_y := msg_y
            font_size: i32 = 20
            line_spacing: f32 = 25.0
            
            for word in msg_words {
                test_line := current_line
                if len(test_line) > 0 {
                    test_line = fmt.tprintf("%s %s", test_line, word)
                } else {
                    test_line = word
                }
                test_line_cstr := strings.clone_to_cstring(test_line, context.temp_allocator)
                test_width := f32(rl.MeasureText(test_line_cstr, font_size))
                
                if test_width > msg_max_width && len(current_line) > 0 {
                    // Draw current line and start new one
                    current_line_cstr := strings.clone_to_cstring(current_line, context.temp_allocator)
                    rl.DrawText(current_line_cstr, i32(box_x + 15), i32(line_y), font_size, rl.SKYBLUE)
                    current_line = word
                    line_y += line_spacing
                    if line_y > msg_y + msg_max_height do break  // Don't overflow message area
                } else {
                    current_line = test_line
                }
            }
            
            // Draw remaining line
            if len(current_line) > 0 && line_y <= msg_y + msg_max_height {
                current_line_cstr := strings.clone_to_cstring(current_line, context.temp_allocator)
                rl.DrawText(current_line_cstr, i32(box_x + 15), i32(line_y), font_size, rl.SKYBLUE)
            }
            
            rl.EndScissorMode()  // End clipping for message area
        } else {
            // Regular dialogue UI
            // NPC response
            if state.npc.is_loading {
                loading_text := "Thinking..."
                loading_cstr := strings.clone_to_cstring(loading_text, context.temp_allocator)
                rl.DrawText(loading_cstr, i32(box_x + 10), i32(box_y + 40), 16, rl.GRAY)
            } else {
                // Word wrap the response (simple version - split by newlines)
                response_lines := strings.split(state.dialogue_ui.npc_response, "\n", context.temp_allocator)
                y_offset: f32 = 40.0
                for line in response_lines {
                    if len(line) > 0 {
                        line_cstr := strings.clone_to_cstring(line, context.temp_allocator)
                        rl.DrawText(line_cstr, i32(box_x + 10), i32(box_y + y_offset), 16, rl.WHITE)
                    }
                    y_offset += 20.0
                    if y_offset > 180.0 do break  // Don't overflow
                }
            }
            
            // Player input box
            input_y := box_y + 200.0
            rl.DrawRectangle(i32(box_x + 10), i32(input_y), i32(box_width - 20), 30, rl.Color{40, 40, 50, 255})
            rl.DrawRectangleLines(i32(box_x + 10), i32(input_y), i32(box_width - 20), 30, rl.WHITE)
            
            // Player input text
            input_text := state.dialogue_ui.player_input
            if state.dialogue_ui.input_focused {
                input_text = fmt.tprintf("%s_", state.dialogue_ui.player_input)  // Cursor
            }
            input_cstr := strings.clone_to_cstring(input_text, context.temp_allocator)
            rl.DrawText(input_cstr, i32(box_x + 15), i32(input_y + 5), 16, rl.WHITE)
            
            // Instructions
            inst_text := "Press ENTER to send, ESC to close"
            inst_cstr := strings.clone_to_cstring(inst_text, context.temp_allocator)
            inst_width := f32(rl.MeasureText(inst_cstr, 12))
            rl.DrawText(inst_cstr, i32(box_x + box_width/2 - inst_width/2), i32(box_y + box_height - 25), 12, rl.GRAY)
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
        hp_text := fmt.tprintf("HP: %d/%d", state.player.hp, state.player.max_hp)
        hp_text_cstr := strings.clone_to_cstring(hp_text, context.temp_allocator)
        text_width := f32(rl.MeasureText(hp_text_cstr, 16))
        text_x := i32(bar_x + bar_width/2 - text_width/2)
        text_y := i32(bar_y + bar_height/2 - 10)
        rl.DrawText(hp_text_cstr, text_x, text_y, 20, rl.WHITE)
    }
    
    // Draw coins in top-right corner (below HP bar)
    {
        coins_text := fmt.tprintf("Coins: %d", state.player.coins)
        coins_cstr := strings.clone_to_cstring(coins_text, context.temp_allocator)
        text_width := f32(rl.MeasureText(coins_cstr, 18))
        coins_x := g.win_size.x - text_width - 20.0
        coins_y := 60.0
        rl.DrawText(coins_cstr, i32(coins_x), i32(coins_y), 18, rl.GOLD)
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
