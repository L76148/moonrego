///|
/// Tokenizes or fails the test with the lexical error message.
fn tokens_of(source : String) -> Array[@moonrego.Token] {
  @moonrego.tokenize(source) catch {
    error => abort(error.message())
  }
}

///|
/// The token kinds of one source text, including the trailing `Eof`.
fn kinds(source : String) -> Array[@moonrego.TokenKind] {
  let out : Array[@moonrego.TokenKind] = []
  for token in tokens_of(source) {
    out.push(token.kind)
  }
  out
}

///|
/// The token texts of one source text, including the empty `Eof` text.
fn texts(source : String) -> Array[String] {
  let out : Array[String] = []
  for token in tokens_of(source) {
    out.push(token.text)
  }
  out
}

///|
/// The message of the first lexical error in one source text.
fn lex_error(source : String) -> String {
  let error = try {
    let _ = @moonrego.tokenize(source)
    abort("expected a lexical error")
  } catch {
    error => error
  }
  error.message()
}
