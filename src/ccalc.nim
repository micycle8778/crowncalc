import std/math
import std/sets
import std/tables
import std/unicode
import crowncalc
import sdl2
import sdl2/ttf

type 
  Size = object
    w, h: cint
  ResultString = object
    s: string
    resultMode: bool
    errorMode: bool
    history: seq[string]
    # Note that this pointer is in reverse, so 1 -> ^1, or the end of the history.
    # historyPtr points to the previous thing in history, not the current thing
    # being shown.
    historyPtr: Natural 
proc initResultString(): ResultString =
  ResultString(s: "", resultMode: false, errorMode: false, history: newSeq[string](), historyPtr: 1)

proc clear(rs: var ResultString) =
  # Clear the result string
  rs.resultMode = false
  rs.errorMode = false
  rs.s.setLen(0)

proc extend(rs: var ResultString, s: string) =
  # Add a character to the string
  if rs.errorMode:
    rs.clear

  if rs.resultMode and s in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"].toHashSet:
    rs.clear

  rs.resultMode = false
  rs.s.add s

proc solve(rs: var ResultString) =
  # Solve the string
  rs.history.add rs.s
  rs.historyPtr = 1

  if rs.errorMode:
    rs.clear
  else:
    rs.resultMode = true
    try:
      rs.s = $rs.s.solve
    except CalcError:
      rs.errorMode = true
      rs.s = getCurrentExceptionMsg()

proc shrink(rs: var ResultString) =
  # Backspace
  if rs.resultMode or rs.errorMode:
    rs.clear
  elif rs.s.len != 0:
    rs.s.setLen(rs.s.len - rs.s[^1].Rune.size)
  else:
    rs.s.setLen(max(0, rs.s.len - 1))

proc prev(rs: var ResultString) =
  # Go up history
  rs.errorMode = false
  rs.s = rs.history[^rs.historyPtr]
  rs.historyPtr = min(rs.history.len, succ rs.historyPtr)

proc next(rs: var ResultString) =
  # Go down history
  rs.errorMode = false
  if rs.historyPtr != 1:
    rs.historyPtr = max(pred rs.historyPtr, 1)
    rs.s = rs.history[^rs.historyPtr]
  else:
    rs.clear
    

# Init
doAssert sdl2.init(INIT_EVERYTHING) == SdlSuccess
doAssert ttfInit() == SdlSuccess

const 
  resPadding = 40

# Colors
  bg = (29.uint8, 32.uint8, 33.uint8, 255.uint8)
  fg = (104.uint8, 157.uint8, 106.uint8, 255.uint8)
  errorFg = (204.uint8, 36.uint8, 29.uint8, 255.uint8)
  btnBg = (40.uint8, 40.uint8, 40.uint8, 255.uint8)
  btnHoverBg = (60.uint8, 56.uint8, 54.uint8, 255.uint8)
  btnFg = (235.uint8, 219.uint8, 178.uint8, 255.uint8)

# Font
const fontData = slurp"../SpaceMono-Italic.ttf"

func getOptimalFontSize(width, height, charCount: int): int =
  let max_x = (width.float - 10).float * 1.63 / charCount.float
  let max_y = height.float * 0.67
  return round(min(max_x, max_y)).int

var fonts = initTable[int, FontPtr]()
proc getFont(size: int): FontPtr =
  if size notin fonts:
    let fontRWops = rwFromConstMem(fontData.cstring, fontData.len)
    fonts[size] = font_RWops.openFontRW(1, size.cint)

  return fonts[size]

# Window
var
  window: WindowPtr
  render: RendererPtr

window = createWindow("Crowncalc", 100, 100, 560, 720, SDL_WINDOW_SHOWN or SDL_WINDOW_RESIZABLE)
render = createRenderer(window, -1, Renderer_Accelerated or Renderer_PresentVsync or Renderer_TargetTexture)

var
  evt = sdl2.defaultEvent
  runGame = true
  expression = initResultString()
  debounce = true

# # Button procs
proc button(render: RendererPtr, x, y, width, height: cint, text: string, left_border = false): bool =
  const border = 2
  var rect: Rect = (x, y, width, height)
  let xOffset = if left_border: 0 else: border

  # # Test for hover and click
  var cur_x, cur_y: cint
  let mouse_state = getMouseState(cur_x, cur_y)
  let hover = x < cur_x and y < cur_y and x + width > cur_x and y + height > cur_y
  result = hover and ((1.uint and mouse_state) > 0) and debounce

  # # Render button border
  render.setDrawColor bg
  render.fillRect(rect)

  # # Render button background
  rect.x += xOffset.cint
  rect.y += border
  rect.w -= xOffset.cint
  rect.h -= border

  render.setDrawColor if hover: btnHoverBg else: btnBg
  render.fillRect(rect)

  # # Render Text
  let font = getFont(getOptimalFontSize((width.float * 0.8).int, (height.float * 0.8).int, 1))
  let surface = renderUTF8Blended(font, text, btnFg)
  let texture = createTextureFromSurface(render, surface)

  var font_width, font_height: cint
  texture.queryTexture(nil, nil, addr font_width, addr font_height)

  var font_rect = (x + ((width-font_width) div 2), y + ((height-font_height) div 2), font_width, font_height)

  render.copy(texture, nil, addr font_rect)

  destroy surface
  destroy texture

proc textButton(render: RendererPtr, x, y, height, width: cint, text: string, left_border = true) =
  if button(render, x, y, height, width, text, left_border):
    expression.extend text

# startTextInput creates these wonderful TextInput events that make life a
# whole lot easier
startTextInput()

while runGame:
  while pollEvent(evt):
    # # Event handling
    case evt.kind:
      of QuitEvent:
        runGame = false
        break
      # TextInput mainly handles the stuff you type into the calculator, like
      # numbers and operators
      of TextInput:
        let c = evt.text.text[0]
        let allowed = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '-', '+', '/',
                       '*', '.', '(', ')', '[', ']', '{', '}', '%', '^'].toHashSet
        if c in allowed:
          var s = $c
          if c == '/':
            s = "÷"
          elif c == '*':
            s = "×"
          expression.extend s
      # KeyDown handles the stuff that affects the calculator, like backspace
      # and clear
      of KeyDown:
        if evt.key.keysym.scancode in [SDL_SCANCODE_RETURN, SDL_SCANCODE_KP_ENTER].toHashSet:
          expression.solve
        if evt.key.keysym.scancode == SDL_SCANCODE_ESCAPE:
          expression.clear
        if evt.key.keysym.scancode in [SDL_SCANCODE_BACKSPACE, SDL_SCANCODE_KP_BACKSPACE].toHashSet:
          expression.shrink
        if evt.key.keysym.scancode == SDL_SCANCODE_DOWN:
          expression.next
        if evt.key.keysym.scancode == SDL_SCANCODE_UP:
          expression.prev

      else:
        discard
  # # Generate button sizes
  var width, height: cint

  window.getSize(width, height)

  let resSize = Size(w: width - resPadding, h: height div 4)
  let btnSize = Size(w: (width div 6).cint, h: (height.float * (3/16)).cint)

  # # Clear the screen
  render.setDrawColor bg
  render.clear

  # # Buttons
  # lookup table for text buttons
  const lut = [
    ["7", "8", "9", "÷", "("],
    ["4", "5", "6", "×", ")"],
    ["1", "2", "3", "-", "^"],
    [".", "0", "", "+", "%"]
  ]

  for x in 0..(lut[0].len - 1):
    for y in 0..(lut.len - 1):
      if lut[y][x] == "": continue

      render.textButton(
        (x * btnSize.w).cint,
        (resSize.h + y * btnSize.h).cint,
        if x == 1 and y == 3: (btnSize.w * 2).cint else: btnSize.w, # 0 is double width
        btnSize.h,
        lut[y][x],
        x == 0
      )
  
  # Backspace
  if render.button((5 * btnSize.w).cint, resSize.h, btnSize.w, btnSize.h, "←"):
    expression.shrink

  # Clear key
  if render.button((5 * btnSize.w).cint, (1 * btnSize.h + resSize.h), btnSize.w, btnSize.h, "C"):
    expression.clear

  # Solve
  if render.button((5 * btnSize.w).cint, (2 * btnSize.h + resSize.h).cint, btnSize.w, (btnSize.h * 2).cint, "="):
    expression.solve

  # # Output
  let resFont = getFont(getOptimalFontSize(resSize.w, resSize.h, expression.s.len))

  let surface = renderUTF8Blended(resFont, expression.s.cstring, if expression.errorMode: errorFg else: fg)
  let texture = createTextureFromSurface(render, surface)

  var font_width, font_height: cint
  texture.queryTexture(nil, nil, addr font_width, addr font_height)

  var font_rect = (resSize.w-font_width + (resPadding div 2), (resSize.h-font_height) div 2, font_width, font_height)

  render.copy(texture, nil, addr font_rect)

  destroy surface
  destroy texture

  # # Present the drawn screen
  render.present

  debounce = (1.uint and getMouseState(nil, nil)) == 0

destroy render
destroy window
