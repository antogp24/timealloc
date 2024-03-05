package main

import "core:fmt"
import rl "vendor:raylib"

// Resoure manager takes care of loading a resource from disk or bakes it into the executable.

BAKE_RESOURCES :: true

resource_load_font :: proc($path: cstring, fontsize: i32) -> (font: rl.Font) {
    when BAKE_RESOURCES {
	data :: #load(path)
	size := cast(i32)len(data)
	ext := rl.GetFileExtension(path)
	font = rl.LoadFontFromMemory(ext, raw_data(data), size, fontsize, nil, 0)
    } else {
	font = rl.LoadFontEx(path, FONTSIZE, nil, 0)
    }
    return font
}

