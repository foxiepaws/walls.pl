# walls.pl
#### a simple wallpaper setting program for use with X11


## Requirements

- Perl 5
- feh
- YAML.pm

## Configuration

Walls is configured using YAML, look at the reference config.

## Control

Walls offers a simple control scheme using unix signals

- SIGHUP - Reload the config
- SIGTERM - Quit safely
- SIGUSR1 - Pause on Current Image
- SIGUSR2 - Switch to Next Image

included is also a script for controlling walls called wallsctl.

- `wallsctl reload` - Reload the config
- `wallsctl quit -f` - Quit Safely
- `wallsctl pause` - pause on current image
- `wallsctl next` - Switch to the next image
