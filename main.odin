package main

import "core:fmt"
import "core:math"
import "core:strings"
import "core:time"
import rl "vendor:raylib"

MouseTimeSpan :: struct {start, end: f32, registering: bool}
Active :: struct {layer, block: int}
Time :: struct {hours, minutes, seconds: int}

TimeBlock :: struct {
    start, duration: f32,
    text: strings.Builder,
    cursor: int,
}

FONTSIZE :: 24
CLOCKSIZE :: 10
HOUR_RECT_W :: 500
HOUR_RECT_H :: 50
N_LAYERS :: 4
UTC_OFFSET :: -5

screen_w, screen_h: f32
layer_w, layer_h: f32
number_w, number_h: f32
timeblocks: [N_LAYERS][dynamic]TimeBlock
active := Active{-1, -1}
mousetime: MouseTimeSpan
clock: f32
font: rl.Font
cam: rl.Camera2D
elapsedtime: f64
dt: f32

keytimers := map[rl.KeyboardKey]f32 {
    .BACKSPACE = 0,
    .ENTER     = 0,
    .UP        = 0,
    .DOWN      = 0,
    .LEFT      = 0,
    .RIGHT     = 0,
}

main :: proc() {
    initial_screen_w: i32 = 2 * HOUR_RECT_W
    initial_screen_h: i32 = (HOUR_RECT_H + CLOCKSIZE) * N_LAYERS
    rl.SetTargetFPS(60)
    rl.InitWindow(initial_screen_w, initial_screen_h, "timealloc")
    defer rl.CloseWindow()

    rl.SetWindowState({.WINDOW_RESIZABLE})
    rl.SetExitKey(.KEY_NULL)
    cam.zoom = 1.0
    
    font = rl.LoadFontEx("assets/Inter-Regular.ttf", FONTSIZE, nil, 0)
    number_w, number_h = get_number_dimentions()
    layer_w, layer_h = get_layer_dimentions()
    
    initial_screen_w += i32(number_w)
    initial_screen_h += i32(number_h * N_LAYERS)
    rl.SetWindowSize(initial_screen_w, initial_screen_h)
    
    for !rl.WindowShouldClose() {
        elapsedtime = rl.GetTime()
        dt = rl.GetFrameTime()
        screen_w = cast(f32) rl.GetScreenWidth()
        screen_h = cast(f32) rl.GetScreenHeight()
        clock = get_current_hour()
        
        center_offset: rl.Vector2
        if screen_h > N_LAYERS*layer_h {
            center_offset.y = screen_h/2 - N_LAYERS*layer_h/2
        }

        // Moving the camera
        if mv := rl.GetMouseWheelMove(); mv != 0 {
            cam.target.x  += mv * HOUR_RECT_W * 0.25
        }
        if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyDown(.A) {
            goto_hour(0)
        }
        if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyDown(.E) {
            goto_hour(23)
        }
        if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyDown(.D) {
            goto_hour(auto_cast clock)
        }
        cam.target.x = clamp(cam.target.x, 0, 24*HOUR_RECT_W)
        
        if rl.IsKeyPressed(.ESCAPE) {
            reset_all_active_timeblocks()
        }
        // Typing in the textboxes
        if active.layer != -1 && active.block != -1 {
            for key in keytimers {
                timer_update(key, dt)
            }
            key := rl.GetKeyPressed()
            chr := rl.GetCharPressed()
            block := &timeblocks[active.layer][active.block]
            using block

            // Typing
            holding_modifiers := rl.IsKeyDown(.LEFT_ALT) || rl.IsKeyDown(.LEFT_CONTROL)
            if (chr >= ' ' && chr <= '~') && !holding_modifiers {
                inject_at(&text.buf, cursor, u8(chr))
                cursor += 1
            }

            // Text Editing
            if key_is_pressed_or_down(key, .DOWN) {
                cursor = len(text.buf) - 1

            } else if key_is_pressed_or_down(key, .UP) {
                cursor = 0

            } else if key_is_pressed_or_down(key, .LEFT) {
                if rl.IsKeyDown(.LEFT_CONTROL) {
                    for cursor > 0 && len(text.buf) > 0 {
                        cursor -= 1
                        cursor = max(cursor, 0)
                        if cursor == 0 do break
                        c := text.buf[cursor - 1] 
                        if c == ' ' || c == '_' || c == ';' || c == ',' || c == 0 {
                            break
                        }
                    }
                } else {
                    cursor -= 1
                    cursor = max(cursor, 0)
                }

            } else if key_is_pressed_or_down(key, .RIGHT) {
                if rl.IsKeyDown(.LEFT_CONTROL) {
                    for {
                        cursor += 1
                        cursor = min(cursor, len(text.buf) - 1)
                        if cursor == len(text.buf) - 1 do break
                        c := text.buf[cursor + 1] 
                        if c == ' ' || c == '_' || c == ';' || c == ',' || c == 0 {
                            cursor += 1
                            cursor = min(cursor, len(text.buf) - 1)
                            break
                        }
                    }
                } else {
                    cursor += 1
                    cursor = min(cursor, len(text.buf) - 1)
                }

            } else if key_is_pressed_or_down(key, .BACKSPACE) {
                if rl.IsKeyDown(.LEFT_CONTROL) {
                    for cursor > 0 && len(text.buf) > 0 {
                        if len(text.buf) > 0 {
                            cursor -= 1
                            cursor = max(cursor, 0)
                            if text.buf[cursor] != 0 {
                                ordered_remove(&text.buf, cursor)
                            }
                        }
                        if cursor == 0 do break
                        c := text.buf[cursor - 1] 
                        if c == ' ' || c == '_' || c == ';' || c == ',' || c == 0 {
                            break
                        }
                    }
                } else if len(text.buf) > 0 {
                    cursor -= 1
                    cursor = max(cursor, 0)
                    if text.buf[cursor] != 0 {
                        ordered_remove(&text.buf, cursor)
                    }
                }
            }
        }
        
        // Mouse interaction
        mpos := rl.GetMousePosition()
        mpos_world := rl.GetScreenToWorld2D(mpos, cam)
        mlayer := get_mouse_layer(mpos, center_offset)
        mouse_on_hour_block := is_mouse_on_hour_block(mpos_world.x, mlayer)
        
        if rl.IsMouseButtonPressed(.LEFT) && !mouse_on_hour_block {
            reset_all_active_timeblocks()
        }       
        
        if mouse_on_hour_block {
            // snapping the mouse position to minutes
            x := mpos_world.x - number_w
            t := f32(HOUR_RECT_W / 60)
            pos := t * math.floor(x / t)
            
            if rl.IsMouseButtonPressed(.LEFT) {
                mousetime.start = math.ceil(60*pos / HOUR_RECT_W)
                
                collided := get_collided_timeblock(mlayer, mpos, center_offset, 0)
                mousetime.registering = (collided == -1)
                reset_all_active_timeblocks()
                
            } else if rl.IsMouseButtonReleased(.LEFT) {
                mousetime.end = math.ceil(60*pos / HOUR_RECT_W)
                
                collided := get_collided_timeblock(mlayer, mpos, center_offset, 0)
                if mousetime.registering do mousetime.registering = (collided == -1)
                
                if mousetime.start != mousetime.end && mousetime.registering {
                    // Swapping if needed.
                    if mousetime.start > mousetime.end {
                        using mousetime
                        start, end = end, start
                    }
                    
                    start := mousetime.start / 60
                    duration := (mousetime.end - mousetime.start) / 60
                    append_timeblock(mlayer, start, duration)
                    last  := len(timeblocks[mlayer]) - 1
                    strings.write_byte(&timeblocks[mlayer][last].text, 0)
                    
                    active.layer = mlayer
                    active.block = last
                    
                } else if collided != -1 {
                    active.layer = mlayer
                    active.block = collided
                }
            }
        }

        rl.ClearBackground(rl.BLACK)
        rl.BeginDrawing()

        // Cursor HUD background
        for layer in 0..<N_LAYERS {
            color: rl.Color = {45, 135, 45, 255} if layer == active.layer else {35, 35, 85, 255}
            pos := rl.Vector2{0, f32(layer) * layer_h} + center_offset
            rl.DrawRectangleV(pos, {screen_w, CLOCKSIZE}, color)
        }
        
        rl.BeginMode2D(cam)
        
        for layer in 0..<N_LAYERS {
            render_clock(layer, center_offset)
            render_layer(layer, center_offset)
        }

        rl.EndMode2D()

        // Drawing time blocks textboxes
        for layer in 0..<N_LAYERS {
            render_timeblocks(layer, center_offset)
        }

        rl.EndDrawing()
    }
}

render_clock :: proc(layer: int, offset: rl.Vector2) {
    pos := rl.Vector2{clock * HOUR_RECT_W + number_w, layer_h * f32(layer)}

    if layer == 0 do rl.DrawLineV({pos.x, 0}, {pos.x, screen_h}, {255, 255, 255, 100})

    v1: rl.Vector2 = ({0.5, 1} - {.5, 0}) * CLOCKSIZE + pos + offset
    v2: rl.Vector2 = ({1.0, 0} - {.5, 0}) * CLOCKSIZE + pos + offset
    v3: rl.Vector2 = ({0.0, 0} - {.5, 0}) * CLOCKSIZE + pos + offset
    
    rl.DrawTriangle(v1, v2, v3, rl.GREEN)
}

render_layer :: proc(layer: int, offset: rl.Vector2) {
    for hour in f32(0)..<24 {
        
        rect_pos := rl.Vector2{
            HOUR_RECT_W * hour + number_w,
            (number_h + CLOCKSIZE) * f32(layer + 1) + HOUR_RECT_H * f32(layer),
        }
        rect_pos += offset
        
        rect := rl.Rectangle{rect_pos.x, rect_pos.y, HOUR_RECT_W, HOUR_RECT_H}
        h, s, v, a: f32

        // Dynamically getting the color value based on the hour.
        x := hour / 23
        {
            using math
            h = (sin(PI*x - PI/2)*.5 + .5) * (280 - 150) + 150 // From 150 to 280
            s = cos(2*PI*x)*.25 + .75
            v = cos(2*PI*x - PI)*.35 + .65
            a = cos(2*PI*x - PI)*.20 + .80
        }
        color := rl.ColorAlpha(rl.ColorFromHSV(h, s, v), a)
        rl.DrawRectangleRounded(rect, 0.25, 10, color)

        // Padding for the cursor background.
        {
            thick :: 4
            start := rect_pos - {0, number_h + CLOCKSIZE}
            end := start + {0, CLOCKSIZE}
            rl.DrawLineEx(start, end, thick, rl.BLACK)
            
            if hour == 23 {
                start += {HOUR_RECT_W, 0}
                end := start + {0, CLOCKSIZE}
                rl.DrawLineEx(start, end, thick, rl.BLACK)
            }
        }

        // Padding between the hours.
        {
            thick :: 2
            start := rect_pos
            end := start + {0, HOUR_RECT_H}
            rl.DrawLineEx(start, end, thick, rl.BLACK)
        }
        
        // Draw text at the top of the block
        hour_text := rl.TextFormat("%i", i32(hour))
        text_pos := rect_pos + rl.Vector2{0, -number_h/2}
        render_text_centered(hour_text, text_pos)

        // Draw the number 24
        if hour == 23 {
            hour_text := rl.TextFormat("%i", 24)
            text_pos := rect_pos + rl.Vector2{HOUR_RECT_W, -number_h/2}
            render_text_centered(hour_text, text_pos)
        }
        
        // Draw lines to indicate half and quarter an hour.
        for i in 1..<4 {
            start := rect_pos + {0.25*f32(i)*HOUR_RECT_W, 0}
            end := start - {0, number_h/2}
            rl.DrawLineEx(start, end, 1, rl.WHITE)
        }
        
        // Draw lines to indicate every one minute
        for i in 0..=60 {
            start := rect_pos + {f32(i*HOUR_RECT_W)/60, 0}
            end := start - {0, number_h/4}
            rl.DrawLineEx(start, end, 1, {255, 255, 255, 150})
        }
    }
}

render_timeblocks :: proc(layer: int, offset: rl.Vector2) {
    for _, i in timeblocks[layer] {
        text := timeblock_cstring(&timeblocks[layer][i])
        text_w, text_h := get_text_dimentions(text)
        
        is_active := (active.block == i && active.layer == layer)
        cursor := timeblocks[layer][i].cursor
        
        color: rl.Color = {13, 13, 200, 200} if is_active else {13, 13, 13, 200}
        
        rect := get_timeblock_rect(layer, i, offset, HOUR_RECT_H/4)
        rl.DrawRectangleRounded(rect, .25, 50, color)

        rect_center := rl.Vector2{rect.x + rect.width/2, rect.y + rect.height/2}
        render_text_centered(text, rect_center)
        
        if is_active {
            offset := get_text_offset(text, cursor)
            cursor_pos: rl.Vector2 = rect_center + {offset - text_w/2, 0}
            cursor_h := rect.height - 10
            
            start: rl.Vector2 = cursor_pos - {0, cursor_h/2}
            end:   rl.Vector2 = cursor_pos + {0, cursor_h/2}
            
            // Blinking cursor
            alpha := f32(1)//f32(math.cos(math.PI*f32(elapsedtime)) + 1) / 2
            rl.DrawLineEx(start, end, 2, rl.ColorAlpha(rl.GREEN, alpha)) 
        }
    }
}

get_timeblock_rect_from_existing :: proc(layer, i: int, offset: rl.Vector2, empty_space: f32) -> rl.Rectangle {
    start := timeblocks[layer][i].start
    duration := timeblocks[layer][i].duration

    rect_pos := rl.Vector2{
        number_w + start * HOUR_RECT_W,
        number_h + CLOCKSIZE + layer_h * f32(layer) + empty_space,
    }
    rect_pos += offset - cam.target

    rect := rl.Rectangle{
        rect_pos.x,
        rect_pos.y,
        duration * HOUR_RECT_W,
        HOUR_RECT_H - 2*empty_space,
    }
    return rect
}

get_timeblock_rect_from_new :: proc(layer: int, start, duration: f32, offset: rl.Vector2, empty_space: f32) -> rl.Rectangle {
    rect_pos := rl.Vector2{
        number_w + start * HOUR_RECT_W,
        number_h + CLOCKSIZE + layer_h * f32(layer) + empty_space,
    }
    rect_pos += offset - cam.target

    rect := rl.Rectangle{
        rect_pos.x,
        rect_pos.y,
        duration * HOUR_RECT_W,
        HOUR_RECT_H - 2*empty_space,
    }
    return rect
}

get_timeblock_rect :: proc{get_timeblock_rect_from_existing, get_timeblock_rect_from_new}

get_collided_timeblock_pos :: proc(layer: int, pos, offset: rl.Vector2, empty_space: f32) -> int {
    collided := -1
    for _, i in timeblocks[layer] {
        rect := get_timeblock_rect(layer, i, offset, empty_space)
        if rl.CheckCollisionPointRec(pos, rect) {
            collided = i
            break
        }
    }
    return collided
}

get_collided_timeblock_rect :: proc(layer: int, rect: rl.Rectangle, offset: rl.Vector2, empty_space: f32) -> int {
    collided := -1
    for _, i in timeblocks[layer] {
        rect_ := get_timeblock_rect(layer, i, offset, empty_space)
        if rl.CheckCollisionRecs(rect, rect_) {
            collided = i
            break
        }
    }
    return collided
}

get_collided_timeblock :: proc{get_collided_timeblock_pos, get_collided_timeblock_rect}

reset_all_active_timeblocks :: proc() {
    active.layer = -1
    active.block = -1
}

timealloc :: proc(start, end: Time, offset: rl.Vector2) -> (success: bool) {
    start_hour := hms_to_hours(auto_cast start.hours, auto_cast start.minutes, auto_cast start.seconds)
    end_hour := hms_to_hours(auto_cast end.hours, auto_cast end.minutes, auto_cast end.seconds)
    if start_hour > end_hour do start_hour, end_hour = end_hour, start_hour

    duration := end_hour - start_hour

    layer: int
    for layer = 0; layer <= N_LAYERS; layer += 1 {
        if layer == N_LAYERS do break
        rect := get_timeblock_rect(layer, start_hour, duration, offset, 0)
        collided := get_collided_timeblock(layer, rect, offset, 0)
        if collided == -1 do break
    }
    if layer == N_LAYERS do return false

    append_timeblock(layer, start_hour, duration)
    last := len(timeblocks[layer]) - 1
    strings.write_byte(&timeblocks[layer][last].text, 0)
    return true
}
