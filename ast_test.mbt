///|
fn start() -> @moonrego.Position {
  @moonrego.Position::new(0, 1, 1)
}

///|
test "a module keeps its package, imports and rules" {
  let position = start()
  let imported = @moonrego.Import::new(["data", "foo"], Some("foo"), position)
  let value = @moonrego.Expr::term(@moonrego.Term::boolean(true), position)
  let rule = @moonrego.Rule::function(
    "allow",
    ["user"],
    Some(value),
    [],
    position,
  )
  let module_ = @moonrego.Module::new(["example"], [imported], [rule], position)
  assert_eq(module_.package_path, ["example"])
  assert_eq(module_.imports.length(), 1)
  assert_eq(module_.imports[0].alias_name, Some("foo"))
  assert_eq(module_.rules.length(), 1)
  assert_eq(module_.rules[0].kind, @moonrego.Function)
  assert_eq(module_.rules[0].args, ["user"])
  assert_eq(module_.rules[0].value, Some(value))
}

///|
test "a rule can be marked default or extended with else branches" {
  let position = start()
  let value = @moonrego.Expr::term(@moonrego.Term::boolean(false), position)
  let rule = @moonrego.Rule::complete("allow", Some(value), [], position)
  assert_eq(rule.is_default, false)
  let defaulted = { ..rule, is_default: true, }
  assert_true(defaulted.is_default)
  let branch = @moonrego.ElseRule::new(Some(value), [], position)
  let extended = { ..rule, else_rules: [branch], }
  assert_eq(extended.else_rules.length(), 1)
  assert_eq(extended.else_rules[0].value, Some(value))
}

///|
test "a reference keeps its base and steps" {
  let reference = @moonrego.Term::reference(@moonrego.Term::variable("input"), [
    @moonrego.RefStep::field("user"),
    @moonrego.RefStep::index(@moonrego.Term::string("roles")),
  ])
  match reference {
    @moonrego.Ref(base, steps) => {
      assert_eq(base, @moonrego.Term::variable("input"))
      assert_eq(steps.length(), 2)
      assert_eq(steps[0], @moonrego.RefStep::field("user"))
      assert_eq(
        steps[1],
        @moonrego.RefStep::index(@moonrego.Term::string("roles")),
      )
    }
    _ => fail("expected a reference")
  }
}

///|
test "comparison operators map from tokens" {
  assert_eq(
    @moonrego.CompareOp::from_token(@moonrego.EqualEqual),
    Some(@moonrego.CmpEqual),
  )
  assert_eq(
    @moonrego.CompareOp::from_token(@moonrego.NotEqual),
    Some(@moonrego.CmpNotEqual),
  )
  assert_eq(
    @moonrego.CompareOp::from_token(@moonrego.Less),
    Some(@moonrego.CmpLess),
  )
  assert_eq(
    @moonrego.CompareOp::from_token(@moonrego.LessEqual),
    Some(@moonrego.CmpLessEqual),
  )
  assert_eq(
    @moonrego.CompareOp::from_token(@moonrego.Greater),
    Some(@moonrego.CmpGreater),
  )
  assert_eq(
    @moonrego.CompareOp::from_token(@moonrego.GreaterEqual),
    Some(@moonrego.CmpGreaterEqual),
  )
  assert_eq(@moonrego.CompareOp::from_token(@moonrego.Plus), None)
  assert_eq(@moonrego.CmpGreater.to_string(), ">")
}

///|
test "expression constructors build the expected kinds" {
  let position = start()

  let compared = @moonrego.Expr::compare(
    @moonrego.CmpGreater,
    @moonrego.Term::call("count", [@moonrego.Term::variable("xs")]),
    @moonrego.Term::number("1"),
    position,
  )
  match compared.kind {
    @moonrego.Compare(op, left, right) => {
      assert_eq(op, @moonrego.CmpGreater)
      assert_eq(
        left,
        @moonrego.Term::call("count", [@moonrego.Term::variable("xs")]),
      )
      assert_eq(right, @moonrego.Term::number("1"))
    }
    _ => fail("expected a comparison")
  }
  let bound = @moonrego.Expr::assign(
    @moonrego.Term::variable("n"),
    @moonrego.Term::call("count", [@moonrego.Term::variable("xs")]),
    position,
  )
  match bound.kind {
    @moonrego.Assign(target, value) => {
      assert_eq(target, @moonrego.Term::variable("n"))
      assert_eq(
        value,
        @moonrego.Term::call("count", [@moonrego.Term::variable("xs")]),
      )
    }
    _ => fail("expected an assignment")
  }
  let quantified = @moonrego.Expr::some_in(
    [@moonrego.Term::variable("x")],
    @moonrego.Term::variable("xs"),
    position,
  )
  match quantified.kind {
    @moonrego.SomeIn(vars, collection) => {
      assert_eq(vars.length(), 1)
      assert_eq(collection, @moonrego.Term::variable("xs"))
    }
    _ => fail("expected a some-in expression")
  }
}

///|
test "comprehension terms compare structurally" {
  let position = start()
  let body = [@moonrego.Expr::term(@moonrego.Term::variable("x"), position)]
  let term = @moonrego.Term::array_comprehension(
    body,
    @moonrego.Term::variable("x"),
  )
  assert_eq(
    term,
    @moonrego.Term::array_comprehension(body, @moonrego.Term::variable("x")),
  )
  assert_not_eq(
    term,
    @moonrego.Term::set_comprehension(body, @moonrego.Term::variable("x")),
  )
  assert_eq(
    @moonrego.Term::object_comprehension(
      body,
      @moonrego.Term::variable("k"),
      @moonrego.Term::variable("v"),
    ),
    @moonrego.Term::object_comprehension(
      body,
      @moonrego.Term::variable("k"),
      @moonrego.Term::variable("v"),
    ),
  )
}
