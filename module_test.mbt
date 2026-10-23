///|
fn parsed_module(source : String) -> @moonrego.Module {
  @moonrego.parse_module(source) catch {
    error => abort(error.message())
  }
}

///|
fn module_error(source : String) -> String {
  let error = try {
    let _ = @moonrego.parse_module(source)
    abort("expected a parse error")
  } catch {
    error => error
  }
  error.message()
}

///|
test "a module needs a package and may have no rules" {
  let module_ = parsed_module("package example\n")
  assert_eq(module_.package_path, ["example"])
  assert_eq(module_.imports.length(), 0)
  assert_eq(module_.rules.length(), 0)
  assert_eq(module_.position, pos(0, 1, 1))
}

///|
test "imports keep their path and alias" {
  let module_ = parsed_module(
    "package example\nimport data.foo\nimport future.keywords.if as kw\n",
  )
  assert_eq(module_.imports.length(), 2)
  assert_eq(module_.imports[0].path, ["data", "foo"])
  assert_eq(module_.imports[0].alias_name, None)
  assert_eq(module_.imports[1].path, ["future", "keywords", "if"])
  assert_eq(module_.imports[1].alias_name, Some("kw"))
}

///|
test "a complete rule may be a fact" {
  let module_ = parsed_module("package p\nallow := true\n")
  assert_eq(module_.rules.length(), 1)
  let rule = module_.rules[0]
  assert_eq(rule.kind, @moonrego.Complete)
  assert_eq(rule.name, "allow")
  assert_eq(rule.value, Some(@moonrego.Term::boolean(true)))
  assert_eq(rule.body.length(), 0)
  assert_eq(rule.is_default, false)
  assert_eq(rule.position, pos(10, 2, 1))
}

///|
test "a rule body follows if" {
  let module_ = parsed_module("package p\nallow if {\n  x := 1\n  x > 0\n}\n")
  assert_eq(module_.rules.length(), 1)
  let body = module_.rules[0].body
  assert_eq(body.length(), 2)
  assert_eq(body[0], @moonrego.Expr::assign(v("x"), n("1"), pos(23, 3, 3)))
  assert_eq(
    body[1],
    @moonrego.Expr::compare(@moonrego.CmpGreater, v("x"), n("0"), pos(32, 4, 3)),
  )
}

///|
test "the legacy body form without if still parses" {
  let module_ = parsed_module("package p\nallow {\n  true\n}\n")
  assert_eq(module_.rules[0].body.length(), 1)
  assert_eq(module_.rules[0].value, None)
}

///|
test "a contains rule is a partial set" {
  let module_ = parsed_module(
    "package p\nnames contains x if {\n  x := \"a\"\n}\n",
  )
  let rule = module_.rules[0]
  assert_eq(rule.kind, @moonrego.PartialSet)
  assert_eq(rule.key, Some(v("x")))
  assert_eq(rule.body.length(), 1)
}

///|
test "a bracketed rule with a value is a partial object" {
  let module_ = parsed_module(
    "package p\nsizes[key] := value if {\n  key := \"a\"\n  value := 1\n}\n",
  )
  let rule = module_.rules[0]
  assert_eq(rule.kind, @moonrego.PartialObject)
  assert_eq(rule.key, Some(v("key")))
  assert_eq(rule.value, Some(v("value")))
  assert_eq(rule.body.length(), 2)
}

///|
test "a function rule keeps its parameters" {
  let module_ = parsed_module("package p\nadd(a, b) := a + b\n")
  let rule = module_.rules[0]
  assert_eq(rule.kind, @moonrego.Function)
  assert_eq(rule.args, ["a", "b"])
  assert_eq(rule.value, Some(@moonrego.Term::call("plus", [v("a"), v("b")])))
}

///|
test "default and else are recorded" {
  let module_ = parsed_module(
    "package p\ndefault allow := false\nallow if {\n  true\n} else := true\n",
  )
  assert_eq(module_.rules.length(), 2)
  assert_true(module_.rules[0].is_default)
  assert_eq(module_.rules[0].value, Some(@moonrego.Term::boolean(false)))
  assert_eq(module_.rules[1].else_rules.length(), 1)
  assert_eq(
    module_.rules[1].else_rules[0].value,
    Some(@moonrego.Term::boolean(true)),
  )
}

///|
test "module errors point at the offending token" {
  assert_eq(
    module_error("allow := true"),
    "expected 'package', found identifier at line 1, column 1",
  )
  assert_eq(
    module_error("package p\nimport"),
    "expected an import path, found end of file",
  )
  assert_eq(
    module_error("package p\nallow := true deny := false"),
    "expected a newline between rules, found identifier at line 2, column 15",
  )
}
