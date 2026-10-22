///|
/// A syntax error, always carrying the position of the offending token.
pub(all) suberror ParseError {
  UnexpectedToken(TokenKind, Position, String)
  UnexpectedEof(String)
  TrailingTokens(Position)
  Lexical(LexError)
} derive(@debug.Debug)

///|
pub extend ParseError with @debug.Debug::{to_repr}

///|
/// A human readable explanation of the error.
pub fn ParseError::message(self : ParseError) -> String {
  match self {
    UnexpectedToken(kind, position, expected) =>
      "expected " +
      expected +
      ", found " +
      kind.name() +
      " at " +
      describe(position)
    UnexpectedEof(expected) => "expected " + expected + ", found end of file"
    TrailingTokens(position) =>
      "unexpected trailing tokens at " + describe(position)
    Lexical(error) => error.message()
  }
}

///|
priv struct Parser {
  tokens : Array[Token]
  mut index : Int32
}

///|
fn Parser::new(tokens : Array[Token]) -> Parser {
  { tokens, index: 0, }
}

///|
fn Parser::peek(self : Parser) -> Token {
  self.tokens[self.index]
}

///|
fn Parser::peek_kind(self : Parser) -> TokenKind {
  self.peek().kind
}

///|
fn Parser::advance(self : Parser) -> Token {
  let token = self.peek()
  if token.kind != Eof {
    self.index = self.index + 1
  }
  token
}

///|
fn Parser::unexpected(self : Parser, expected : String) -> ParseError {
  let token = self.peek()
  if token.kind == Eof {
    UnexpectedEof(expected)
  } else {
    UnexpectedToken(token.kind, token.position, expected)
  }
}

///|
fn Parser::expect(
  self : Parser,
  kind : TokenKind,
  expected : String,
) -> Token raise ParseError {
  let token = self.peek()
  if token.kind == kind {
    self.advance()
  } else {
    raise self.unexpected(expected)
  }
}

///|
fn Parser::parse_term(self : Parser) -> Term raise ParseError {
  let base = self.parse_primary()
  self.parse_suffixes(base)
}

///|
fn Parser::parse_primary(self : Parser) -> Term raise ParseError {
  let token = self.peek()
  match token.kind {
    NullKeyword => {
      let _ = self.advance()
      Term::null()
    }
    TrueKeyword => {
      let _ = self.advance()
      Term::boolean(true)
    }
    FalseKeyword => {
      let _ = self.advance()
      Term::boolean(false)
    }
    NumberLit => {
      let _ = self.advance()
      Term::number(token.text)
    }
    StringLit | RawStringLit => {
      let _ = self.advance()
      Term::string(token.text)
    }
    Ident => {
      let _ = self.advance()
      Term::variable(token.text)
    }
    Minus => {
      let _ = self.advance()
      let operand = self.parse_term()
      match operand {
        NumberTerm(text) =>
          if text.get_char(0) == Some('-') {
            Term::number(text[1:].to_owned())
          } else {
            Term::number("-" + text)
          }
        _ => Term::call("minus", [Term::number("0"), operand])
      }
    }
    LParen => {
      let _ = self.advance()
      let inner = self.parse_term()
      let _ = self.expect(RParen, "')'")
      inner
    }
    LBracket => self.parse_array()
    LBrace => self.parse_brace()
    _ => raise self.unexpected("a term")
  }
}

///|
fn Parser::parse_suffixes(self : Parser, base : Term) -> Term raise ParseError {
  let mut current = base
  let mut steps : Array[RefStep] = []
  let mut running = true
  while running {
    match self.peek_kind() {
      Dot => {
        let _ = self.advance()
        let token = self.peek()
        if token.kind == Ident {
          let _ = self.advance()
          steps.push(RefStep::field(token.text))
        } else {
          raise self.unexpected("a field name")
        }
      }
      LBracket => {
        let _ = self.advance()
        let index = self.parse_term()
        let _ = self.expect(RBracket, "']'")
        steps.push(RefStep::index(index))
      }
      LParen => {
        let _ = self.advance()
        let args = self.parse_arguments()
        let callee = if steps.length() == 0 {
          current
        } else {
          Term::reference(current, steps)
        }
        current = Term::call_term(callee, args)
        steps = []
      }
      _ => running = false
    }
  }
  if steps.length() == 0 {
    current
  } else {
    Term::reference(current, steps)
  }
}

///|
fn Parser::parse_arguments(self : Parser) -> Array[Term] raise ParseError {
  let args : Array[Term] = []
  if self.peek_kind() == RParen {
    let _ = self.advance()
    return args
  }
  while true {
    args.push(self.parse_term())
    if self.peek_kind() == Comma {
      let _ = self.advance()
      if self.peek_kind() == RParen {
        let _ = self.advance()
        break
      }
    } else if self.peek_kind() == RParen {
      let _ = self.advance()
      break
    } else {
      raise self.unexpected("',' or ')'")
    }
  }
  args
}

///|
fn Parser::parse_array(self : Parser) -> Term raise ParseError {
  let _ = self.expect(LBracket, "'['")
  let items : Array[Term] = []
  if self.peek_kind() == RBracket {
    let _ = self.advance()
    return Term::array_lit(items)
  }
  while true {
    items.push(self.parse_term())
    if self.peek_kind() == Comma {
      let _ = self.advance()
      if self.peek_kind() == RBracket {
        let _ = self.advance()
        break
      }
    } else if self.peek_kind() == RBracket {
      let _ = self.advance()
      break
    } else {
      raise self.unexpected("',' or ']'")
    }
  }
  Term::array_lit(items)
}

///|
fn Parser::parse_brace(self : Parser) -> Term raise ParseError {
  let _ = self.expect(LBrace, "'{'")
  if self.peek_kind() == RBrace {
    let _ = self.advance()
    return Term::object_lit([])
  }
  let first = self.parse_term()
  if self.peek_kind() == Colon {
    let _ = self.advance()
    let first_value = self.parse_term()
    let pairs : Array[(Term, Term)] = [(first, first_value)]
    while self.peek_kind() == Comma {
      let _ = self.advance()
      if self.peek_kind() == RBrace {
        let _ = self.advance()
        return Term::object_lit(pairs)
      }
      let key = self.parse_term()
      let _ = self.expect(Colon, "':'")
      let value = self.parse_term()
      pairs.push((key, value))
    }
    let _ = self.expect(RBrace, "'}'")
    Term::object_lit(pairs)
  } else {
    let items : Array[Term] = [first]
    while self.peek_kind() == Comma {
      let _ = self.advance()
      if self.peek_kind() == RBrace {
        let _ = self.advance()
        return Term::set_lit(items)
      }
      items.push(self.parse_term())
    }
    let _ = self.expect(RBrace, "'}'")
    Term::set_lit(items)
  }
}

///|
/// Parses one term and requires the whole input to be consumed.
///
/// Supported: scalars, variables, references with field and index steps,
/// calls, arrays, objects, sets and parentheses. Comprehensions, arithmetic
/// and expression statements arrive with the expression parser.
pub fn parse_term(source : String) -> Term raise ParseError {
  let tokens = tokenize(source) catch { error => raise Lexical(error) }
  let parser = Parser::new(tokens)
  let term = parser.parse_term()
  match parser.peek().kind {
    Eof => term
    _ => raise TrailingTokens(parser.peek().position)
  }
}
