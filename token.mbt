///|
/// A position in the source text. `offset` counts characters from the start of
/// the file, while `line` and `column` are one-based and meant for humans.
pub(all) struct Position {
  offset : Int32
  line : Int32
  column : Int32
} derive(Eq, @debug.Debug)

///|
pub extend Position with Eq::{equal, not_equal}

///|
pub extend Position with @debug.Debug::{to_repr}

///|
pub fn Position::new(offset : Int32, line : Int32, column : Int32) -> Position {
  { offset, line, column, }
}

///|
/// The lexical categories of Rego.
///
/// The variants that share a name with a built-in constructor or a core type
/// carry a suffix, so `SomeKeyword` and `StringLit` cannot be confused with
/// `Some` or `String`.
pub(all) enum TokenKind {
  Eof
  Ident
  NumberLit
  StringLit
  RawStringLit
  Package
  Import
  As
  Default
  Else
  Not
  SomeKeyword
  Every
  In
  If
  Contains
  With
  TrueKeyword
  FalseKeyword
  NullKeyword
  LBrace
  RBrace
  LBracket
  RBracket
  LParen
  RParen
  Comma
  Colon
  Semicolon
  Dot
  Pipe
  Ampersand
  Assign
  Equal
  EqualEqual
  NotEqual
  Less
  LessEqual
  Greater
  GreaterEqual
  Plus
  Minus
  Star
  Slash
  Percent
} derive(Eq, @debug.Debug)

///|
pub extend TokenKind with Eq::{equal, not_equal}

///|
pub extend TokenKind with @debug.Debug::{to_repr}

///|
/// A short name used in error messages and tests.
pub fn TokenKind::name(self : TokenKind) -> String {
  match self {
    Eof => "end of file"
    Ident => "identifier"
    NumberLit => "number"
    StringLit => "string"
    RawStringLit => "raw string"
    Package => "package"
    Import => "import"
    As => "as"
    Default => "default"
    Else => "else"
    Not => "not"
    SomeKeyword => "some"
    Every => "every"
    In => "in"
    If => "if"
    Contains => "contains"
    With => "with"
    TrueKeyword => "true"
    FalseKeyword => "false"
    NullKeyword => "null"
    LBrace => "{"
    RBrace => "}"
    LBracket => "["
    RBracket => "]"
    LParen => "("
    RParen => ")"
    Comma => ","
    Colon => ":"
    Semicolon => ";"
    Dot => "."
    Pipe => "|"
    Ampersand => "&"
    Assign => ":="
    Equal => "="
    EqualEqual => "=="
    NotEqual => "!="
    Less => "<"
    LessEqual => "<="
    Greater => ">"
    GreaterEqual => ">="
    Plus => "+"
    Minus => "-"
    Star => "*"
    Slash => "/"
    Percent => "%"
  }
}

///|
/// A token and where it came from.
///
/// `text` is the meaningful text: the identifier or keyword as written, the
/// numeric literal, the decoded value of a string, the contents of a raw
/// string, or the operator itself.
pub(all) struct Token {
  kind : TokenKind
  text : String
  position : Position
} derive(Eq, @debug.Debug)

///|
pub extend Token with Eq::{equal, not_equal}

///|
pub extend Token with @debug.Debug::{to_repr}

///|
pub fn Token::new(
  kind : TokenKind,
  text : String,
  position : Position,
) -> Token {
  { kind, text, position, }
}

///|
/// Whether a character may start an identifier.
pub fn is_ident_start(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'
}

///|
/// Whether a character may continue an identifier.
pub fn is_ident_continue(c : Char) -> Bool {
  is_ident_start(c) || (c >= '0' && c <= '9')
}

///|
/// The keyword kind for one identifier, or `None` for a plain identifier.
pub fn keyword_kind(text : String) -> TokenKind? {
  if text == "package" {
    Some(Package)
  } else if text == "import" {
    Some(Import)
  } else if text == "as" {
    Some(As)
  } else if text == "default" {
    Some(Default)
  } else if text == "else" {
    Some(Else)
  } else if text == "not" {
    Some(Not)
  } else if text == "some" {
    Some(SomeKeyword)
  } else if text == "every" {
    Some(Every)
  } else if text == "in" {
    Some(In)
  } else if text == "if" {
    Some(If)
  } else if text == "contains" {
    Some(Contains)
  } else if text == "with" {
    Some(With)
  } else if text == "true" {
    Some(TrueKeyword)
  } else if text == "false" {
    Some(FalseKeyword)
  } else if text == "null" {
    Some(NullKeyword)
  } else {
    None
  }
}
