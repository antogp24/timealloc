# timealloc
Time management application. Managing time can be just like managing memory, frustrating...

<p align=center>
  <img src="./assets/icon/timealloc.png">
</p>

> [!WARNING]
> This software is very simple in functionality. Keep your expectations low.

## How it works ⏰
The application shows a *timeline* of all the hours in the day. You can place *textboxes* indicating what activities
you will be doing at that time of the day. To have overlapping activities, there's a fixed amount of *layers* you can use.
All your textboxes will be automatically saved once you close the application, if *AUTO_SAVE* is enabled. The saving is 
done with the `user.timealloc` file, but it is **NOT** human readable, do not modify it by hand. If the program doesn't
find that file, it creates it automatically, so place `timealloc.exe` in an empty folder.

## Timeline Bindings 🖱️⌨️  

- `Ctrl+S`: Save the textboxes
- `Ctrl+T`: Toggle timealloc
- `Ctrl+A`: Go to hour 0
- `Ctrl+E`: Go to hour 23
- `Ctrl+D`: Go to the current hour in the clock

- `left/right`: Move the cursor left/right in the active textbox
- `up/down`: Move the cursor to the start/end of the active textbox
- `backspace`: Delete a character in the active textbox
- `Ctrl+backspace`: Delete a word in the active textbox
- `Ctrl+left/right`: Move the cursor left/right by a word in the active textbox

- `mouse:left`: Select a textbox
- `mouse:right`: Delete a textbox
- `mouse:left and drag`: Create a new textbox

## Timealloc Bindings ⌨️

- `Ctrl+T`: Get out of timealloc
- `esc`: Get out of timealloc
- `left/right`: Move to the previous/next textbox
- `up/down`: increase/decrease the number in the textbox
- `enter`: add a textbox in that time

## Dependencies

The Odin programming language: https://odin-lang.org/docs/install/

## How to setup your timezone 🌐
It happens to be that my timezone is UTC-5, but that may not be the case for you. If you want to change it you will
have to do build the application with the flag `UTC_OFFSET` with your value. Follow these steps:

Install the dependencies.

```console
$ git clone --depth=1 https://github.com/antogp24/timealloc.git
$ cd timealloc
```

Now open your text editor of choice and change to your specific value in the `build.bat`.
Change this specific line replace the -5 with your offset.
```bat
odin build src -resource:assets/icon/timealloc.rc -out:timealloc.exe -o:speed -show-timings -define:UTC_OFFSET=-5
```

```console
$ build.bat release
```
