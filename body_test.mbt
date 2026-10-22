///|
fn parsed_body(source : String) -> Array[@moonrego.Expr] {
  @moonrego.parse_body(source) catch {
    error => abort(error.message())
  }
}

///|
fn body_error(source : String) -> String {
  let error = try {
    let _ = @moonrego.parse_body(source)
    abort("expected a parse error")
  } catch {
    error => error
  }
  error.message()
}

///|
fn pos(offset : Int32, line : Int32, column : Int32) -> @moonrego.Position {
  @moonrego.Position::new(offset, line, column)
}

///|
test "newlines separate statements" {
  let body = parsed_body("x := 1\ny := 2")
  assert_eq(body.length(), 2)
  assert_eq(body[0], @moonrego.Expr::assign(v("x"), n("1"), pos(0, 1, 1)))
  assert_eq(body[1], @moonrego.Expr::assign(v("y"), n("2"), pos(7, 2, 1)))
}

///|
test "semicolons separate statements" {
  let body = parsed_body("x := 1; y := 2")
  assert_eq(body.length(), 2)
  assert_eq(body[0], @moonrego.Expr::assign(v("x"), n("1"), pos(0, 1, 1)))
  assert_eq(body[1], @moonrego.Expr::assign(v("y"), n("2"), pos(8, 1, 9)))
  assert_eq(parsed_body("x := 1;").length(), 1)
}

///|
test "a newline inside brackets does not split a statement" {
  let body = parsed_body("x := [1,\n 2]\ny := 3")
  assert_eq(body.length(), 2)
  assert_eq(
    body[0],
    @moonrego.Expr::assign(
      v("x"),
      @moonrego.Term::array_lit([n("1"), n("2")]),
      pos(0, 1, 1),
    ),
  )
  assert_eq(body[1], @moonrego.Expr::assign(v("y"), n("3"), pos(13, 3, 1)))
}

///|
test "some binds variables or iterates a collection" {
  assert_eq(parsed_body("some x, y in xs"), [
    @moonrego.Expr::some_in([v("x"), v("y")], v("xs"), pos(0, 1, 1)),
  ])
  assert_eq(parsed_body("some x"), [
    @moonrego.Expr::some_vars([v("x")], pos(0, 1, 1)),
  ])
}

///|
test "every takes a collection and a body" {
  let body = parsed_body("every x in xs { x > 0 }")
  assert_eq(body.length(), 1)
  assert_eq(
    body[0],
    @moonrego.Expr::every(
      [v("x")],
      v("xs"),
      [
        @moonrego.Expr::compare(
          @moonrego.CmpGreater,
          v("x"),
          n("0"),
          pos(16, 1, 17),
        ),
      ],
      pos(0, 1, 1),
    ),
  )
}

///|
test "not takes a term or a body" {
  assert_eq(parsed_body("not p[x]"), [
    @moonrego.Expr::not(
      [
        @moonrego.Expr::term(
          @moonrego.Term::reference(v("p"), [@moonrego.RefStep::index(v("x"))]),
          pos(4, 1, 5),
        ),
      ],
      pos(0, 1, 1),
    ),
  ])
  let body = parsed_body("not {\n  x := 1\n}")
  assert_eq(body.length(), 1)
  match body[0].kind {
    @moonrego.Not(inner) => {
      assert_eq(inner.length(), 1)
      assert_eq(inner[0], @moonrego.Expr::assign(v("x"), n("1"), pos(8, 2, 3)))
    }
    _ => fail("expected a negative body")
  }
}

///|
test "with modifiers attach to an expression" {
  let body = parsed_body("allow with input as {\"user\": \"alice\"}")
  assert_eq(body, [
    @moonrego.Expr::with_modifiers(
      @moonrego.Expr::term(v("allow"), pos(0, 1, 1)),
      [
        @moonrego.WithModifier::new(
          v("input"),
          @moonrego.Term::object_lit([
            (@moonrego.Term::string("user"), @moonrego.Term::string("alice")),
          ]),
        ),
      ],
      pos(0, 1, 1),
    ),
  ])
}

///|
test "statements on one line must be separated" {
  assert_eq(
    body_error("x := 1 y := 2"),
    "expected a statement separator, found identifier at line 1, column 8",
  )
  assert_eq(body_error("some"), "expected a term, found end of file")
  assert_eq(
    body_error("every x xs { }"),
    "expected 'in', found identifier at line 1, column 9",
  )
}
