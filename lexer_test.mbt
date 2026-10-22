///|
test "an empty source has only the end token" {
  assert_eq(kinds(""), [@moonrego.Eof])
  assert_eq(texts(""), [""])
}

///|
test "keywords are recognised" {
  assert_eq(
    kinds(
      "package import as default else not some every in if contains with true false null",
    ),
    [
      @moonrego.Package,
      @moonrego.Import,
      @moonrego.As,
      @moonrego.Default,
      @moonrego.Else,
      @moonrego.Not,
      @moonrego.SomeKeyword,
      @moonrego.Every,
      @moonrego.In,
      @moonrego.If,
      @moonrego.Contains,
      @moonrego.With,
      @moonrego.TrueKeyword,
      @moonrego.FalseKeyword,
      @moonrego.NullKeyword,
      @moonrego.Eof,
    ],
  )
}

///|
test "identifiers keep their text" {
  assert_eq(kinds("package example\nimport data.foo"), [
    @moonrego.Package,
    @moonrego.Ident,
    @moonrego.Import,
    @moonrego.Ident,
    @moonrego.Dot,
    @moonrego.Ident,
    @moonrego.Eof,
  ])
  assert_eq(texts("package example"), ["package", "example", ""])
  assert_eq(kinds("_ __ a1 A_9"), [
    @moonrego.Ident,
    @moonrego.Ident,
    @moonrego.Ident,
    @moonrego.Ident,
    @moonrego.Eof,
  ])
}

///|
test "numbers follow the JSON grammar" {
  assert_eq(texts("0 1 42 3.14 1e3 2.5e-2 6E+2"), [
    "0", "1", "42", "3.14", "1e3", "2.5e-2", "6E+2", "",
  ])
  assert_eq(kinds("0 1 2"), [
    @moonrego.NumberLit,
    @moonrego.NumberLit,
    @moonrego.NumberLit,
    @moonrego.Eof,
  ])
}

///|
test "malformed numbers are rejected" {
  assert_eq(lex_error("01"), "invalid number '0' at line 1, column 1")
  assert_eq(lex_error("1."), "invalid number '1.' at line 1, column 1")
  assert_eq(lex_error("1e"), "invalid number '1e' at line 1, column 1")
  assert_eq(lex_error("1e+"), "invalid number '1e+' at line 1, column 1")
  assert_eq(lex_error("1x"), "invalid number '1' at line 1, column 1")
}

///|
test "strings decode escapes" {
  assert_eq(texts("\"a\\nb\""), ["a\nb", ""])
  assert_eq(texts("\"\\u0041\""), ["A", ""])
  assert_eq(texts("\"quote: \\\"\""), ["quote: \"", ""])
  assert_eq(texts("\"tab\\there\""), ["tab\there", ""])
  assert_eq(texts("\"\\uD83D\\uDE00\""), ["😀", ""])
}

///|
test "raw strings keep their contents" {
  assert_eq(texts("`line1\nline2`"), ["line1\nline2", ""])
  assert_eq(kinds("`a\\nb`"), [@moonrego.RawStringLit, @moonrego.Eof])
  assert_eq(texts("`a\\nb`"), ["a\\nb", ""])
}

///|
test "string errors carry positions" {
  assert_eq(lex_error("\"abc"), "unterminated string at line 1, column 1")
  assert_eq(lex_error("\"a\\qb\""), "invalid escape '\\q' at line 1, column 3")
  assert_eq(lex_error("`abc"), "unterminated raw string at line 1, column 1")
  assert_eq(
    lex_error("\"\\u12\""),
    "invalid unicode escape at line 1, column 2",
  )
}

///|
test "comments and whitespace are skipped" {
  assert_eq(kinds("1 # first\n  2\t# second\n3"), [
    @moonrego.NumberLit,
    @moonrego.NumberLit,
    @moonrego.NumberLit,
    @moonrego.Eof,
  ])
  assert_eq(kinds("# only a comment\n"), [@moonrego.Eof])
}

///|
test "positions are one based and follow newlines" {
  let tokens = @moonrego.tokenize("a\n  bc")
  assert_eq(tokens[0].position.line, 1)
  assert_eq(tokens[0].position.column, 1)
  assert_eq(tokens[0].position.offset, 0)
  assert_eq(tokens[1].position.line, 2)
  assert_eq(tokens[1].position.column, 3)
  assert_eq(tokens[1].position.offset, 4)
  assert_eq(tokens[2].kind, @moonrego.Eof)
  assert_eq(tokens[2].position.line, 2)
  assert_eq(tokens[2].position.column, 5)
}

///|
test "operators are recognised" {
  assert_eq(kinds("= == != < <= > >= + - * / % := { } [ ] ( ) , : ; . | &"), [
    @moonrego.Equal,
    @moonrego.EqualEqual,
    @moonrego.NotEqual,
    @moonrego.Less,
    @moonrego.LessEqual,
    @moonrego.Greater,
    @moonrego.GreaterEqual,
    @moonrego.Plus,
    @moonrego.Minus,
    @moonrego.Star,
    @moonrego.Slash,
    @moonrego.Percent,
    @moonrego.Assign,
    @moonrego.LBrace,
    @moonrego.RBrace,
    @moonrego.LBracket,
    @moonrego.RBracket,
    @moonrego.LParen,
    @moonrego.RParen,
    @moonrego.Comma,
    @moonrego.Colon,
    @moonrego.Semicolon,
    @moonrego.Dot,
    @moonrego.Pipe,
    @moonrego.Ampersand,
    @moonrego.Eof,
  ])
}

///|
test "unexpected characters are rejected" {
  assert_eq(lex_error("@"), "unexpected character '@' at line 1, column 1")
  assert_eq(
    lex_error("package p\n  !"),
    "unexpected character '!' at line 2, column 3",
  )
}

///|
test "a semicolon separates statements without a newline" {
  assert_eq(kinds("a := 1; b := 2"), [
    @moonrego.Ident,
    @moonrego.Assign,
    @moonrego.NumberLit,
    @moonrego.Semicolon,
    @moonrego.Ident,
    @moonrego.Assign,
    @moonrego.NumberLit,
    @moonrego.Eof,
  ])
}
