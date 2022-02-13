import std/os
import std/strformat
import std/terminal
import crowncalc
import noise

proc main() =
  var noise = Noise.init()
  noise.setPrompt("👑 calc> ")

  while true:
    let ok = noise.readLine
    if not ok:
      if noise.getKeyType() == ktCtrlD:
        break
      else:
        continue

    let expression = noise.getLine
    
    try:
      echo expression.solve
      noise.historyAdd(expression)
    except CalcError:
      echo &"\x1b[31m{getCurrentExceptionMsg()}\x1b[0m"

    echo ""

  echo "Goodbye!"


proc robot() =
  try:
    while true:
      let expression = stdin.readLine
      echo expression.solve
  except CalcError:
    quit getCurrentExceptionMsg()
  except EOFError:
    discard

when isMainModule:
  if paramCount() == 0:
    if isatty(stdin):
      main()
    else:
      robot()
  else:
    discard
