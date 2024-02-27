package main

import "core:fmt"
import "core:math"
import "core:time"

import rl "vendor:raylib"

screen_w, screen_h: f32
font: rl.Font
dt: f32

// UTC-5 in my case
UTC_OFFSET :: -5

FONTSIZE :: 24
CLOCKSIZE :: 10
HOUR_RECT_W :: 150
HOUR_RECT_H :: 50
RECT_PADDING :: 1
WINDOW_PADDING_X :: 0
WINDOW_PADDING_Y :: 0

main :: proc() {
    initial_screen_w: i32 = 6 * (HOUR_RECT_W + RECT_PADDING) + WINDOW_PADDING_X
    initial_screen_h: i32 = HOUR_RECT_H + CLOCKSIZE + WINDOW_PADDING_Y
    rl.InitWindow(initial_screen_w, initial_screen_h, "timealloc")
    
    rl.SetWindowState({.WINDOW_RESIZABLE})
    defer rl.CloseWindow()
    
    font = rl.LoadFontEx("assets/Inter-Regular.ttf", FONTSIZE, nil, 0)
    number_w, number_h := get_number_dimentions()
    
    initial_screen_w += i32(number_w)
    initial_screen_h += i32(number_h)
    rl.SetWindowSize(initial_screen_w, initial_screen_h)

    for !rl.WindowShouldClose() {
        dt = rl.GetFrameTime()
        screen_w = cast(f32)rl.GetScreenWidth()
        screen_h = cast(f32)rl.GetScreenHeight()

        clock := get_current_hour()

        rl.ClearBackground(rl.BLACK)
        rl.BeginDrawing()

        // Drawing the clock
        {
            v1 := (rl.Vector2{0.5, 1} - rl.Vector2{.5, 0}) * CLOCKSIZE
            v2 := (rl.Vector2{1.0, 0} - rl.Vector2{.5, 0}) * CLOCKSIZE
            v3 := (rl.Vector2{0.0, 0} - rl.Vector2{.5, 0}) * CLOCKSIZE
            
            pos := rl.Vector2{clock * (HOUR_RECT_W + RECT_PADDING*.75) + number_w/2, 0}
            rl.DrawLineV(rl.Vector2{pos.x, 0}, rl.Vector2{pos.x, screen_h}, rl.Color{255, 255, 255, 100})
            rl.DrawTriangle(v1 + pos, v2 + pos, v3 + pos, rl.GREEN)
        }
        
        // Drawing the hour blocks
        for hour: f32; hour <= 24; hour += 1 {

            rect_pos := rl.Vector2{
                (HOUR_RECT_W + RECT_PADDING) * hour + number_w/2,
                number_h + CLOCKSIZE,
            }
            
            rect := rl.Rectangle{rect_pos.x, rect_pos.y, HOUR_RECT_W, HOUR_RECT_H}
            h, s, v: f32
            x := hour / 24
            // Dynamically getting the color value based on the hour.
            {
                using math
                h = (sin(PI*x - PI/2)*.5 + .5) * 180
                s = .8 + sin(x)*.2 
                v = sin(2*PI*x - PI/2)*.4 + .5
            }
            if (hour < 24) do rl.DrawRectangleRounded(rect, 0.25, 10, rl.ColorFromHSV(h, s, v))
            
            // Draw text at the top of the block
            hour_text := rl.TextFormat("%i", cast(i32)hour)
            text_pos := rect_pos + rl.Vector2{0, -number_h/2}
            draw_text_centered(hour_text, text_pos)
            
            // Draw lines to indicate half and quarter an hour.
            for i in 0..<4 {
                if hour == 24 do break
                if i == 0 do continue
                start := rect_pos + rl.Vector2{cast(f32)i*HOUR_RECT_W*0.25, 0}
                end := start - rl.Vector2{0, number_h/2}
                rl.DrawLineEx(start, end, 1, rl.WHITE)
            }
        }
        rl.EndDrawing()
    }
}

get_current_hour :: proc() -> f32 {
    t := time.now()
    t = time.time_add(t, UTC_OFFSET*time.Hour)
    h, m, s := time.clock_from_time(t)
    hours, minutes, seconds := f32(h), f32(m), f32(s)
    return hours + minutes/60 + seconds/3600
}

get_number_dimentions :: proc() -> (f32, f32) {
    measure := rl.MeasureTextEx(font, "0", FONTSIZE, 0)
    return measure.x, measure.y
} 

draw_text_centered :: proc(text: cstring, pos: rl.Vector2, color := rl.WHITE) {
    spacing :: 0
    measure := rl.MeasureTextEx(font, text, FONTSIZE, spacing)
    rl.DrawTextEx(font, text, pos - measure/2, FONTSIZE, spacing, color)
}
