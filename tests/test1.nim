import unittest

import crowncalc

test "add":
  check "2+2".solve == 4

test "subtract":
  check "3-2".solve == 1

test "multiply":
  check "2*2".solve == 4

test "divide":
  check "4/2".solve == 2

test "exponent":
  check "2^3".solve == 8

test "groups":
  check "(3+2)*5".solve == 25

test "subtract negative":
  check "2-3".solve == -1

test "negative exponent":
  check "2^-2".solve == 0.25

test "many numbers":
  check "1+2+3+4".solve == 10

test "float test":
  check "1.25*2".solve == 2.5

test "front negative":
  check "-3*3".solve == -9

test "negative numbers":
  check "3*-3".solve == -9

test "percentage":
  check "10+10%".solve == 11
  check "10*10%".solve == 10

test "negative percentage":
  check "10+-10%".solve == 9
  check "10*-10%".solve == -10

test "order of operations":
  check "3+2*5".solve == 13

test "order of operations 2":
  check "2-15+3".solve == -10

test "order of operations 3":
  check "2^4/4".solve == 4

test "order of operations 4":
  check "5*3+7*4".solve == 43

test "group sandwich":
  check "(5+4)*(7+3)".solve == 90

test "unbalanced groups":
  expect(CalcError):
    discard "(((5))".solve

test "front operator":
  expect(CalcError):
    discard "*5".solve

test "back operator":
  expect(CalcError):
    discard "5*".solve

test "divide by zero":
  expect(CalcError):
    discard "1/0".solve
