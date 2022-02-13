# Crowncalc
A calculator written in nim

## Dependencies
`ccalc` depends on SDL2, meaning you have to install it if you want to use the GUI
calculator. Installation instructions exist at
[nim-lang/sdl2](https://github.com/nim-lang/sdl2/blob/master/README.md)

## Usage
Crowncalc is fairly straight forward.

### `crowncalc`
![ccalc screenshot](ccalc.png)

### `ccalccli`
```
👑 calc>2+2
4.0

👑 calc> ^D
Goodbye!
```

### `crowncalc` library
```nim
import crowncalc

echo "2+2".solve # 4.0
```

## Credits
[Space Mono](https://fonts.google.com/specimen/Space+Mono), the font used in `ccalc`, is
under the [OFL](OFL.txt) and is made by Colophon Foundry.
