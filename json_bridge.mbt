///|
fn object_key_text(key : Value) -> String {
  match key {
    StringVal(text) => text
    _ => key.to_rego_text()
  }
}

///|
/// Converts a value to JSON.
///
/// Sets become arrays, which is what Rego does when it serialises a set to
/// JSON. Object keys that are not strings are rendered with `to_rego_text`.
pub fn Value::to_json(self : Value) -> Json {
  match self {
    NullVal => Json::null()
    BoolVal(value) => Json::boolean(value)
    IntVal(value) => Json::number(value.to_double(), repr=value.to_string())
    FloatVal(value) => Json::number(value)
    StringVal(text) => Json::string(text)
    ArrayVal(items) => Json::array(items.map(fn(item) { item.to_json() }))
    SetVal(items) => Json::array(items.map(fn(item) { item.to_json() }))
    ObjectVal(pairs) => {
      let map : Map[String, Json] = Map([])
      for pair in pairs {
        map[object_key_text(pair.0)] = pair.1.to_json()
      }
      Json::object(map)
    }
  }
}

///|
/// Converts JSON to a value.
///
/// Numbers that are integral and within the safe integer range become
/// `IntVal`; other numbers stay `FloatVal`.
pub fn Value::from_json(json : Json) -> Value {
  match json {
    Json::Null => NullVal
    Json::True => BoolVal(true)
    Json::False => BoolVal(false)
    Json::Number(value, ..) =>
      if value >= -9007199254740992.0 &&
        value <= 9007199254740992.0 &&
        value.to_int64().to_double() == value {
        IntVal(value.to_int64())
      } else {
        FloatVal(value)
      }
    Json::String(text) => StringVal(text)
    Json::Array(items) =>
      ArrayVal(items.map(fn(item) { Value::from_json(item) }))
    Json::Object(map) => {
      let pairs : Array[(Value, Value)] = []
      for entry in map.to_array() {
        pairs.push((StringVal(entry.0), Value::from_json(entry.1)))
      }
      ObjectVal(pairs)
    }
  }
}

///|
/// Parses JSON text into a value.
pub fn parse_json_value(source : String) -> Value raise @json.ParseError {
  Value::from_json(@json.parse(source))
}
