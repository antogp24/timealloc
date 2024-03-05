package main

import "core:fmt"
import rl "vendor:raylib"

// Resoure manager takes care of loading a resource from disk or bakes it into the executable.

BAKE_RESOURCES :: true

resource_load_font :: proc(path: cstring, fontsize: i32) -> (font: rl.Font) {
    when BAKE_RESOURCES {
	data :: #load("assets/Inter-Regular.ttf")
	font = rl.LoadFontFromMemory(".ttf", raw_data(data), cast(i32)len(data), fontsize, nil, 0)
    } else {
	font = rl.LoadFontEx("assets/Inter-Regular.ttf", FONTSIZE, nil, 0)
    }
    return font
}

