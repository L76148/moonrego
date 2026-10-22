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
fn Parser::parse_postfix(self : Parser) -> Term raise ParseError {
  let base = self.parse_primary()
  self.parse_suffixes(base)
}

///|
fn Parser::parse_unary(self : Parser) -> Term raise ParseError {
  if self.peek_kind() == Minus {
    let _ = self.advance()
    let operand = self.parse_unary()
    match operand {
      NumberTerm(text) =>
        if text.get_char(0) == Some('-') {
          Term::number(text[1:].to_owned())
        } else {
          Term::number("-" + text)
        }
      _ => Term::call("minus", [Term::number("0"), operand])
    }
  } else {
    self.parse_postfix()
  }
}

///|
fn Parser::parse_multiplicative(self : Parser) -> Term raise ParseError {
  let mut left = self.parse_unary()
  let mut running = true
  while running {
    match self.peek_kind() {
      Star => {
        let _ = self.advance()
        left = Term::call("mul", [left, self.parse_unary()])
      }
      Slash => {
        let _ = self.advance()
        left = Term::call("div", [left, self.parse_unary()])
      }
      Percent => {
        let _ = self.advance()
        left = Term::call("rem", [left, self.parse_unary()])
      }
      _ => running = false
    }
  }
  left
}

///|
fn Parser::parse_additive(self : Parser) -> Term raise ParseError {
  let mut left = self.parse_multiplicative()
  let mut running = true
  while running {
    match self.peek_kind() {
      Plus => {
        let _ = self.advance()
        left = Term::call("plus", [left, self.parse_multiplicative()])
      }
      Minus => {
        let _ = self.advance()
        left = Term::call("minus", [left, self.parse_multiplicative()])
      }
      _ => running = false
    }
  }
  left
}

///|
fn Parser::parse_intersection(self : Parser) -> Term raise ParseError {
  let mut left = self.parse_additive()
  while self.peek_kind() == Ampersand {
    let _ = self.advance()
    left = Term::call("intersection", [left, self.parse_additive()])
  }
  left
}

///|
/// Parses one term including the infix operators. `|` binds loosest, then
/// `&`, then `+` and `-`, then `*`, `/` and `%`, then unary minus.
fn Parser::parse_expression_term(self : Parser) -> Term raise ParseError {
  let mut left = self.parse_intersection()
  while self.peek_kind() == Pipe {
    let _ = self.advance()
    left = Term::call("union", [left, self.parse_intersection()])
  }
  left
}

///|
fn Parser::parse_expr_statement(self : Parser) -> Expr raise ParseError {
  let position = self.peek().position
  let left = self.parse_expression_term()
  match self.peek_kind() {
    Assign => {
      let _ = self.advance()
      let right = self.parse_expression_term()
      Expr::assign(left, right, position)
    }
    Equal => {
      let _ = self.advance()
      let right = self.parse_expression_term()
      Expr::unify(left, right, position)
    }
    kind =>
      match CompareOp::from_token(kind) {
        Some(op) => {
          let _ = self.advance()
          let right = self.parse_expression_term()
          Expr::compare(op, left, right, position)
        }
        None => Expr::term(left, position)
      }
  }
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
    LParen => {
      let _ = self.advance()
      let inner = self.parse_expression_term()
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
        let index = self.parse_expression_term()
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
    args.push(self.parse_expression_term())
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
    items.push(self.parse_expression_term())
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
  let first = self.parse_expression_term()
  if self.peek_kind() == Colon {
    let _ = self.advance()
    let first_value = self.parse_expression_term()
    let pairs : Array[(Term, Term)] = [(first, first_value)]
    while self.peek_kind() == Comma {
      let _ = self.advance()
      if self.peek_kind() == RBrace {
        let _ = self.advance()
        return Term::object_lit(pairs)
      }
      let key = self.parse_expression_term()
      let _ = self.expect(Colon, "':'")
      let value = self.parse_expression_term()
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
      items.push(self.parse_expression_term())
    }
    let _ = self.expect(RBrace, "'}'")
    Term::set_lit(items)
  }
}

///|
fn Parser::at_new_line(self : Parser) -> Bool {
  if self.index == 0 {
    false
  } else {
    let previous = self.tokens[self.index - 1]
    self.peek().position.line > previous.position.line
  }
}

///|
fn Parser::parse_with(self : Parser, expr : Expr) -> Expr raise ParseError {
  let modifiers : Array[WithModifier] = []
  while self.peek_kind() == With {
    let _ = self.advance()
    let target = self.parse_expression_term()
    let _ = self.expect(As, "'as'")
    let value = self.parse_expression_term()
    modifiers.push(WithModifier::new(target, value))
  }
  if modifiers.length() == 0 {
    expr
  } else {
    Expr::with_modifiers(expr, modifiers, expr.position)
  }
}

///|
fn Parser::parse_some(self : Parser) -> Expr raise ParseError {
  let position = self.peek().position
  let _ = self.advance()
  let vars : Array[Term] = [self.parse_expression_term()]
  while self.peek_kind() == Comma {
    let _ = self.advance()
    vars.push(self.parse_expression_term())
  }
  if self.peek_kind() == In {
    let _ = self.advance()
    let collection = self.parse_expression_term()
    Expr::some_in(vars, collection, position)
  } else {
    Expr::some_vars(vars, position)
  }
}

///|
fn Parser::parse_every(self : Parser) -> Expr raise ParseError {
  let position = self.peek().position
  let _ = self.advance()
  let vars : Array[Term] = [self.parse_expression_term()]
  while self.peek_kind() == Comma {
    let _ = self.advance()
    vars.push(self.parse_expression_term())
  }
  let _ = self.expect(In, "'in'")
  let collection = self.parse_expression_term()
  let _ = self.expect(LBrace, "'{'")
  let body = self.parse_body_until(RBrace)
  let _ = self.expect(RBrace, "'}'")
  Expr::every(vars, collection, body, position)
}

///|
fn Parser::parse_not(self : Parser) -> Expr raise ParseError {
  let position = self.peek().position
  let _ = self.advance()
  let body = if self.peek_kind() == LBrace {
    let _ = self.advance()
    let inner = self.parse_body_until(RBrace)
    let _ = self.expect(RBrace, "'}'")
    inner
  } else {
    [self.parse_expr_statement()]
  }
  Expr::not(body, position)
}

///|
fn Parser::parse_statement(self : Parser) -> Expr raise ParseError {
  match self.peek_kind() {
    SomeKeyword => self.parse_some()
    Every => self.parse_every()
    Not => self.parse_not()
    _ => {
      let expr = self.parse_expr_statement()
      self.parse_with(expr)
    }
  }
}

///|
/// Parses statements until the closing token. Statements are separated by a
/// semicolon or by a line break that follows the end of the previous
/// statement, so a line break inside brackets does not split a statement.
fn Parser::parse_body_until(
  self : Parser,
  closing : TokenKind,
) -> Array[Expr] raise ParseError {
  let body : Array[Expr] = []
  while true {
    let kind = self.peek_kind()
    if kind == closing || kind == Eof {
      break
    }
    body.push(self.parse_statement())
    let next = self.peek_kind()
    if next == closing || next == Eof {
      break
    }
    if next == Semicolon {
      let _ = self.advance()
      continue
    }
    if self.at_new_line() {
      continue
    }
    raise self.unexpected("a statement separator")
  }
  body
}

///|
fn source_tokens(source : String) -> Array[Token] raise ParseError {
  tokenize(source) catch {
    error => raise Lexical(error)
  }
}

///|
/// Parses one term including the infix operators, and requires the whole
/// input to be consumed.
///
/// Supported: scalars, variables, references with field and index steps,
/// calls, arrays, objects, sets, parentheses and the arithmetic and set
/// operators. Comprehensions and statement keywords arrive later.
pub fn parse_term(source : String) -> Term raise ParseError {
  let parser = Parser::new(source_tokens(source))
  let term = parser.parse_expression_term()
  match parser.peek().kind {
    Eof => term
    _ => raise TrailingTokens(parser.peek().position)
  }
}

///|
/// Parses one value expression and requires the whole input to be consumed.
///
/// The expression is a term, a comparison, an assignment (`:=`) or a
/// unification (`=`). The operators are lowered to the Rego built-ins
/// `plus`, `minus`, `mul`, `div`, `rem`, `intersection` and `union`.
pub fn parse_expr(source : String) -> Expr raise ParseError {
  let parser = Parser::new(source_tokens(source))
  let expr = parser.parse_expr_statement()
  match parser.peek().kind {
    Eof => expr
    _ => raise TrailingTokens(parser.peek().position)
  }
}

///|
/// Parses a statement body without its surrounding braces and requires the
/// whole input to be consumed.
///
/// Statements are separated by `;` or by a line break. The body may contain
/// value expressions, `some`, `every`, `not` and `with` modifiers.
pub fn parse_body(source : String) -> Array[Expr] raise ParseError {
  let parser = Parser::new(source_tokens(source))
  parser.parse_body_until(Eof)
}
