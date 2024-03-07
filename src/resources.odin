package main

import "core:fmt"
import rl "vendor:raylib"

// Resoure manager takes care of loading a resource from disk or bakes it into the executable.

BAKE_RESOURCES :: #config(BAKE_RESOURCES, true)

resource_load_image :: proc($path: cstring) -> (image: rl.Image) {
    when BAKE_RESOURCES {
        data :: #load(path)
        size := cast(i32)len(data)
        ext := rl.GetFileExtension(path)
        image = rl.LoadImageFromMemory(ext, raw_data(data), size)
    } else {
        image = rl.LoadImage(path)
    }
    return image 
}

resource_load_font :: proc($path: cstring, fontsize: i32) -> (font: rl.Font) {
    when BAKE_RESOURCES {
        data :: #load(path)
        size := cast(i32)len(data)
        ext := rl.GetFileExtension(path)
        font = rl.LoadFontFromMemory(ext, raw_data(data), size, fontsize, nil, 0)
    } else {
        font = rl.LoadFontEx(path, fontsize, nil, 0)
    }
    return font
}

