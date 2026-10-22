///|
fn parsed(source : String) -> @moonrego.Term {
  @moonrego.parse_term(source) catch {
    error => abort(error.message())
  }
}

///|
fn parse_error(source : String) -> String {
  let error = try {
    let _ = @moonrego.parse_term(source)
    abort("expected a parse error")
  } catch {
    error => error
  }
  error.message()
}

///|
fn num(text : String) -> @moonrego.Term {
  @moonrego.Term::number(text)
}

///|
fn var_(name : String) -> @moonrego.Term {
  @moonrego.Term::variable(name)
}

///|
test "scalars parse" {
  assert_eq(parsed("null"), @moonrego.Term::null())
  assert_eq(parsed("true"), @moonrego.Term::boolean(true))
  assert_eq(parsed("false"), @moonrego.Term::boolean(false))
  assert_eq(parsed("42"), num("42"))
  assert_eq(parsed("3.14"), num("3.14"))
  assert_eq(parsed("-3.5"), num("-3.5"))
  assert_eq(parsed("--3"), num("3"))
  assert_eq(parsed("\"hi\""), @moonrego.Term::string("hi"))
  assert_eq(parsed("`raw`"), @moonrego.Term::string("raw"))
  assert_eq(parsed("_"), var_("_"))
}

///|
test "references keep field and index steps" {
  assert_eq(
    parsed("input.user.name"),
    @moonrego.Term::reference(var_("input"), [
      @moonrego.RefStep::field("user"),
      @moonrego.RefStep::field("name"),
    ]),
  )
  assert_eq(
    parsed("xs[0]"),
    @moonrego.Term::reference(var_("xs"), [@moonrego.RefStep::index(num("0"))]),
  )
  assert_eq(
    parsed("data.foo[\"bar\"].baz"),
    @moonrego.Term::reference(var_("data"), [
      @moonrego.RefStep::field("foo"),
      @moonrego.RefStep::index(@moonrego.Term::string("bar")),
      @moonrego.RefStep::field("baz"),
    ]),
  )
}

///|
test "calls parse with names and references as callees" {
  assert_eq(parsed("count(xs)"), @moonrego.Term::call("count", [var_("xs")]))
  assert_eq(parsed("f()"), @moonrego.Term::call("f", []))
  assert_eq(parsed("f(1, 2)"), @moonrego.Term::call("f", [num("1"), num("2")]))
  assert_eq(parsed("f(1,)"), @moonrego.Term::call("f", [num("1")]))
  assert_eq(
    parsed("json.marshal(x)"),
    @moonrego.Term::call_term(
      @moonrego.Term::reference(var_("json"), [
        @moonrego.RefStep::field("marshal"),
      ]),
      [var_("x")],
    ),
  )
}

///|
test "arrays parse, including nesting and trailing commas" {
  assert_eq(parsed("[]"), @moonrego.Term::array_lit([]))
  assert_eq(
    parsed("[1, 2, 3]"),
    @moonrego.Term::array_lit([num("1"), num("2"), num("3")]),
  )
  assert_eq(
    parsed("[1, [2, 3]]"),
    @moonrego.Term::array_lit([
      num("1"),
      @moonrego.Term::array_lit([num("2"), num("3")]),
    ]),
  )
  assert_eq(parsed("[1,]"), @moonrego.Term::array_lit([num("1")]))
}

///|
test "objects and sets parse" {
  assert_eq(parsed("{}"), @moonrego.Term::object_lit([]))
  assert_eq(
    parsed("{\"a\": 1, \"b\": true}"),
    @moonrego.Term::object_lit([
      (@moonrego.Term::string("a"), num("1")),
      (@moonrego.Term::string("b"), @moonrego.Term::boolean(true)),
    ]),
  )
  assert_eq(
    parsed("{1: \"x\"}"),
    @moonrego.Term::object_lit([(num("1"), @moonrego.Term::string("x"))]),
  )
  assert_eq(parsed("{1, 2}"), @moonrego.Term::set_lit([num("1"), num("2")]))
  assert_eq(parsed("{1}"), @moonrego.Term::set_lit([num("1")]))
}

///|
test "parentheses group terms and suffixes" {
  assert_eq(parsed("((42))"), num("42"))
  assert_eq(
    parsed("(input).x"),
    @moonrego.Term::reference(var_("input"), [@moonrego.RefStep::field("x")]),
  )
}

///|
test "unary minus folds numbers and rewrites other terms" {
  assert_eq(parsed("-x"), @moonrego.Term::call("minus", [num("0"), var_("x")]))
  assert_eq(
    parsed("-input.count"),
    @moonrego.Term::call("minus", [
      num("0"),
      @moonrego.Term::reference(var_("input"), [
        @moonrego.RefStep::field("count"),
      ]),
    ]),
  )
}

///|
test "parse errors carry expectations and positions" {
  assert_eq(parse_error(""), "expected a term, found end of file")
  assert_eq(
    parse_error("1 2"),
    "unexpected trailing tokens at line 1, column 3",
  )
  assert_eq(parse_error("[1,"), "expected a term, found end of file")
  assert_eq(
    parse_error("f(1 2)"),
    "expected ',' or ')', found number at line 1, column 5",
  )
  assert_eq(
    parse_error("{1: }"),
    "expected a term, found } at line 1, column 5",
  )
}

///|
test "lexical errors surface through the parser" {
  assert_eq(parse_error("\"abc"), "unterminated string at line 1, column 1")
  assert_eq(parse_error("@"), "unexpected character '@' at line 1, column 1")
}
