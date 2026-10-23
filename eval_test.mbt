///|
fn evaluate(
  module_source : String,
  data_json : String,
  input_json : String,
  query : String,
) -> @moonrego.Value? {
  let module_ = @moonrego.parse_module(module_source) catch {
    error => abort(error.message())
  }
  let data = @moonrego.parse_json_value(data_json) catch {
    error => abort(error.to_string())
  }
  let input = @moonrego.parse_json_value(input_json) catch {
    error => abort(error.to_string())
  }
  let evaluator = @moonrego.Evaluator::new(module_, data, input)
  evaluator.query_text(query) catch {
    error => abort(error.message())
  }
}

///|
fn evaluate_error(module_source : String, query : String) -> String {
  let module_ = @moonrego.parse_module(module_source) catch {
    error => abort(error.message())
  }
  let evaluator = @moonrego.Evaluator::new(
    module_,
    @moonrego.Value::object([]),
    @moonrego.Value::object([]),
  )
  let error = try {
    let _ = evaluator.query_text(query)
    abort("expected an evaluation error")
  } catch {
    error => error
  }
  error.message()
}

///|
fn bool_value(value : Bool) -> @moonrego.Value {
  @moonrego.Value::boolean(value)
}

///|
test "a complete rule evaluates its body" {
  let source = "package example\nallow if {\n  input.user == \"alice\"\n}\n"
  assert_eq(
    evaluate(source, "{}", "{\"user\": \"alice\"}", "data.example.allow"),
    Some(bool_value(true)),
  )
  assert_eq(
    evaluate(source, "{}", "{\"user\": \"bob\"}", "data.example.allow"),
    None,
  )
}

///|
test "default applies when the rules are undefined" {
  let source = "package example\ndefault allow := false\nallow if { input.user == \"alice\" }\n"
  assert_eq(
    evaluate(source, "{}", "{\"user\": \"bob\"}", "data.example.allow"),
    Some(bool_value(false)),
  )
  assert_eq(
    evaluate(source, "{}", "{\"user\": \"alice\"}", "data.example.allow"),
    Some(bool_value(true)),
  )
}

///|
test "partial sets collect body solutions" {
  let source = "package example\nnames contains x if {\n  x := input.name\n}\n"
  assert_eq(
    evaluate(source, "{}", "{\"name\": \"alice\"}", "data.example.names"),
    Some(@moonrego.Value::set([@moonrego.Value::string("alice")])),
  )
}

///|
test "partial objects collect keys and values" {
  let source = "package example\nsizes[k] := v if {\n  k := \"a\"\n  v := 1\n}\n"
  assert_eq(
    evaluate(source, "{}", "{}", "data.example.sizes"),
    Some(
      @moonrego.Value::object([
        (@moonrego.Value::string("a"), @moonrego.Value::int(1L)),
      ]),
    ),
  )
}

///|
test "arithmetic and comparison evaluate" {
  let source = "package example\nanswer if {\n  x := 1 + 2\n  x == 3\n}\n"
  assert_eq(
    evaluate(source, "{}", "{}", "data.example.answer"),
    Some(bool_value(true)),
  )
  let wrong = "package example\nanswer if {\n  x := 2 * 3\n  x == 5\n}\n"
  assert_eq(evaluate(wrong, "{}", "{}", "data.example.answer"), None)
}

///|
test "some in iterates a collection" {
  let source = "package example\nany_big if {\n  some x in [1, 2, 3]\n  x > 2\n}\n"
  assert_eq(
    evaluate(source, "{}", "{}", "data.example.any_big"),
    Some(bool_value(true)),
  )
  let pairs = "package example\nvalues contains v if {\n  some k, v in input.map\n}\n"
  match
    evaluate(
      pairs, "{}", "{\"map\": {\"a\": 1, \"b\": 2}}", "data.example.values",
    ) {
    Some(value) =>
      assert_true(
        value.equals(
          @moonrego.Value::set([
            @moonrego.Value::int(1L),
            @moonrego.Value::int(2L),
          ]),
        ),
      )
    None => fail("expected a set")
  }
}

///|
test "every requires the body for each element" {
  let source = "package example\nall_positive if {\n  every x in [1, 2] { x > 0 }\n}\n"
  assert_eq(
    evaluate(source, "{}", "{}", "data.example.all_positive"),
    Some(bool_value(true)),
  )
  let failing = "package example\nall_positive if {\n  every x in [1, -2] { x > 0 }\n}\n"
  assert_eq(evaluate(failing, "{}", "{}", "data.example.all_positive"), None)
}

///|
test "not negates a body" {
  let source = "package example\ndenied if {\n  not input.ok\n}\n"
  assert_eq(
    evaluate(source, "{}", "{\"ok\": false}", "data.example.denied"),
    Some(bool_value(true)),
  )
  assert_eq(
    evaluate(source, "{}", "{\"ok\": true}", "data.example.denied"),
    None,
  )
}

///|
test "comprehensions collect evaluated values" {
  let source = "package example\ndoubled := [x | x := input.n]\n"
  assert_eq(
    evaluate(source, "{}", "{\"n\": 5}", "data.example.doubled"),
    Some(@moonrego.Value::array([@moonrego.Value::int(5L)])),
  )
}

///|
test "with input overrides the input document" {
  let source = "package example\nallow if { input.user == \"alice\" }\nforced := true if {\n  allow with input as {\"user\": \"alice\"}\n}\n"
  assert_eq(
    evaluate(source, "{}", "{}", "data.example.forced"),
    Some(bool_value(true)),
  )
  assert_eq(evaluate(source, "{}", "{}", "data.example.allow"), None)
}

///|
test "rules read the data document" {
  let source = "package example\nok if {\n  data.limit > 10\n}\n"
  assert_eq(
    evaluate(source, "{\"limit\": 20}", "{}", "data.example.ok"),
    Some(bool_value(true)),
  )
  assert_eq(evaluate(source, "{\"limit\": 5}", "{}", "data.example.ok"), None)
}

///|
test "unqualified names resolve to rules in the same package" {
  let source = "package example\nbase := 2\ndoubled if {\n  base == 2\n}\n"
  assert_eq(
    evaluate(source, "{}", "{}", "data.example.doubled"),
    Some(bool_value(true)),
  )
}

///|
test "evaluation errors are reported" {
  assert_eq(
    evaluate_error("package example\nx := f(1)\n", "data.example.x"),
    "unknown function 'f'",
  )
  assert_eq(
    evaluate_error("package example\nx := 1 / 0\n", "data.example.x"),
    "division by zero",
  )
}
