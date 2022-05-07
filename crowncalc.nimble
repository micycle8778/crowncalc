# Package

version           = "1.0.2"
author            = "Rainbow Asteroids"
description       = "Basic calculator in Nim"
license           = "MIT"
srcDir            = "src"
installExt        = @["nim"]
bin               = @["ccalccli"]
namedBin["ccalc"] = "crowncalc"


# Dependencies

requires "nim >= 1.6.0"
requires "noise"
requires "sdl2"
