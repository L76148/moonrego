///|
/// A lexical error, always carrying the position where it was detected.
pub(all) suberror LexError {
  UnexpectedChar(Position, Char)
  UnterminatedString(Position)
  UnterminatedRawString(Position)
  InvalidEscape(Position, Char)
  InvalidUnicodeEscape(Position)
  InvalidNumber(Position, String)
} derive(@debug.Debug)

///|
pub extend LexError with @debug.Debug::{to_repr}

///|
fn describe(position : Position) -> String {
  "line " +
  position.line.to_string() +
  ", column " +
  position.column.to_string()
}

///|
/// A human readable explanation of the error.
pub fn LexError::message(self : LexError) -> String {
  match self {
    UnexpectedChar(position, c) =>
      "unexpected character '" + c.to_string() + "' at " + describe(position)
    UnterminatedString(position) =>
      "unterminated string at " + describe(position)
    UnterminatedRawString(position) =>
      "unterminated raw string at " + describe(position)
    InvalidEscape(position, c) =>
      "invalid escape '\\" + c.to_string() + "' at " + describe(position)
    InvalidUnicodeEscape(position) =>
      "invalid unicode escape at " + describe(position)
    InvalidNumber(position, text) =>
      "invalid number '" + text + "' at " + describe(position)
  }
}

///|
fn is_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn hex_value(c : Char) -> Int32? {
  if c >= '0' && c <= '9' {
    Some(c.to_int() - '0'.to_int())
  } else if c >= 'a' && c <= 'f' {
    Some(c.to_int() - 'a'.to_int() + 10)
  } else if c >= 'A' && c <= 'F' {
    Some(c.to_int() - 'A'.to_int() + 10)
  } else {
    None
  }
}

///|
priv struct Scanner {
  source : Array[Char]
  mut offset : Int32
  mut line : Int32
  mut column : Int32
}

///|
fn Scanner::new(source : String) -> Scanner {
  { source: source.to_array(), offset: 0, line: 1, column: 1, }
}

///|
fn Scanner::position(self : Scanner) -> Position {
  { offset: self.offset, line: self.line, column: self.column, }
}

///|
fn Scanner::peek(self : Scanner) -> Char? {
  self.source.get(self.offset)
}

///|
fn Scanner::peek_at(self : Scanner, distance : Int32) -> Char? {
  self.source.get(self.offset + distance)
}

///|
fn Scanner::advance(self : Scanner) -> Char? {
  match self.source.get(self.offset) {
    Some(c) => {
      self.offset = self.offset + 1
      if c == '\n' {
        self.line = self.line + 1
        self.column = 1
      } else {
        self.column = self.column + 1
      }
      Some(c)
    }
    None => None
  }
}

///|
fn Scanner::skip_trivia(self : Scanner) -> Unit {
  while true {
    match self.peek() {
      Some(c) =>
        if c == ' ' || c == '\t' || c == '\r' || c == '\n' {
          let _ = self.advance()
        } else if c == '#' {
          while true {
            match self.peek() {
              Some(ch) =>
                if ch == '\n' {
                  break
                } else {
                  let _ = self.advance()
                }
              None => break
            }
          }
        } else {
          break
        }
      None => break
    }
  }
}

///|
fn Scanner::next_token(self : Scanner) -> Token raise LexError {
  self.skip_trivia()
  let position = self.position()
  match self.peek() {
    None => Token::new(Eof, "", position)
    Some(c) =>
      if is_ident_start(c) {
        self.scan_identifier(position)
      } else if is_digit(c) {
        self.scan_number(position)
      } else if c == '"' {
        self.scan_string(position)
      } else if c == '`' {
        self.scan_raw_string(position)
      } else {
        self.scan_symbol(c, position)
      }
  }
}

///|
fn Scanner::scan_identifier(self : Scanner, position : Position) -> Token {
  let buffer = StringBuilder()
  while true {
    match self.peek() {
      Some(c) =>
        if is_ident_continue(c) {
          buffer.write_char(c)
          let _ = self.advance()
        } else {
          break
        }
      None => break
    }
  }
  let text = buffer.to_string()
  let kind = match keyword_kind(text) {
    Some(kind) => kind
    None => Ident
  }
  Token::new(kind, text, position)
}

///|
fn Scanner::scan_number(
  self : Scanner,
  position : Position,
) -> Token raise LexError {
  let buffer = StringBuilder()
  match self.peek() {
    Some('0') => {
      buffer.write_char('0')
      let _ = self.advance()
    }
    Some(c) =>
      if c >= '1' && c <= '9' {
        while true {
          match self.peek() {
            Some(d) =>
              if is_digit(d) {
                buffer.write_char(d)
                let _ = self.advance()
              } else {
                break
              }
            None => break
          }
        }
      } else {
        raise InvalidNumber(position, buffer.to_string())
      }
    None => raise InvalidNumber(position, buffer.to_string())
  }
  if self.peek() == Some('.') {
    match self.peek_at(1) {
      Some(d) =>
        if is_digit(d) {
          buffer.write_char('.')
          let _ = self.advance()
          while true {
            match self.peek() {
              Some(ch) =>
                if is_digit(ch) {
                  buffer.write_char(ch)
                  let _ = self.advance()
                } else {
                  break
                }
              None => break
            }
          }
        } else {
          raise InvalidNumber(position, buffer.to_string() + ".")
        }
      None => raise InvalidNumber(position, buffer.to_string() + ".")
    }
  }
  if self.peek() == Some('e') || self.peek() == Some('E') {
    let marker = match self.peek() {
      Some(ch) => ch
      None => 'e'
    }
    buffer.write_char(marker)
    let _ = self.advance()
    if self.peek() == Some('+') || self.peek() == Some('-') {
      let sign = match self.peek() {
        Some(ch) => ch
        None => '+'
      }
      buffer.write_char(sign)
      let _ = self.advance()
    }
    let mut digits = 0
    while true {
      match self.peek() {
        Some(ch) =>
          if is_digit(ch) {
            buffer.write_char(ch)
            let _ = self.advance()
            digits = digits + 1
          } else {
            break
          }
        None => break
      }
    }
    if digits == 0 {
      raise InvalidNumber(position, buffer.to_string())
    }
  }
  match self.peek() {
    Some(c) =>
      if is_ident_continue(c) {
        raise InvalidNumber(position, buffer.to_string())
      }
    None => ()
  }
  Token::new(NumberLit, buffer.to_string(), position)
}

///|
fn Scanner::scan_string(
  self : Scanner,
  position : Position,
) -> Token raise LexError {
  let _ = self.advance()
  let buffer = StringBuilder()
  while true {
    match self.peek() {
      None => raise UnterminatedString(position)
      Some('"') => {
        let _ = self.advance()
        break
      }
      Some('\\') => self.scan_escape(buffer)
      Some('\n') => raise UnterminatedString(position)
      Some(c) => {
        buffer.write_char(c)
        let _ = self.advance()
      }
    }
  }
  Token::new(StringLit, buffer.to_string(), position)
}

///|
fn Scanner::scan_escape(
  self : Scanner,
  buffer : StringBuilder,
) -> Unit raise LexError {
  let position = self.position()
  let _ = self.advance()
  match self.peek() {
    None => raise UnterminatedString(position)
    Some(c) => {
      let _ = self.advance()
      match c {
        '"' => buffer.write_char('"')
        '\\' => buffer.write_char('\\')
        '/' => buffer.write_char('/')
        'b' => buffer.write_char((8).to_char().unwrap())
        'f' => buffer.write_char((12).to_char().unwrap())
        'n' => buffer.write_char('\n')
        'r' => buffer.write_char('\r')
        't' => buffer.write_char('\t')
        'u' => self.scan_unicode_escape(buffer, position)
        _ => raise InvalidEscape(position, c)
      }
    }
  }
}

///|
fn Scanner::read_hex4(
  self : Scanner,
  position : Position,
) -> Int32 raise LexError {
  let mut value = 0
  for _i = 0; _i < 4; _i = _i + 1 {
    match self.peek() {
      Some(c) =>
        match hex_value(c) {
          Some(digit) => {
            value = value * 16 + digit
            let _ = self.advance()
          }
          None => raise InvalidUnicodeEscape(position)
        }
      None => raise InvalidUnicodeEscape(position)
    }
  }
  value
}

///|
fn Scanner::scan_unicode_escape(
  self : Scanner,
  buffer : StringBuilder,
  position : Position,
) -> Unit raise LexError {
  let high = self.read_hex4(position)
  if high >= 0xD800 && high <= 0xDBFF {
    if self.peek() == Some('\\') && self.peek_at(1) == Some('u') {
      let _ = self.advance()
      let _ = self.advance()
      let low = self.read_hex4(position)
      if low >= 0xDC00 && low <= 0xDFFF {
        let code = 0x10000 + ((high - 0xD800) << 10) + (low - 0xDC00)
        buffer.write_char(code.to_char().unwrap())
        return
      }
    }
    raise InvalidUnicodeEscape(position)
  }
  if high >= 0xDC00 && high <= 0xDFFF {
    raise InvalidUnicodeEscape(position)
  }
  buffer.write_char(high.to_char().unwrap())
}

///|
fn Scanner::scan_raw_string(
  self : Scanner,
  position : Position,
) -> Token raise LexError {
  let _ = self.advance()
  let buffer = StringBuilder()
  while true {
    match self.peek() {
      None => raise UnterminatedRawString(position)
      Some('`') => {
        let _ = self.advance()
        break
      }
      Some(c) => {
        buffer.write_char(c)
        let _ = self.advance()
      }
    }
  }
  Token::new(RawStringLit, buffer.to_string(), position)
}

///|
fn Scanner::scan_symbol(
  self : Scanner,
  c : Char,
  position : Position,
) -> Token raise LexError {
  let _ = self.advance()
  match c {
    '{' => Token::new(LBrace, "{", position)
    '}' => Token::new(RBrace, "}", position)
    '[' => Token::new(LBracket, "[", position)
    ']' => Token::new(RBracket, "]", position)
    '(' => Token::new(LParen, "(", position)
    ')' => Token::new(RParen, ")", position)
    ',' => Token::new(Comma, ",", position)
    ';' => Token::new(Semicolon, ";", position)
    '.' => Token::new(Dot, ".", position)
    '|' => Token::new(Pipe, "|", position)
    '&' => Token::new(Ampersand, "&", position)
    '+' => Token::new(Plus, "+", position)
    '-' => Token::new(Minus, "-", position)
    '*' => Token::new(Star, "*", position)
    '/' => Token::new(Slash, "/", position)
    '%' => Token::new(Percent, "%", position)
    ':' =>
      if self.peek() == Some('=') {
        let _ = self.advance()
        Token::new(Assign, ":=", position)
      } else {
        Token::new(Colon, ":", position)
      }
    '=' =>
      if self.peek() == Some('=') {
        let _ = self.advance()
        Token::new(EqualEqual, "==", position)
      } else {
        Token::new(Equal, "=", position)
      }
    '!' =>
      if self.peek() == Some('=') {
        let _ = self.advance()
        Token::new(NotEqual, "!=", position)
      } else {
        raise UnexpectedChar(position, '!')
      }
    '<' =>
      if self.peek() == Some('=') {
        let _ = self.advance()
        Token::new(LessEqual, "<=", position)
      } else {
        Token::new(Less, "<", position)
      }
    '>' =>
      if self.peek() == Some('=') {
        let _ = self.advance()
        Token::new(GreaterEqual, ">=", position)
      } else {
        Token::new(Greater, ">", position)
      }
    _ => raise UnexpectedChar(position, c)
  }
}

///|
/// Splits a Rego source text into tokens, ending with one `Eof` token.
///
/// Comments and whitespace are skipped. String tokens carry their decoded
/// value; raw string tokens carry their contents verbatim.
pub fn tokenize(source : String) -> Array[Token] raise LexError {
  let scanner = Scanner::new(source)
  let tokens : Array[Token] = []
  while true {
    let token = scanner.next_token()
    let done = token.kind == Eof
    tokens.push(token)
    if done {
      break
    }
  }
  tokens
}
