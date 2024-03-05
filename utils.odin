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
    last := len(timeblocks[layer]) - 1
    strings.write_byte(&timeblocks[layer][last].text, 0)
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

goto_hour :: proc(hour: int) {
    cam.target.x = f32(hour) * HOUR_RECT_W
}

square_wave :: proc(x, period: f32) -> bool {
    result := -math.floor(math.sin(x * math.PI / period))
    return bool(int(result))
}

timer_update :: proc(key: rl.KeyboardKey, dt: f32) {
    if rl.IsKeyDown(key) {
        keytimers[key] += dt
    } else {
        keytimers[key] = 0
    }
}

key_is_pressed_or_down :: proc(pressed, key: rl.KeyboardKey, threshold: f32 = 0.3) -> bool {
    timer := keytimers[key]
    return pressed == key || (timer > threshold && square_wave(timer, 0.015))
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

get_text_dimentions :: proc(text: cstring, size: int, font := font, fontsize: f32 = FONTSIZE) -> (w, h: f32) {
    size := size
    if font.texture.id == 0 || text == nil do return

    if size <= 0 do size = cast(int)rl.TextLength(text)
    scaleFactor := fontsize / cast(f32)font.baseSize
    ctext := transmute([^]u8)text
    next: i32

    for i := 0; i < size; i += int(next) {
        letter := rl.GetCodepointNext(cast(cstring)&ctext[i], &next)
        index := rl.GetGlyphIndex(font, letter)

	if (font.chars[index].advanceX != 0) {
	    w += cast(f32)font.chars[index].advanceX
	} else {
	    w += font.recs[index].width + cast(f32)font.chars[index].offsetX
	}
    }

    w *= scaleFactor
    h = fontsize

    return w, h
} 

get_number_dimentions :: proc(font := font, fontsize: f32 = FONTSIZE) -> (f32, f32) {
    measure := rl.MeasureTextEx(font, "0", fontsize, 0)
    return measure.x, measure.y
} 

get_text_offset :: proc(text: cstring, cursor: int, font := font, fontsize: f32 = FONTSIZE) -> (offset: f32) {
    if font.texture.id == 0 || text == nil || cursor == 0 {
        return 0
    }
    ctext := transmute([^]u8)text
    next: i32
    
    for i := 0; i < cursor; i += int(next) {
        if ctext[i] == 0 do break

        letter := rl.GetCodepointNext(cast(cstring)&ctext[i], &next)
        index := rl.GetGlyphIndex(font, letter)

        if font.chars[index].advanceX != 0 {
            offset += cast(f32)font.chars[index].advanceX
        } else {
            offset += font.recs[index].width + cast(f32)font.chars[index].offsetX
        }
    }
    return offset
}

render_text :: proc(text: cstring, size: int, pos: rl.Vector2, font := font, fontsize: f32 = FONTSIZE, tint := rl.WHITE) {
    font, size := font, size
    if font.texture.id == 0 do font = rl.GetFontDefault()

    if size <= 0 do size = cast(int)rl.TextLength(text)
    offset: f32                                   // Offset X to next character to draw
    scaleFactor := fontsize / f32(font.baseSize)  // Character quad scaling factor
    codepointByteCount: i32

    ctext := transmute([^]u8)text

    for i := 0; i < size; i += int(codepointByteCount) {
        codepoint := rl.GetCodepointNext(cast(cstring)&ctext[i], &codepointByteCount)
        index := rl.GetGlyphIndex(font, codepoint)

	if codepoint != ' ' && codepoint != '\t' {
	    rl.DrawTextCodepoint(font, codepoint, pos + {offset, 0}, fontsize, tint)
	}

	if font.chars[index].advanceX == 0 {
	    offset += font.recs[index].width * scaleFactor
	} else {
	    offset += cast(f32)font.chars[index].advanceX * scaleFactor
	}
    }
}

render_text_centered :: proc(text: cstring, size: int, pos: rl.Vector2, font := font, fontsize: f32 = FONTSIZE, tint := rl.WHITE) {
    measure := rl.MeasureTextEx(font, text, fontsize, 0)
    render_text(text, size, pos - measure/2, font, fontsize, tint)
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
