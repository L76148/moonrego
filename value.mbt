///|
/// A Rego value.
///
/// Integers are kept as `Int64` and other numbers as `Double`; arbitrary
/// precision decimals arrive in a later increment. Objects and sets are flat
/// arrays with linear lookup, which lets any term act as a key without
/// imposing a hashable representation.
pub(all) enum Value {
  NullVal
  BoolVal(Bool)
  IntVal(Int64)
  FloatVal(Double)
  StringVal(String)
  ArrayVal(Array[Value])
  ObjectVal(Array[(Value, Value)])
  SetVal(Array[Value])
} derive(Eq, @debug.Debug)

///|
pub extend Value with Eq::{equal, not_equal}

///|
pub extend Value with @debug.Debug::{to_repr}

///|
pub extend Value with Show::{to_string, output}

///|
pub impl Show for Value with fn output(self, logger) {
  logger.write_string(Value::to_rego_text(self))
}

///|
pub fn Value::null() -> Value {
  NullVal
}

///|
pub fn Value::boolean(value : Bool) -> Value {
  BoolVal(value)
}

///|
pub fn Value::int(value : Int64) -> Value {
  IntVal(value)
}

///|
pub fn Value::float(value : Double) -> Value {
  FloatVal(value)
}

///|
pub fn Value::string(value : String) -> Value {
  StringVal(value)
}

///|
pub fn Value::array(items : Array[Value]) -> Value {
  ArrayVal(items)
}

///|
pub fn Value::object(pairs : Array[(Value, Value)]) -> Value {
  ObjectVal(pairs)
}

///|
/// A set with duplicate elements removed.
pub fn Value::set(items : Array[Value]) -> Value {
  let unique : Array[Value] = []
  for item in items {
    if !contains_value(unique, item) {
      unique.push(item)
    }
  }
  SetVal(unique)
}

///|
/// Builds a number from a Rego literal. A literal with a fraction or an
/// exponent becomes a `Double`; an integer that fits becomes an `Int64`.
pub fn Value::number_literal(text : String) -> Value {
  let mut fractional = false
  for c in text.to_array() {
    if c == '.' || c == 'e' || c == 'E' {
      fractional = true
    }
  }
  if fractional {
    FloatVal(@string.parse_double(text) catch { _error => 0.0 })
  } else {
    let parsed = Some(@string.parse_int64(text)) catch { _error => None }
    match parsed {
      Some(value) => IntVal(value)
      None => FloatVal(@string.parse_double(text) catch { _error => 0.0 })
    }
  }
}

///|
fn compare_double(left : Double, right : Double) -> Int32 {
  if left < right {
    -1
  } else if left > right {
    1
  } else {
    0
  }
}

///|
/// Rego equality: integers and floats compare by numeric value, sets compare
/// regardless of order, and objects compare by key.
pub fn Value::equals(self : Value, other : Value) -> Bool {
  match (self, other) {
    (NullVal, NullVal) => true
    (BoolVal(left), BoolVal(right)) => left == right
    (IntVal(left), IntVal(right)) => left == right
    (FloatVal(left), FloatVal(right)) => left == right
    (IntVal(left), FloatVal(right)) => left.to_double() == right
    (FloatVal(left), IntVal(right)) => left == right.to_double()
    (StringVal(left), StringVal(right)) => left == right
    (ArrayVal(left), ArrayVal(right)) => values_equal(left, right)
    (SetVal(left), SetVal(right)) => sets_equal(left, right)
    (ObjectVal(left), ObjectVal(right)) => objects_equal(left, right)
    _ => false
  }
}

///|
fn values_equal(left : Array[Value], right : Array[Value]) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for i = 0; i < left.length(); i = i + 1 {
    if !left[i].equals(right[i]) {
      return false
    }
  }
  true
}

///|
fn contains_value(items : Array[Value], target : Value) -> Bool {
  for item in items {
    if item.equals(target) {
      return true
    }
  }
  false
}

///|
fn sets_equal(left : Array[Value], right : Array[Value]) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for item in left {
    if !contains_value(right, item) {
      return false
    }
  }
  true
}

///|
fn objects_equal(
  left : Array[(Value, Value)],
  right : Array[(Value, Value)],
) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for pair in left {
    match object_get(right, pair.0) {
      Some(value) => if !value.equals(pair.1) { return false }
      None => return false
    }
  }
  true
}

///|
fn object_get(pairs : Array[(Value, Value)], key : Value) -> Value? {
  for pair in pairs {
    if pair.0.equals(key) {
      return Some(pair.1)
    }
  }
  None
}

///|
/// Orders two values that Rego can compare, or returns `None` when the types
/// do not form an ordering.
pub fn Value::compare(self : Value, other : Value) -> Int32? {
  match (self, other) {
    (IntVal(left), IntVal(right)) =>
      Some(if left < right { -1 } else if left > right { 1 } else { 0 })
    (FloatVal(left), FloatVal(right)) => Some(compare_double(left, right))
    (IntVal(left), FloatVal(right)) =>
      Some(compare_double(left.to_double(), right))
    (FloatVal(left), IntVal(right)) =>
      Some(compare_double(left, right.to_double()))
    (StringVal(left), StringVal(right)) =>
      Some(if left < right { -1 } else if left > right { 1 } else { 0 })
    _ => None
  }
}

///|
/// Looks up a key in an object, or returns `None` for other values.
pub fn Value::lookup(self : Value, key : Value) -> Value? {
  match self {
    ObjectVal(pairs) => object_get(pairs, key)
    _ => None
  }
}

///|
/// Returns an object with the key set to the value, replacing an existing
/// entry.
pub fn Value::with_entry(self : Value, key : Value, value : Value) -> Value {
  match self {
    ObjectVal(pairs) => {
      let next : Array[(Value, Value)] = []
      let mut replaced = false
      for pair in pairs {
        if pair.0.equals(key) {
          next.push((key, value))
          replaced = true
        } else {
          next.push(pair)
        }
      }
      if !replaced {
        next.push((key, value))
      }
      ObjectVal(next)
    }
    _ => ObjectVal([(key, value)])
  }
}

///|
/// Whether a set contains an element.
pub fn Value::element(self : Value, target : Value) -> Bool {
  match self {
    SetVal(items) => contains_value(items, target)
    _ => false
  }
}

///|
/// Returns a set with the element added once.
pub fn Value::with_element(self : Value, item : Value) -> Value {
  match self {
    SetVal(items) =>
      if contains_value(items, item) {
        SetVal(items)
      } else {
        let next : Array[Value] = []
        for existing in items {
          next.push(existing)
        }
        next.push(item)
        SetVal(next)
      }
    _ => SetVal([item])
  }
}

///|
/// The number of elements: array and set items, object entries, or string
/// characters. Scalars have length zero.
pub fn Value::length(self : Value) -> Int32 {
  match self {
    ArrayVal(items) | SetVal(items) => items.length()
    ObjectVal(pairs) => pairs.length()
    StringVal(text) => text.length()
    _ => 0
  }
}

///|
fn escape_string(text : String) -> String {
  let buffer = StringBuilder()
  for c in text.to_array() {
    match c {
      '"' => buffer.write_string("\\\"")
      '\\' => buffer.write_string("\\\\")
      '\n' => buffer.write_string("\\n")
      '\r' => buffer.write_string("\\r")
      '\t' => buffer.write_string("\\t")
      _ => buffer.write_char(c)
    }
  }
  buffer.to_string()
}

///|
/// Renders the value the way Rego prints it: strings are quoted, sets use
/// braces, and objects keep their insertion order.
pub fn Value::to_rego_text(self : Value) -> String {
  match self {
    NullVal => "null"
    BoolVal(true) => "true"
    BoolVal(false) => "false"
    IntVal(value) => value.to_string()
    FloatVal(value) => value.to_string()
    StringVal(text) => "\"" + escape_string(text) + "\""
    ArrayVal(items) => {
      let buffer = StringBuilder()
      buffer.write_char('[')
      for i = 0; i < items.length(); i = i + 1 {
        if i > 0 {
          buffer.write_string(", ")
        }
        buffer.write_string(items[i].to_rego_text())
      }
      buffer.write_char(']')
      buffer.to_string()
    }
    SetVal(items) => {
      let buffer = StringBuilder()
      buffer.write_char('{')
      for i = 0; i < items.length(); i = i + 1 {
        if i > 0 {
          buffer.write_string(", ")
        }
        buffer.write_string(items[i].to_rego_text())
      }
      buffer.write_char('}')
      buffer.to_string()
    }
    ObjectVal(pairs) => {
      let buffer = StringBuilder()
      buffer.write_char('{')
      for i = 0; i < pairs.length(); i = i + 1 {
        if i > 0 {
          buffer.write_string(", ")
        }
        buffer.write_string(pairs[i].0.to_rego_text())
        buffer.write_string(": ")
        buffer.write_string(pairs[i].1.to_rego_text())
      }
      buffer.write_char('}')
      buffer.to_string()
    }
  }
}
