///|
fn parsed_expr(source : String) -> @moonrego.Expr {
  @moonrego.parse_expr(source) catch {
    error => abort(error.message())
  }
}

///|
fn expr_error(source : String) -> String {
  let error = try {
    let _ = @moonrego.parse_expr(source)
    abort("expected a parse error")
  } catch {
    error => error
  }
  error.message()
}

///|
fn at_start() -> @moonrego.Position {
  @moonrego.Position::new(0, 1, 1)
}

///|
fn n(text : String) -> @moonrego.Term {
  @moonrego.Term::number(text)
}

///|
fn v(name : String) -> @moonrego.Term {
  @moonrego.Term::variable(name)
}

///|
fn call(name : String, args : Array[@moonrego.Term]) -> @moonrego.Term {
  @moonrego.Term::call(name, args)
}

///|
test "a bare term is a value expression" {
  assert_eq(parsed_expr("1"), @moonrego.Expr::term(n("1"), at_start()))
}

///|
test "arithmetic follows precedence" {
  assert_eq(
    parsed_expr("1 + 2 * 3"),
    @moonrego.Expr::term(
      call("plus", [n("1"), call("mul", [n("2"), n("3")])]),
      @moonrego.Position::new(0, 1, 1),
    ),
  )
  assert_eq(
    parsed_expr("(1 + 2) * 3"),
    @moonrego.Expr::term(
      call("mul", [call("plus", [n("1"), n("2")]), n("3")]),
      @moonrego.Position::new(0, 1, 1),
    ),
  )
  assert_eq(
    parsed_expr("a - b - c"),
    @moonrego.Expr::term(
      call("minus", [call("minus", [v("a"), v("b")]), v("c")]),
      @moonrego.Position::new(0, 1, 1),
    ),
  )
  assert_eq(
    parsed_expr("s1 | s2 & s3"),
    @moonrego.Expr::term(
      call("union", [v("s1"), call("intersection", [v("s2"), v("s3")])]),
      @moonrego.Position::new(0, 1, 1),
    ),
  )
}

///|
test "unary minus binds tighter than multiplication" {
  assert_eq(
    parsed_expr("-a * b"),
    @moonrego.Expr::term(
      call("mul", [call("minus", [n("0"), v("a")]), v("b")]),
      @moonrego.Position::new(0, 1, 1),
    ),
  )
}

///|
test "assignment and unification take a term on the right" {
  assert_eq(
    parsed_expr("x := 1 + 2"),
    @moonrego.Expr::assign(v("x"), call("plus", [n("1"), n("2")]), at_start()),
  )
  assert_eq(
    parsed_expr("x = 1"),
    @moonrego.Expr::unify(v("x"), n("1"), at_start()),
  )
}

///|
test "comparisons compare two terms" {
  assert_eq(
    parsed_expr("count(xs) > 1"),
    @moonrego.Expr::compare(
      @moonrego.CmpGreater,
      call("count", [v("xs")]),
      n("1"),
      at_start(),
    ),
  )
  assert_eq(
    parsed_expr("a <= b"),
    @moonrego.Expr::compare(@moonrego.CmpLessEqual, v("a"), v("b"), at_start()),
  )
}

///|
test "terms parse arithmetic too" {
  assert_eq(@moonrego.parse_term("1 + 2"), call("plus", [n("1"), n("2")]))
}

///|
test "expression errors report the missing term" {
  assert_eq(expr_error("x :="), "expected a term, found end of file")
  assert_eq(expr_error("1 +"), "expected a term, found end of file")
  assert_eq(expr_error("1 <"), "expected a term, found end of file")
  assert_eq(
    expr_error("x := y := z"),
    "unexpected trailing tokens at line 1, column 8",
  )
}
