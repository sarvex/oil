#!/usr/bin/env python3
"""
tokens_test.py: Tests for tokens.py
"""

import unittest

import tokens
from tokens import *

from lexer import Token


class TokensTest(unittest.TestCase):

  def testTokens(self):
    print(OP_NEWLINE)
    print(Token(OP_NEWLINE, '\n'))

    print(TokenTypeToName(OP_NEWLINE))

    print(TokenKind.Eof)
    print(TokenKind.LEFT)
    print('--')
    for name in dir(TokenKind):
      if name[0].isupper():
        print(name, getattr(TokenKind, name))

    # Make sure we're not exporting too much
    print(dir(tokens))

    # 144 out of 256 tokens now
    print(len(tokens._TOKEN_TYPE_NAMES))

    t = Token(AS_OP_PLUS, '+')
    self.assertEqual(TokenKind.AS_OP, t.Kind())
    t = Token(AS_OP_CARET_EQUAL, '^=')
    self.assertEqual(TokenKind.AS_OP, t.Kind())
    t = Token(AS_OP_RBRACE, '}')
    self.assertEqual(TokenKind.AS_OP, t.Kind())

  def testBTokens(self):
    print(BType)

    print('')
    print(dir(BType))
    print('')
    print(dir(BKind))
    print('')

    from pprint import pprint
    pprint(tokens._BTOKEN_TYPE_NAMES)


def PrintBoolTable():
  for i, (kind, logical, arity, arg_type) in enumerate(BOOLEAN_OP_TABLE):
    row = (BTokenTypeToName(i), logical, arity, arg_type)
    print('\t'.join(str(c) for c in row))

  print(dir(BKind))


if __name__ == '__main__':
  import sys
  if len(sys.argv) > 1 and sys.argv[1] == 'stats':
    k = tokens._kind_sizes
    print('STATS: %d tokens in %d groups: %s' % (sum(k), len(k), k))
    # Thinking about switching
    big = [i for i in k if i > 8]
    print('%d BIG groups: %s' % (len(big), big))

    a = len(tokens._TokenDef.AS_OP)
    print(a)

    print('BType:', len(tokens._BTOKEN_TYPE_NAMES))

    PrintBoolTable()

  else:
    unittest.main()
