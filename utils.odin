package main

import "core:fmt"
import "core:time"
import "core:math"
import "core:strings"
import rl "vendor:raylib"

append_timeblock :: proc(layer: int, start, duration: f32) {
    t: TimeBlock
    t.start = start
    t.duration = duration
    t.text = strings.builder_make()
    append(&timeblocks[layer], t)
}

hours_to_hms :: proc(hours: f32) -> (h, m, s: f32) {
    whole := f32(int(hours))
    decimal := hours - f32(int(hours))

    h = whole
    m = f32(int(decimal * 60))
    s = ((decimal * 60) - m) * 60
    return h, m, s
}

hms_to_hours :: proc(h, m, s: f32) -> (hours: f32) {
    return h + m/60 + s/3600
}

timeblock_cstring :: proc(using t: ^TimeBlock) -> cstring {
    return cstring(raw_data(text.buf[:]))
}

get_text_offset :: proc(text: cstring, cursor: int) -> (offset: f32) {
    if font.texture.id == 0 || text == nil || cursor == 0 {
        return 0
    }
    ctext := transmute([^]u8)text
    
    for i := 0; i < cursor; {
        if ctext[i] == 0 do break

        next: i32
        letter := rl.GetCodepointNext(auto_cast &ctext[i], &next)
        index := rl.GetGlyphIndex(font, letter)
        i += int(next);

        if font.chars[index].advanceX != 0 {
            offset += auto_cast font.chars[index].advanceX
        } else {
            offset += font.recs[index].width + auto_cast font.chars[index].offsetX
        }
    }
    return offset
}

goto_hour :: proc(hour: int) {
    cam.target.x = f32(hour) * HOUR_RECT_W
}

square_wave :: proc (x, period: f32) -> bool {
    using math
    result := -floor(sin(x * PI / period))
    return bool(int(result))
}

timer_update :: proc(key: rl.KeyboardKey) {
    if rl.IsKeyDown(key) {
        keytimers[key] += dt
    } else {
        keytimers[key] = 0
    }
}

key_is_pressed_or_down :: proc(pressed, key: rl.KeyboardKey, threshold: f32 = 0.3) -> bool {
    return pressed == key || (keytimers[key] > threshold && square_wave(keytimers[key], 0.015))
}

get_current_hour :: proc() -> f32 {
    t := time.now()
    t = time.time_add(t, UTC_OFFSET*time.Hour)
    h, m, s := time.clock_from_time(t)
    return hms_to_hours(f32(h), f32(m), f32(s))
}

get_layer_dimentions :: proc() -> (f32, f32) {
    return 24*HOUR_RECT_W, HOUR_RECT_H + CLOCKSIZE + number_h
}

get_text_dimentions :: proc(text: cstring) -> (f32, f32) {
    measure := rl.MeasureTextEx(font, text, FONTSIZE, 0)
    return measure.x, measure.y
} 

get_number_dimentions :: proc() -> (f32, f32) {
    measure := rl.MeasureTextEx(font, "0", FONTSIZE, 0)
    return measure.x, measure.y
} 

render_text :: proc(text: cstring, pos: rl.Vector2, color := rl.WHITE) {
    rl.DrawTextEx(font, text, pos, FONTSIZE, 0, color)
}

render_text_centered :: proc(text: cstring, pos: rl.Vector2, color := rl.WHITE) {
    spacing :: 0
    measure := rl.MeasureTextEx(font, text, FONTSIZE, spacing)
    rl.DrawTextEx(font, text, pos - measure/2, FONTSIZE, spacing, color)
}

get_mouse_layer :: proc(mpos, offset: rl.Vector2) -> int {
    mlayer := -1
    layer_y: [N_LAYERS]f32
    for i in 0..<N_LAYERS {
    	layer_y[i] = (number_h + CLOCKSIZE) * f32(i + 1) + HOUR_RECT_H * f32(i) + offset.y

        if mpos.y >= layer_y[i] && mpos.y <= layer_y[i] + HOUR_RECT_H {
        	mlayer = i
        	break
        }
    }
    return mlayer
}

is_mouse_on_hour_block :: proc(mpos_world_x: f32, mlayer: int) -> bool {
    return (mpos_world_x >= number_w && mpos_world_x <= number_w + layer_w) && mlayer != -1
}
