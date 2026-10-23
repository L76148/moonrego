///|
/// An evaluation error. Undefined results are not errors: they are `None`.
pub(all) suberror EvalError {
  UnknownFunction(String)
  Unsupported(String)
  InvalidOperation(String)
  DivisionByZero
  RecursionLimit(String)
  Query(ParseError)
} derive(@debug.Debug)

///|
pub extend EvalError with @debug.Debug::{to_repr}

///|
/// A human readable explanation of the error.
pub fn EvalError::message(self : EvalError) -> String {
  match self {
    UnknownFunction(name) => "unknown function '" + name + "'"
    Unsupported(what) => "unsupported: " + what
    InvalidOperation(what) => "invalid operation: " + what
    DivisionByZero => "division by zero"
    RecursionLimit(name) =>
      "recursion limit reached while evaluating '" + name + "'"
    Query(error) => error.message()
  }
}

///|
priv struct Env {
  bindings : Map[String, Value]
}

///|
fn Env::empty() -> Env {
  { bindings: Map([]), }
}

///|
fn Env::get(self : Env, name : String) -> Value? {
  self.bindings.get(name)
}

///|
fn Env::binding(self : Env, name : String, value : Value) -> Env {
  let next = self.bindings.copy()
  next[name] = value
  { bindings: next, }
}

///|
fn bind_term(env : Env, target : Term, value : Value) -> Env? {
  match target {
    Var(name) =>
      if name == "_" {
        Some(env)
      } else {
        match env.get(name) {
          Some(existing) =>
            if existing.equals(value) {
              Some(env)
            } else {
              None
            }
          None => Some(env.binding(name, value))
        }
      }
    _ => None
  }
}

///|
fn compare_holds(op : CompareOp, ordering : Int32) -> Bool {
  match op {
    CmpEqual => ordering == 0
    CmpNotEqual => ordering != 0
    CmpLess => ordering < 0
    CmpLessEqual => ordering <= 0
    CmpGreater => ordering > 0
    CmpGreaterEqual => ordering >= 0
  }
}

///|
fn number_as_double(value : Value) -> Double? {
  match value {
    IntVal(integer) => Some(integer.to_double())
    FloatVal(float) => Some(float)
    _ => None
  }
}

///|
fn arithmetic(op : String, args : Array[Value]) -> Value? raise EvalError {
  if args.length() != 2 {
    raise EvalError::InvalidOperation(op + " takes two arguments")
  }
  match (args[0], args[1]) {
    (IntVal(left), IntVal(right)) =>
      match op {
        "plus" => Some(IntVal(left + right))
        "minus" => Some(IntVal(left - right))
        "mul" => Some(IntVal(left * right))
        "div" =>
          if right == 0L {
            raise EvalError::DivisionByZero
          } else {
            Some(IntVal(left / right))
          }
        "rem" =>
          if right == 0L {
            raise EvalError::DivisionByZero
          } else {
            Some(IntVal(left % right))
          }
        _ => None
      }
    _ => {
      let left = match number_as_double(args[0]) {
        Some(value) => value
        None => raise EvalError::InvalidOperation(op + " needs numbers")
      }
      let right = match number_as_double(args[1]) {
        Some(value) => value
        None => raise EvalError::InvalidOperation(op + " needs numbers")
      }
      match op {
        "plus" => Some(FloatVal(left + right))
        "minus" => Some(FloatVal(left - right))
        "mul" => Some(FloatVal(left * right))
        "div" =>
          if right == 0.0 {
            raise EvalError::DivisionByZero
          } else {
            Some(FloatVal(left / right))
          }
        "rem" => raise EvalError::InvalidOperation("rem needs integers")
        _ => None
      }
    }
  }
}

///|
fn set_operation(op : String, args : Array[Value]) -> Value? raise EvalError {
  if args.length() != 2 {
    raise EvalError::InvalidOperation(op + " takes two arguments")
  }
  let left = match args[0] {
    SetVal(items) => items
    _ => raise EvalError::InvalidOperation(op + " needs sets")
  }
  let right = match args[1] {
    SetVal(items) => items
    _ => raise EvalError::InvalidOperation(op + " needs sets")
  }
  if op == "union" {
    let combined : Array[Value] = []
    for item in left {
      combined.push(item)
    }
    for item in right {
      combined.push(item)
    }
    Some(Value::set(combined))
  } else if op == "intersection" {
    let shared : Array[Value] = []
    for item in left {
      let mut present = false
      for other in right {
        if item.equals(other) {
          present = true
        }
      }
      if present {
        shared.push(item)
      }
    }
    Some(Value::set(shared))
  } else {
    None
  }
}

///|
fn apply_builtin(name : String, args : Array[Value]) -> Value? raise EvalError {
  if name == "plus" ||
    name == "minus" ||
    name == "mul" ||
    name == "div" ||
    name == "rem" {
    arithmetic(name, args)
  } else if name == "union" || name == "intersection" {
    set_operation(name, args)
  } else {
    raise EvalError::UnknownFunction(name)
  }
}

///|
/// Evaluates one module against a data document and an input value.
///
/// This increment covers complete, partial set and partial object rules,
/// `default`, `else`, variable binding, references into `data` and `input`,
/// iteration with `some` and `every`, `not`, `with input as`, comprehensions
/// and the arithmetic and set operators. Function rules and other built-ins
/// arrive in later increments.
pub(all) struct Evaluator {
  module_ : Module
  data : Value
  input : Value
  mut rule_depth : Int32
} derive(@debug.Debug)

///|
pub extend Evaluator with @debug.Debug::{to_repr}

///|
pub fn Evaluator::new(
  module_ : Module,
  data : Value,
  input : Value,
) -> Evaluator {
  { module_, data, input, rule_depth: 0, }
}

///|
/// Parses a term as a query and evaluates it. `None` means undefined.
pub fn Evaluator::query_text(
  self : Evaluator,
  source : String,
) -> Value? raise EvalError {
  let term = parse_term(source) catch { error => raise Query(error) }
  self.eval_term(term, Env::empty())
}

///|
/// Evaluates one term. `None` means undefined.
pub fn Evaluator::query(
  self : Evaluator,
  term : Term,
) -> Value? raise EvalError {
  self.eval_term(term, Env::empty())
}

///|
fn lookup_index(value : Value, index : Value) -> Value? {
  match value {
    ArrayVal(items) =>
      match index {
        IntVal(position) =>
          if position >= 0L && position < items.length().to_int64() {
            Some(items[position.to_int()])
          } else {
            None
          }
        _ => None
      }
    ObjectVal(_) => value.lookup(index)
    SetVal(items) => {
      let mut found = None
      for item in items {
        if item.equals(index) {
          found = Some(index)
        }
      }
      found
    }
    _ => None
  }
}

///|
fn Evaluator::walk_ref(
  self : Evaluator,
  value : Value,
  steps : Array[RefStep],
  env : Env,
) -> Value? raise EvalError {
  let mut current = value
  for step in steps {
    let next = match step {
      Field(name) => current.lookup(Value::string(name))
      Index(term) =>
        match self.eval_term(term, env) {
          Some(index) => lookup_index(current, index)
          None => None
        }
    }
    match next {
      Some(value) => current = value
      None => return None
    }
  }
  Some(current)
}

///|
fn Evaluator::resolve_rule_path(
  self : Evaluator,
  steps : Array[RefStep],
) -> Value? raise EvalError {
  let names : Array[String] = []
  for step in steps {
    match step {
      Field(name) => names.push(name)
      Index(_) => return None
    }
  }
  if names.length() < 2 {
    return None
  }
  let prefix : Array[String] = []
  for i = 0; i < names.length() - 1; i = i + 1 {
    prefix.push(names[i])
  }
  if prefix == self.module_.package_path {
    self.rule_value(names[names.length() - 1])
  } else {
    None
  }
}

///|
fn Evaluator::eval_data_ref(
  self : Evaluator,
  steps : Array[RefStep],
  env : Env,
) -> Value? raise EvalError {
  match self.walk_ref(self.data, steps, env) {
    Some(value) => Some(value)
    None => self.resolve_rule_path(steps)
  }
}

///|
fn Evaluator::eval_term(
  self : Evaluator,
  term : Term,
  env : Env,
) -> Value? raise EvalError {
  match term {
    NullTerm => Some(Value::null())
    BoolTerm(value) => Some(Value::boolean(value))
    NumberTerm(text) => Some(Value::number_literal(text))
    StringTerm(text) => Some(Value::string(text))
    Var(name) =>
      match env.get(name) {
        Some(value) => Some(value)
        None =>
          if name == "input" {
            Some(self.input)
          } else if name == "data" {
            Some(self.data)
          } else {
            self.rule_value(name)
          }
      }
    Ref(base, steps) =>
      match base {
        Var(name) =>
          if name == "data" {
            self.eval_data_ref(steps, env)
          } else {
            match self.eval_term(base, env) {
              Some(value) => self.walk_ref(value, steps, env)
              None => None
            }
          }
        _ =>
          match self.eval_term(base, env) {
            Some(value) => self.walk_ref(value, steps, env)
            None => None
          }
      }
    ArrayLit(items) => {
      let values : Array[Value] = []
      for item in items {
        match self.eval_term(item, env) {
          Some(value) => values.push(value)
          None => return None
        }
      }
      Some(Value::array(values))
    }
    SetLit(items) => {
      let values : Array[Value] = []
      for item in items {
        match self.eval_term(item, env) {
          Some(value) => values.push(value)
          None => return None
        }
      }
      Some(Value::set(values))
    }
    ObjectLit(pairs) => {
      let values : Array[(Value, Value)] = []
      for pair in pairs {
        let key = self.eval_term(pair.0, env)
        let value = self.eval_term(pair.1, env)
        match (key, value) {
          (Some(k), Some(v)) => values.push((k, v))
          _ => return None
        }
      }
      Some(Value::object(values))
    }
    Call(callee, args) => self.eval_call(callee, args, env)
    ArrayComprehension(body, head) => {
      let solutions = self.eval_body(body, env)
      let values : Array[Value] = []
      for solution in solutions {
        match self.eval_term(head, solution) {
          Some(value) => values.push(value)
          None => ()
        }
      }
      Some(Value::array(values))
    }
    SetComprehension(body, head) => {
      let solutions = self.eval_body(body, env)
      let values : Array[Value] = []
      for solution in solutions {
        match self.eval_term(head, solution) {
          Some(value) => values.push(value)
          None => ()
        }
      }
      Some(Value::set(values))
    }
    ObjectComprehension(body, key, value) => {
      let solutions = self.eval_body(body, env)
      let pairs : Array[(Value, Value)] = []
      for solution in solutions {
        let evaluated_key = self.eval_term(key, solution)
        let evaluated_value = self.eval_term(value, solution)
        match (evaluated_key, evaluated_value) {
          (Some(k), Some(v)) => pairs.push((k, v))
          _ => ()
        }
      }
      Some(Value::object(pairs))
    }
  }
}

///|
fn Evaluator::eval_call(
  self : Evaluator,
  callee : Term,
  args : Array[Term],
  env : Env,
) -> Value? raise EvalError {
  let name = match callee {
    Var(name) => name
    _ => raise EvalError::Unsupported("only named functions are supported")
  }
  let values : Array[Value] = []
  for arg in args {
    match self.eval_term(arg, env) {
      Some(value) => values.push(value)
      None => return None
    }
  }
  match self.find_function_kind(name) {
    Some(Function) =>
      raise EvalError::Unsupported("function rules are not evaluated yet")
    _ => apply_builtin(name, values)
  }
}

///|
fn Evaluator::find_function_kind(self : Evaluator, name : String) -> RuleKind? {
  let mut found = None
  for rule in self.module_.rules {
    if rule.name == name && rule.kind == Function {
      found = Some(Function)
    }
  }
  found
}

///|
fn bind_vars(env : Env, vars : Array[Term], values : Array[Value]) -> Env? {
  let mut current = env
  if vars.length() != values.length() {
    return None
  }
  for i = 0; i < vars.length(); i = i + 1 {
    match bind_term(current, vars[i], values[i]) {
      Some(next) => current = next
      None => return None
    }
  }
  Some(current)
}

///|
fn Evaluator::eval_some_in(
  self : Evaluator,
  vars : Array[Term],
  collection : Term,
  env : Env,
) -> Array[Env] raise EvalError {
  let value = match self.eval_term(collection, env) {
    Some(value) => value
    None => return []
  }
  let solutions : Array[Env] = []
  match value {
    ArrayVal(items) =>
      for i = 0; i < items.length(); i = i + 1 {
        let values = if vars.length() == 1 {
          [items[i]]
        } else {
          [Value::int(i.to_int64()), items[i]]
        }
        match bind_vars(env, vars, values) {
          Some(next) => solutions.push(next)
          None => ()
        }
      }
    SetVal(items) =>
      for item in items {
        match bind_vars(env, vars, [item]) {
          Some(next) => solutions.push(next)
          None => ()
        }
      }
    ObjectVal(pairs) =>
      for pair in pairs {
        let values = if vars.length() == 1 {
          [pair.0]
        } else {
          [pair.0, pair.1]
        }
        match bind_vars(env, vars, values) {
          Some(next) => solutions.push(next)
          None => ()
        }
      }
    _ => ()
  }
  solutions
}

///|
fn Evaluator::eval_statement(
  self : Evaluator,
  expr : Expr,
  env : Env,
) -> Array[Env] raise EvalError {
  match expr.kind {
    Term(term) =>
      match self.eval_term(term, env) {
        Some(BoolVal(false)) => []
        Some(_) => [env]
        None => []
      }
    Assign(target, value) =>
      match self.eval_term(value, env) {
        Some(result) =>
          match bind_term(env, target, result) {
            Some(next) => [next]
            None => []
          }
        None => []
      }
    Unify(left, right) => {
      let left_bound = match left {
        Var(name) => env.get(name)
        _ => None
      }
      let right_bound = match right {
        Var(name) => env.get(name)
        _ => None
      }
      match (left_bound, right_bound) {
        (Some(left_value), _) =>
          match self.eval_term(right, env) {
            Some(right_value) =>
              if left_value.equals(right_value) {
                [env]
              } else {
                []
              }
            None => []
          }
        (None, Some(right_value)) =>
          match bind_term(env, left, right_value) {
            Some(next) => [next]
            None => []
          }
        (None, None) =>
          match self.eval_term(right, env) {
            Some(right_value) =>
              match bind_term(env, left, right_value) {
                Some(next) => [next]
                None => []
              }
            None => []
          }
      }
    }
    Compare(op, left, right) =>
      match (self.eval_term(left, env), self.eval_term(right, env)) {
        (Some(left_value), Some(right_value)) =>
          match left_value.compare(right_value) {
            Some(ordering) =>
              if compare_holds(op, ordering) {
                [env]
              } else {
                []
              }
            None => []
          }
        _ => []
      }
    SomeVars(_) => [env]
    SomeIn(vars, collection) => self.eval_some_in(vars, collection, env)
    Every(vars, collection, body) => {
      let value = match self.eval_term(collection, env) {
        Some(value) => value
        None => return []
      }
      let elements = match value {
        ArrayVal(items) => items
        SetVal(items) => items
        _ => return []
      }
      for element in elements {
        let bound = match bind_vars(env, vars, [element]) {
          Some(next) => next
          None => return []
        }
        if self.eval_body(body, bound).length() == 0 {
          return []
        }
      }
      [env]
    }
    Not(body) =>
      if self.eval_body(body, env).length() == 0 {
        [env]
      } else {
        []
      }
    With(inner, modifiers) => {
      let mut input = self.input
      for modifier in modifiers {
        let value = match self.eval_term(modifier.value, env) {
          Some(value) => value
          None => return []
        }
        match modifier.target {
          Var(name) =>
            if name == "input" {
              input = value
            } else {
              raise EvalError::Unsupported("with is only supported for input")
            }
          _ => raise EvalError::Unsupported("with is only supported for input")
        }
      }
      let scoped = Evaluator::new(self.module_, self.data, input)
      scoped.eval_statement(inner, env)
    }
  }
}

///|
fn Evaluator::eval_body(
  self : Evaluator,
  body : Array[Expr],
  env : Env,
) -> Array[Env] raise EvalError {
  let mut solutions : Array[Env] = [env]
  for statement in body {
    let next : Array[Env] = []
    for solution in solutions {
      for result in self.eval_statement(statement, solution) {
        next.push(result)
      }
    }
    solutions = next
  }
  solutions
}

///|
fn Evaluator::eval_complete_rule(
  self : Evaluator,
  rule : Rule,
) -> Value? raise EvalError {
  let solutions = self.eval_body(rule.body, Env::empty())
  if solutions.length() > 0 {
    match rule.value {
      Some(term) => self.eval_term(term, solutions[0])
      None => Some(Value::boolean(true))
    }
  } else {
    let mut result : Value? = None
    for branch in rule.else_rules {
      let branch_solutions = self.eval_body(branch.body, Env::empty())
      if branch_solutions.length() > 0 {
        result = match branch.value {
          Some(term) => self.eval_term(term, branch_solutions[0])
          None => Some(Value::boolean(true))
        }
        break
      }
    }
    result
  }
}

///|
fn Evaluator::eval_rule_set(
  self : Evaluator,
  rules : Array[Rule],
) -> Value? raise EvalError {
  let mut complete : Value? = None
  let set_items : Array[Value] = []
  let object_pairs : Array[(Value, Value)] = []
  for rule in rules {
    match rule.kind {
      Complete =>
        match self.eval_complete_rule(rule) {
          Some(value) => complete = Some(value)
          None => ()
        }
      PartialSet => {
        let solutions = self.eval_body(rule.body, Env::empty())
        for solution in solutions {
          match rule.key {
            Some(element) =>
              match self.eval_term(element, solution) {
                Some(value) => set_items.push(value)
                None => ()
              }
            None => ()
          }
        }
      }
      PartialObject => {
        let solutions = self.eval_body(rule.body, Env::empty())
        for solution in solutions {
          let key = match rule.key {
            Some(term) => self.eval_term(term, solution)
            None => None
          }
          let value = match rule.value {
            Some(term) => self.eval_term(term, solution)
            None => None
          }
          match (key, value) {
            (Some(k), Some(v)) => object_pairs.push((k, v))
            _ => ()
          }
        }
      }
      Function =>
        raise EvalError::Unsupported("function rules are not evaluated yet")
    }
  }
  if set_items.length() > 0 {
    Some(Value::set(set_items))
  } else if object_pairs.length() > 0 {
    Some(Value::object(object_pairs))
  } else {
    complete
  }
}

///|
fn Evaluator::rule_value(
  self : Evaluator,
  name : String,
) -> Value? raise EvalError {
  let regular : Array[Rule] = []
  let defaults : Array[Rule] = []
  for rule in self.module_.rules {
    if rule.name == name {
      if rule.is_default {
        defaults.push(rule)
      } else {
        regular.push(rule)
      }
    }
  }
  if regular.length() == 0 && defaults.length() == 0 {
    return None
  }
  if self.rule_depth > 64 {
    raise EvalError::RecursionLimit(name)
  }
  self.rule_depth = self.rule_depth + 1
  let value = self.eval_rule_set(regular)
  self.rule_depth = self.rule_depth - 1
  match value {
    Some(result) => Some(result)
    None =>
      if defaults.length() == 0 {
        None
      } else {
        self.rule_depth = self.rule_depth + 1
        let fallback = self.eval_rule_set(defaults)
        self.rule_depth = self.rule_depth - 1
        fallback
      }
  }
}
