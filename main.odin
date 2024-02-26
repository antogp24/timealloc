package main

import "core:fmt"
import "core:math"
import "core:time"

import rl "vendor:raylib"

screen_w, screen_h: f32
font: rl.Font
dt: f32
schedule: [24]cstring

// UTC-5 in my case
UTC_OFFSET :: -5

FONTSIZE :: 24
CLOCKSIZE :: 10
HOUR_RECT_W :: 125
HOUR_RECT_H :: 50
RECT_PADDING :: 2
WINDOW_PADDING_X :: 0
WINDOW_PADDING_Y :: 0

main :: proc() {
    initial_screen_w: i32 = 12*HOUR_RECT_W + 12*RECT_PADDING + WINDOW_PADDING_X
    initial_screen_h: i32 = 2*HOUR_RECT_H + 2*CLOCKSIZE + WINDOW_PADDING_Y
    rl.InitWindow(initial_screen_w, initial_screen_h, "timealloc")
    
    rl.SetWindowState({.WINDOW_RESIZABLE})
    defer rl.CloseWindow()
    
    font = rl.LoadFontEx("assets/Inter-Regular.ttf", FONTSIZE, nil, 0)
    number_w, number_h := get_number_dimentions()
    
    initial_screen_w += i32(2*number_w)
    initial_screen_h += i32(2*number_h)
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
            v1 := rl.Vector2{0.5, 1.0} * CLOCKSIZE - rl.Vector2{CLOCKSIZE/2, 0}
            v2 := rl.Vector2{1.0, 0.0} * CLOCKSIZE - rl.Vector2{CLOCKSIZE/2, 0}
            v3 := rl.Vector2{0.0, 0.0} * CLOCKSIZE - rl.Vector2{CLOCKSIZE/2, 0}

            pos: rl.Vector2
            pos.x = screen_w/2 - 6*(HOUR_RECT_W + RECT_PADDING)
            pos.y = screen_h/2 - HOUR_RECT_H

            if clock <= 12 {
                pos.x += clock * (HOUR_RECT_W + RECT_PADDING)
                pos.y -= CLOCKSIZE + number_h
            } else {
                pos.x += (clock - 12) * (HOUR_RECT_W + RECT_PADDING)
                pos.y += HOUR_RECT_H
            }
            rl.DrawTriangle(v1 + pos, v2 + pos, v3 + pos, rl.WHITE)
        }
        
        // Drawing the hour blocks
        for hour: f32; hour <= 24; hour += 1 {
            rect_pos: rl.Vector2

            // Splitting appart in two rows the hours of the day.
            if (hour < 12) { 
                rect_pos.x = screen_w/2 + (HOUR_RECT_W + RECT_PADDING)*(hour - 6)
                rect_pos.y = screen_h/2 - HOUR_RECT_H
            } else {
                rect_pos.x = screen_w/2 + (HOUR_RECT_W + RECT_PADDING)*(hour - 18)
                rect_pos.y = screen_h/2 + number_h + CLOCKSIZE
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
            
            // Draw 12 also on the first row.
            if (hour == 12) {
                text_pos := rl.Vector2{
                    screen_w/2 + HOUR_RECT_W*6 + RECT_PADDING*6,
                    screen_h/2 - HOUR_RECT_H - number_h/2,
                }            
                draw_text_centered(hour_text, text_pos)
            }
            
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
