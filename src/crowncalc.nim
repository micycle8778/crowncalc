import std/lists
import std/math
import std/parseutils
import std/sets
import std/strformat
import std/tables
import std/unicode

## Crowncalc is a library for parsing strings into math equations, which can then be
## solved.

runnableExamples:
  assert "2+2".solve == 4
  assert "1+2+3+4+5".solve == 15
  assert "5*2".solve == 10
  assert "10+5*2".solve == 20 # Order of operations, this doesn't resolve to 15*2 -> 30
  assert "12*-5".solve == -60 # Negative numbers
  assert "10+10%".solve == 11 # Percentages
  assert "10*20%".solve == 20 # 10 * (10 * 0.2) -> 10 * 2 -> 20
  assert "(10+2)*5".solve == 60 # Groups
  assert "1.25*2".solve == 2.50 # Decimals

type 
  EquationKind* = enum
    ekNumber, ekAdd, ekSubtract, ekMultiply, ekDivide, ekExponent

  Equation* = ref object
    case kind: EquationKind
      of ekNumber: n: float
      of ekAdd, ekSubtract, ekMultiply, ekDivide, ekExponent: left, right: Equation

  TokenKind* = enum
    tkNumber, tkPercentage, tkAdd, tkSubtract, tkMultiply, tkDivide, tkGroupOpen,
    tkGroupClose, tkEquation, tkExponent

  Token* = object
    case kind: TokenKind
      of tkNumber, tkPercentage: n: float
      of tkEquation: e: Equation
      of tkAdd, tkSubtract, tkMultiply, tkDivide, tkGroupOpen, tkGroupClose, tkExponent: nil
  
  TokenString* = DoublyLinkedList[Token]
  
  CalcError* = object of CatchableError

  LexError* = object of CalcError
  ParseError* = object of CalcError
  SolveError* = object of CalcError

func makeAdd*(l, r: Equation): Equation =
  ## Helper function for making equation objects
  Equation(kind: ekAdd, left: l, right: r)

func makeSubtract*(l, r: Equation): Equation =
  ## Helper function for making equation objects
  Equation(kind: ekSubtract, left: l, right: r)

func makeMultiply*(l, r: Equation): Equation =
  ## Helper function for making equation objects
  Equation(kind: ekMultiply, left: l, right: r)

func makeDivide*(l, r: Equation): Equation =
  ## Helper function for making equation objects
  Equation(kind: ekDivide, left: l, right: r)

converter toEquation*(f: float): Equation =
  ## Helper function for making equation objects
  Equation(kind: ekNumber, n: f)

converter toEquation*(i: int): Equation =
  ## Helper function for making equation objects
  Equation(kind: ekNumber, n: i.float)

func excludeChars(s: string, chars: HashSet[char]): string =
  for c in s:
    if c notin chars:
      result.add c

proc snipAndReplace[T](list: var DoublyLinkedList[T], front, back: DoublyLinkedNode[T], x: T) =
  var node = newDoublyLinkedNode(x)
  if not front.isNil:
    front.next = node
    node.prev = front
  else:
    list.head = node
  if not back.isNil:
    back.prev = node
    node.next = back
  else:
    list.tail = node

proc `$`(L: SinglyLinkedList[Rune]): string =
  for r in L:
    result.add $r

func lexString*(s: string): TokenString =
  ## Convert a string into a list of tokens that the computer can understand
  var s = s.excludeChars([',', '\'', '_', ' '].toHashSet)
  if s == "":
    raise LexError.newException("Empty expression")

  if s[0] == '-':
    s = "0" & s

  result = initDoublyLinkedList[Token]()
  var arr = initSinglyLinkedList[Rune]()
  for r in s.runes:
    arr.add r

  while not arr.head.isNil:
    case arr.head.value:
      of '0'.Rune, '1'.Rune, '2'.Rune, '3'.Rune, '4'.Rune, '5'.Rune, '6'.Rune, '7'.Rune,
        '8'.Rune, '9'.Rune, '.'.Rune:
        # TODO: Optimize this code by making a float scanner for linked lists
        var str = $arr
        var n: float
        let length = str.parseFloat(n)

        for _ in countdown(length, 1):
          arr.remove(arr.head)

        if not arr.head.isNil and arr.head.value == '%'.Rune:
          result.add Token(kind: tkPercentage, n: n)
          arr.remove(arr.head)
        else:
          result.add Token(kind: tkNumber, n: n)
      of '('.Rune, '['.Rune, '{'.Rune:
        result.add Token(kind: tkGroupOpen)
        arr.remove(arr.head)
      of ')'.Rune, ']'.Rune, '}'.Rune:
        result.add Token(kind: tkGroupClose)
        arr.remove(arr.head)
      of '+'.Rune:
        result.add Token(kind: tkAdd)
        arr.remove(arr.head)
      of '-'.Rune:
        result.add Token(kind: tkSubtract)
        arr.remove(arr.head)
      of '*'.Rune, 0xd7.Rune: # 0xd7 == ×
        result.add Token(kind: tkMultiply)
        arr.remove(arr.head)
      of '/'.Rune, 0xf7.Rune: # 0xf7 == ÷
        result.add Token(kind: tkDivide)
        arr.remove(arr.head)
      of '^'.Rune:
        result.add Token(kind: tkExponent)
        arr.remove(arr.head)
      of '%'.Rune:
        raise LexError.newException("Misplaced '%'")
      else:
        raise LexError.newException(fmt"Unknown character '{arr.head.value}'")

func parseTokens*(arr: TokenString): Equation =
  ## Convert a list of tokens into an equation that can be solved
  var arr = arr
  const val_tokens = [tkNumber, tkEquation, tkPercentage].toHashSet

  # Check if the parenthesises are unbalanced
  block:
    var flag = arr.head
    var count = 0

    while not flag.isNil:
      let kind = flag.value.kind
      if kind == tkGroupOpen:
        inc count
      elif kind == tkGroupClose:
        dec count

      flag = flag.next

    if count != 0:
      raise ParseError.newException("Unbalanced parenthesises")

  while (arr.head != arr.tail):
    # groups
    block:
      var front = arr.head
      while not front.isNil and front.value.kind != tkGroupOpen:
        front = front.next

      if front.isNil:
        break
      
      var back = front.next
      var count = 1
      while not back.isNil and count > 0:
        if back.value.kind == tkGroupClose:
          dec count
        elif back.value.kind == tkGroupOpen:
          inc count
        else:
          back = back.next

      if count > 0:
        raise ParseError.newException("Missing ')'")

      var list = initDoublyLinkedList[Token]()

      front.next.prev = nil
      back.prev.next = nil

      list.head = front.next
      list.tail = back.prev
      
      let eq = Token(kind: tkEquation, e: parseTokens(list))

      arr.snipAndReplace(front.prev, back.next, eq)

    proc op(opTable: Table[TokenKind, EquationKind]) =
      var flag = arr.head
      # Scan for the operator
      while not flag.isNil and flag.value.kind notin opTable:
        flag = flag.next

      # Break out of the block if the operator isn't found
      if flag.isNil:
        return

      # Check that there is a number on the left and right of the operator
      if (flag == arr.head or flag == arr.tail) or 
        (flag.prev.value.kind notin val_tokens or flag.next.value.kind notin val_tokens):
        # If there's a negative to the right of us, that probably means there's a
        # negative number there
        if flag.next.value.kind == tkSubtract:
          if flag.next.next.value.kind notin val_tokens:
            raise ParseError.newException(fmt"Misplaced '-'")

          var t: Token
          let rkind = flag.next.next.value.kind
          case rkind:
            of tkEquation:
              t = Token(kind: tkEquation, e: makeMultiply(-1, flag.next.next.value.e))
            of tkNumber:
              t = Token(kind: tkEquation, e: makeMultiply(-1, flag.next.next.value.n))
            of tkPercentage:
              t = Token(kind: tkPercentage, n: flag.next.next.value.n * -1)
            else:
              discard
          arr.snipAndReplace(flag, flag.next.next.next, t)

        # Clearly, this must be a malformed equation
        else:
          raise ParseError.newException(fmt"Misplaced '{flag.value.kind}'")

      if flag.prev.value.kind == tkPercentage:
        raise ParseError.newException("Percentages are only supported on the rightside of the operator")

      # Find the left and right equations
      let left = if flag.prev.value.kind == tkEquation: flag.prev.value.e else: flag.prev.value.n
      let rKind = flag.next.value.kind
      var right: Equation
      
      if rKind == tkEquation:
        right = flag.next.value.e
      elif rKind == tkNumber:
        right = Equation(kind: ekNumber, n: flag.next.value.n)
      elif rKind == tkPercentage:
        right = makeMultiply(left, makeDivide(flag.next.value.n, 100))

      # Make the equation and replace the parsed tokens
      let eq = case opTable[flag.value.kind]:
        of ekAdd:
          Token(kind: tkEquation, e: Equation(kind: ekAdd, left: left, right: right))
        of ekSubtract:
          Token(kind: tkEquation, e: Equation(kind: ekSubtract, left: left, right: right))
        of ekMultiply:
          Token(kind: tkEquation, e: Equation(kind: ekMultiply, left: left, right: right))
        of ekDivide:
          Token(kind: tkEquation, e: Equation(kind: ekDivide, left: left, right: right))
        of ekExponent:
          Token(kind: tkEquation, e: Equation(kind: ekExponent, left: left, right: right))
        of ekNumber:
          raise Defect.newException("Unsupported Equation Kind")
      arr.snipAndReplace(flag.prev.prev, flag.next.next, eq)

    op({tkExponent: ekExponent}.toTable)
    op({tkMultiply: ekMultiply, tkDivide: ekDivide}.toTable)
    op({tkAdd: ekAdd, tkSubtract: ekSubtract}.toTable)

  case arr.head.value.kind:
    of tkEquation:
      result = arr.head.value.e
    of tkNumber:
      result = arr.head.value.n # Implicit conversion to Equation
    of tkPercentage:
      result = makeDivide(arr.head.value.n, 100)
    else:
      raise ParseError.newException("Isolated operator")

func solve*(e: Equation): float =
  ## Solve the equation
  case e.kind:
    of ekNumber:
      e.n
    of ekAdd:
      e.left.solve() + e.right.solve()
    of ekSubtract:
      e.left.solve() - e.right.solve()
    of ekMultiply:
      e.left.solve() * e.right.solve()
    of ekDivide:
      let right = e.right.solve()
      if right == 0:
        raise SolveError.newException("Cannot divide by zero")
      else:
        e.left.solve() / right
    of ekExponent:
      pow(e.left.solve(), e.right.solve())

func solve*(s: string): float =
  ## Alias for `s.lexString.parseTokens.solve`
  s.lexString.parseTokens.solve
