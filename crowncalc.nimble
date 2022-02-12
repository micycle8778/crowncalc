# Package

version       = "0.1.0"
author        = "Rainbow Asteroids"
description   = "Basic calculator in Nim"
license       = "MIT"
srcDir        = "src"
installFiles  = @["crowncalc.nim"]
bin           = @["ccalccli", "ccalc"]


# Dependencies

requires "nim >= 1.6.0"
requires "noise"
requires "sdl2"
