///|
fn int_value(n : Int64) -> @moonrego.Value {
  @moonrego.Value::int(n)
}

///|
fn str_value(text : String) -> @moonrego.Value {
  @moonrego.Value::string(text)
}

///|
test "values render the way Rego prints them" {
  assert_eq(@moonrego.Value::null().to_rego_text(), "null")
  assert_eq(@moonrego.Value::boolean(true).to_rego_text(), "true")
  assert_eq(int_value(42L).to_rego_text(), "42")
  assert_eq(@moonrego.Value::float(3.5).to_rego_text(), "3.5")
  assert_eq(str_value("a\"b").to_rego_text(), "\"a\\\"b\"")
  assert_eq(str_value("x\ny").to_rego_text(), "\"x\\ny\"")
  assert_eq(
    @moonrego.Value::array([int_value(1L), str_value("x")]).to_rego_text(),
    "[1, \"x\"]",
  )
  assert_eq(
    @moonrego.Value::set([int_value(1L), int_value(2L)]).to_rego_text(),
    "{1, 2}",
  )
  assert_eq(
    @moonrego.Value::object([(str_value("k"), int_value(1L))]).to_rego_text(),
    "{\"k\": 1}",
  )
}

///|
test "sets drop duplicates" {
  let value = @moonrego.Value::set([int_value(1L), int_value(1L), int_value(2L)])
  assert_eq(value.length(), 2)
}

///|
test "equality compares numbers numerically and sets without order" {
  assert_true(int_value(1L).equals(@moonrego.Value::float(1.0)))
  assert_true(
    @moonrego.Value::set([int_value(1L), int_value(2L)]).equals(
      @moonrego.Value::set([int_value(2L), int_value(1L)]),
    ),
  )
  assert_true(
    @moonrego.Value::object([
      (str_value("a"), int_value(1L)),
      (str_value("b"), int_value(2L)),
    ]).equals(
      @moonrego.Value::object([
        (str_value("b"), int_value(2L)),
        (str_value("a"), int_value(1L)),
      ]),
    ),
  )
  assert_eq(int_value(1L).equals(int_value(2L)), false)
  assert_eq(int_value(1L).equals(str_value("1")), false)
}

///|
test "compare orders numbers and strings only" {
  assert_eq(int_value(1L).compare(@moonrego.Value::float(1.0)), Some(0))
  assert_eq(int_value(1L).compare(int_value(2L)), Some(-1))
  assert_eq(int_value(2L).compare(int_value(1L)), Some(1))
  assert_eq(str_value("a").compare(str_value("b")), Some(-1))
  assert_eq(int_value(1L).compare(str_value("a")), None)
}

///|
test "object helpers replace and append entries" {
  let object = @moonrego.Value::object([(str_value("a"), int_value(1L))])
  assert_eq(object.lookup(str_value("a")), Some(int_value(1L)))
  assert_eq(object.lookup(str_value("b")), None)
  let appended = object.with_entry(str_value("b"), int_value(2L))
  assert_eq(appended.length(), 2)
  assert_eq(appended.lookup(str_value("b")), Some(int_value(2L)))
  let replaced = object.with_entry(str_value("a"), int_value(9L))
  assert_eq(replaced.length(), 1)
  assert_eq(replaced.lookup(str_value("a")), Some(int_value(9L)))
}

///|
test "set helpers keep membership unique" {
  let set = @moonrego.Value::set([int_value(1L)])
  assert_true(set.element(int_value(1L)))
  assert_eq(set.element(int_value(2L)), false)
  assert_eq(set.with_element(int_value(1L)).length(), 1)
  assert_eq(set.with_element(int_value(2L)).length(), 2)
}

///|
test "number literals become ints or floats" {
  assert_eq(@moonrego.Value::number_literal("42"), int_value(42L))
  assert_eq(@moonrego.Value::number_literal("-7"), int_value(-7L))
  assert_eq(@moonrego.Value::number_literal("3.5"), @moonrego.Value::float(3.5))
  assert_eq(
    @moonrego.Value::number_literal("1e3"),
    @moonrego.Value::float(1000.0),
  )
  assert_eq(
    @moonrego.Value::number_literal("99999999999999999999"),
    @moonrego.Value::float(100000000000000000000.0),
  )
}

///|
test "json parses into values" {
  let value = @moonrego.parse_json_value(
    "{\"a\": [1, 2.5, true, null], \"b\": \"x\"}",
  )
  assert_eq(value.length(), 2)
  match value.lookup(str_value("a")) {
    Some(items) => {
      assert_eq(items.length(), 4)
      assert_eq(items.lookup(str_value("0")), None)
    }
    None => fail("missing key a")
  }
  assert_eq(value.lookup(str_value("b")), Some(str_value("x")))
  assert_eq(@moonrego.parse_json_value("42"), int_value(42L))
  assert_eq(@moonrego.parse_json_value("3.5"), @moonrego.Value::float(3.5))
  assert_eq(@moonrego.parse_json_value("null"), @moonrego.Value::null())
  assert_eq(@moonrego.parse_json_value("true"), @moonrego.Value::boolean(true))
}

///|
test "values convert back to json" {
  assert_eq(int_value(42L).to_json().stringify(), "42")
  assert_eq(str_value("x").to_json().stringify(), "\"x\"")
  assert_eq(
    @moonrego.Value::set([int_value(1L), int_value(2L)]).to_json().stringify(),
    "[1,2]",
  )
  assert_eq(
    @moonrego.Value::object([(str_value("k"), int_value(1L))])
    .to_json()
    .stringify(),
    "{\"k\":1}",
  )
  assert_eq(
    @moonrego.Value::object([(int_value(1L), str_value("x"))])
    .to_json()
    .stringify(),
    "{\"1\":\"x\"}",
  )
}

///|
test "json round trips through values" {
  let source = "{\"a\": [1, 2.5, true, null], \"b\": \"x\"}"
  let value = @moonrego.parse_json_value(source)
  let round = @moonrego.Value::from_json(value.to_json())
  assert_true(round.equals(value))
}
