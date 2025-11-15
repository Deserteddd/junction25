package aigame

import "core:fmt"
import "core:math/rand"
import "core:math"



// Directions (Indices for Tile_Sides array: N, E, S, W)
NORTH :: 0
EAST  :: 1
SOUTH :: 2
WEST  :: 3

Tile_Side :: enum {
    NONE,
    CITY,
    ROAD,
    FIELD,
}

Tile_Sides :: [4]Tile_Side; 

// --- Data Structures ---

Board_Position :: struct {
    x, y: i32,
}

// Grid_Cell is optimized to store only the prototype and the rotation index,
// saving memory compared to storing a full, rotated tile structure.
Grid_Cell :: struct {
    tile_proto:    ^Tile_Type, // Pointer to the original, unrotated prototype
    rotation:      i32,        // 0 to 3 (0=0deg, 1=90deg, 2=180deg, 3=270deg)
    is_occupied:   bool,
    is_available:  bool,       // Can a tile be placed next to an existing occupied tile?
}

// Tile_Type defines the unrotated blueprint of a tile piece
Tile_Type :: struct {
    name:     string,
    sides:    Tile_Sides,
    color:    [4]u8, // R, G, B, A for raylib visualization
}

Board :: struct {
    cells:        map[Board_Position]Grid_Cell,
    tile_prototypes: [dynamic]Tile_Type, // All possible tile types
    center_pos:   Board_Position,
    room_type:    i32,  // Room type index (0-6 for castle themes)
}

// Struct to track a successful placement option during the loop
Valid_Placement :: struct {
    tile_prototype: ^Tile_Type,
    rotation_count: i32,
}

// --- Core Generation Procedures ---

// Rotates the four sides of a tile 90 degrees clockwise (CW).
rotate_sides_clockwise :: proc(original_sides: Tile_Sides) -> Tile_Sides {
    rotated_sides: Tile_Sides;

    rotated_sides[NORTH] = original_sides[WEST]; 
    rotated_sides[EAST]  = original_sides[NORTH]; 
    rotated_sides[SOUTH] = original_sides[EAST]; 
    rotated_sides[WEST]  = original_sides[SOUTH]; 

    return rotated_sides;
}

// Calculates the sides of a Tile_Type given its rotation count (0-3).
get_rotated_sides :: proc(tile_proto: ^Tile_Type, rotations: i32) -> Tile_Sides {
    current_sides := tile_proto.sides;
    
    // Fix: Explicitly declare i as i32 to match rotations type
    for i: i32 = 0; i < rotations; i += 1 {
        current_sides = rotate_sides_clockwise(current_sides);
    }
    
    return current_sides;
}

// Check if two tile sides can connect (must match exactly).
can_connect :: proc(side1: Tile_Side, side2: Tile_Side) -> bool {
    // NONE can connect to anything if the neighbor is empty, but if the neighbor 
    // is occupied, we must ensure the boundaries align (e.g., Road to Road).
    return side1 == side2
}

// Gets the side of the tile already placed in the neighbor cell,
// which is facing the position we are trying to fill.
get_neighbor_side :: proc(board: ^Board, pos: Board_Position, dx: i32, dy: i32) -> Tile_Side {
    neighbor_pos := Board_Position{pos.x + dx, pos.y + dy}
    cell, ok := board.cells[neighbor_pos]
    
    // If neighbor is empty or not in the map, assume FIELD boundary (or NONE)
    if !ok || !cell.is_occupied {
        return .FIELD // Treat empty areas as Field to allow new tiles to connect to the void
    }

    // Determine the side of the neighbor tile facing our new position:
    rotated_sides := get_rotated_sides(cell.tile_proto, cell.rotation)
    
    if dx == 1 { return rotated_sides[WEST] } // New tile is East of neighbor -> check neighbor's West side
    if dx == -1 { return rotated_sides[EAST] } // New tile is West of neighbor -> check neighbor's East side
    if dy == 1 { return rotated_sides[NORTH] } // New tile is South of neighbor -> check neighbor's North side
    if dy == -1 { return rotated_sides[SOUTH] } // New tile is North of neighbor -> check neighbor's South side

    return .NONE // Should not happen
}

// Checks if a *rotated* tile's sides align with all occupied neighbors.
is_placement_valid :: proc(board: ^Board, pos: Board_Position, rotated_sides: Tile_Sides) -> bool {
    // Check North neighbor
    if !can_connect(rotated_sides[NORTH], get_neighbor_side(board, pos, 0, -1)) { return false }
    // Check East neighbor
    if !can_connect(rotated_sides[EAST], get_neighbor_side(board, pos, 1, 0)) { return false }
    // Check South neighbor
    if !can_connect(rotated_sides[SOUTH], get_neighbor_side(board, pos, 0, 1)) { return false }
    // Check West neighbor
    if !can_connect(rotated_sides[WEST], get_neighbor_side(board, pos, -1, 0)) { return false }

    return true
}

// Places a tile and updates the availability of neighboring empty spaces.
place_tile :: proc(board: ^Board, pos: Board_Position, placement: Valid_Placement) {
    
    // 1. Place the tile (store prototype pointer and rotation)
    // Create or update the cell in the map directly (don't take address of map value)
    board.cells[pos] = Grid_Cell{
        tile_proto = placement.tile_prototype,
        rotation = placement.rotation_count,
        is_occupied = true,
        is_available = false,
    }

    // 2. Update neighboring empty cells to 'available' (if they don't exist yet)
    neighbor_offsets := [4]Board_Position{
        {0, -1}, {1, 0}, {0, 1}, {-1, 0}, 
    }

    for offset in neighbor_offsets {
        neighbor_pos := Board_Position{pos.x + offset.x, pos.y + offset.y}
        
        // If the neighbor position is not yet in the map (or is marked as occupied/not available)
        neighbor_cell, ok := board.cells[neighbor_pos]
        if !ok || (!neighbor_cell.is_occupied && !neighbor_cell.is_available) {
            
            // Mark the new empty cell as a place where a tile *can* be placed
            board.cells[neighbor_pos] = Grid_Cell{
                tile_proto = nil,
                rotation = 0,
                is_occupied = false,
                is_available = true,
            }
        }
    }
}

// Initializes the tile prototypes for the game.
// These are unrotated blueprints.
init_prototypes :: proc() -> [dynamic]Tile_Type {
    prototypes: [dynamic]Tile_Type
    
    // R, G, B, A
    city_color  := [4]u8{100, 100, 100, 255} // Gray
    road_color  := [4]u8{150, 75, 0, 255}   // Brown
    field_color := [4]u8{50, 200, 50, 255}  // Green

    // 1. Starter Tile (City on one side)
    append(&prototypes, Tile_Type{
        name = "Start/City End",
        sides = {.CITY, .FIELD, .FIELD, .FIELD},
        color = city_color,
    })

    // 2. Straight Road Tile
    append(&prototypes, Tile_Type{
        name = "Straight Road",
        sides = {.ROAD, .FIELD, .ROAD, .FIELD},
        color = road_color,
    })

    // 3. Corner Road Tile
    append(&prototypes, Tile_Type{
        name = "Corner Road",
        sides = {.FIELD, .ROAD, .ROAD, .FIELD},
        color = road_color,
    })
    
    // 4. City Corner Tile
    append(&prototypes, Tile_Type{
        name = "City Corner",
        sides = {.CITY, .CITY, .FIELD, .FIELD},
        color = city_color,
    })
    
    // 5. All Field Tile
    append(&prototypes, Tile_Type{
        name = "All Field",
        sides = {.FIELD, .FIELD, .FIELD, .FIELD},
        color = field_color,
    })

    return prototypes
}

// Main map generation function
generate_room :: proc(max_tiles: i32) -> Board {
    
    board: Board
    
    // Initialize the prototypes
    board.tile_prototypes = init_prototypes()
    
    // Assign room type based on max_tiles (used to cycle through room types)
    NUM_ROOM_TYPES :: 7  // Match the constant from main.odin
    board.room_type = i32(max_tiles % NUM_ROOM_TYPES)
    
    // Setup the starting position
    board.center_pos = {0, 0}
    
    // 1. Initialize the board with the starting tile (Prototype 1)
    start_pos := board.center_pos
    start_proto := &board.tile_prototypes[0]
    
    place_tile(&board, start_pos, Valid_Placement{
        tile_prototype = start_proto, 
        rotation_count = 0,
    })
    
    current_tile_count: i32 = 1
    
    // 2. The Main Loop
    for current_tile_count < max_tiles {
        
        // Find all currently available placement positions
        available_positions: [dynamic]Board_Position
        defer delete(available_positions) // Clean up temp array
        
        for pos, cell in board.cells {
            if cell.is_available {
                append(&available_positions, pos)
            }
        }

        if len(available_positions) == 0 {
            fmt.println("Map generation stuck: No more valid placement spots.")
            break
        }

        // a. Select a position to place the next tile
        // Choose the first available position (deterministic) to avoid the undefined rand.int_range
        chosen_pos := available_positions[0]

        // b. Find all valid tiles (and rotations) for that position
        valid_placements: [dynamic]Valid_Placement
        defer delete(valid_placements) // Clean up temp array
        
        // Fix: Iterate by pointer (&tile_proto) to allow taking the address later
        for &tile_proto, i in board.tile_prototypes {
            // Fix: Explicitly declare rot as i32
            for rot: i32 = 0; rot < 4; rot += 1 {
                
                rotated_sides := get_rotated_sides(&tile_proto, rot);

                if is_placement_valid(&board, chosen_pos, rotated_sides) { 
                    
                    append(&valid_placements, Valid_Placement{
                        tile_prototype = &tile_proto, 
                        rotation_count = rot,
                    })
                }
            }
        }

        // c. Place the chosen tile or mark the spot as a dead end
        if len(valid_placements) > 0 {
            // Select the first valid placement (deterministic) to avoid the undefined rand.int_range
            chosen_placement := valid_placements[0]
            
            place_tile(&board, chosen_pos, chosen_placement)
            current_tile_count += 1
            
        } else {
            // Fix: To modify a map value, get a pointer/reference to the cell and modify it.
            cell_ptr := &board.cells[chosen_pos]
            cell_ptr.is_available = false
        }
    }
    
    fmt.printf("Map generation finished. Total tiles placed: %d\n", current_tile_count)
    return board
}