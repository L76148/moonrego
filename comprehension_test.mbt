///|
test "array comprehension" {
  assert_eq(
    parsed("[x | x := 1]"),
    @moonrego.Term::array_comprehension(
      [@moonrego.Expr::assign(v("x"), n("1"), pos(5, 1, 6))],
      v("x"),
    ),
  )
  assert_eq(
    parsed("[[x | x := 1]]"),
    @moonrego.Term::array_lit([
      @moonrego.Term::array_comprehension(
        [@moonrego.Expr::assign(v("x"), n("1"), pos(6, 1, 7))],
        v("x"),
      ),
    ]),
  )
}

///|
test "set comprehension" {
  assert_eq(
    parsed("{x | x := 1}"),
    @moonrego.Term::set_comprehension(
      [@moonrego.Expr::assign(v("x"), n("1"), pos(5, 1, 6))],
      v("x"),
    ),
  )
}

///|
test "object comprehension" {
  assert_eq(
    parsed("{k: v | k := \"a\"; v := 1}"),
    @moonrego.Term::object_comprehension(
      [
        @moonrego.Expr::assign(
          v("k"),
          @moonrego.Term::string("a"),
          pos(8, 1, 9),
        ),
        @moonrego.Expr::assign(v("v"), n("1"), pos(18, 1, 19)),
      ],
      v("k"),
      v("v"),
    ),
  )
}

///|
test "a union inside a comprehension body is still an operator" {
  assert_eq(
    parsed("{x | y := a | b}"),
    @moonrego.Term::set_comprehension(
      [
        @moonrego.Expr::assign(
          v("y"),
          @moonrego.Term::call("union", [v("a"), v("b")]),
          pos(5, 1, 6),
        ),
      ],
      v("x"),
    ),
  )
}

///|
test "parentheses keep a union as a set element" {
  assert_eq(
    parsed("{(a | b)}"),
    @moonrego.Term::set_lit([@moonrego.Term::call("union", [v("a"), v("b")])]),
  )
}

///|
test "a comprehension needs a body" {
  assert_eq(
    parse_error("[x | ]"),
    "expected a body statement, found ] at line 1, column 6",
  )
  assert_eq(
    parse_error("{x | }"),
    "expected a body statement, found } at line 1, column 6",
  )
  assert_eq(
    parse_error("{k: v | }"),
    "expected a body statement, found } at line 1, column 9",
  )
}
