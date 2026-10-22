///|
/// One parsed Rego module: its package, imports and rules.
pub(all) struct Module {
  package_path : Array[String]
  imports : Array[Import]
  rules : Array[Rule]
  position : Position
} derive(Eq, @debug.Debug)

///|
pub extend Module with Eq::{equal, not_equal}

///|
pub extend Module with @debug.Debug::{to_repr}

///|
pub fn Module::new(
  package_path : Array[String],
  imports : Array[Import],
  rules : Array[Rule],
  position : Position,
) -> Module {
  { package_path, imports, rules, position, }
}

///|
/// One `import` declaration. `path` keeps every segment, so
/// `import data.foo.bar as baz` is `["data", "foo", "bar"]` with alias `baz`.
pub(all) struct Import {
  path : Array[String]
  alias_name : String?
  position : Position
} derive(Eq, @debug.Debug)

///|
pub extend Import with Eq::{equal, not_equal}

///|
pub extend Import with @debug.Debug::{to_repr}

///|
pub fn Import::new(
  path : Array[String],
  alias_name : String?,
  position : Position,
) -> Import {
  { path, alias_name, position, }
}

///|
/// The shape of a rule head.
pub(all) enum RuleKind {
  /// `name := value` or `name if { body }`
  Complete
  /// `name contains element if { body }`
  PartialSet
  /// `name[key] := value if { body }`
  PartialObject
  /// `name(args) := value if { body }`
  Function
} derive(Eq, @debug.Debug)

///|
pub extend RuleKind with Eq::{equal, not_equal}

///|
pub extend RuleKind with @debug.Debug::{to_repr}

///|
pub extend RuleKind with Show::{to_string, output}

///|
pub impl Show for RuleKind with fn output(self, logger) {
  logger.write_string(
    match self {
      Complete => "complete"
      PartialSet => "partial set"
      PartialObject => "partial object"
      Function => "function"
    },
  )
}

///|
/// One rule, including its head, optional value, body and `else` branches.
///
/// An empty `body` means the rule is a fact. A `None` value means the rule
/// produces `true` when its body holds, as in `allow if { ... }`.
pub(all) struct Rule {
  kind : RuleKind
  name : String
  args : Array[String]
  key : Term?
  value : Expr?
  body : Array[Expr]
  is_default : Bool
  else_rules : Array[ElseRule]
  position : Position
} derive(Eq, @debug.Debug)

///|
pub extend Rule with Eq::{equal, not_equal}

///|
pub extend Rule with @debug.Debug::{to_repr}

///|
fn Rule::empty(
  kind : RuleKind,
  name : String,
  key : Term?,
  value : Expr?,
  body : Array[Expr],
  position : Position,
) -> Rule {
  {
    kind,
    name,
    args: [],
    key,
    value,
    body,
    is_default: false,
    else_rules: [],
    position,
  }
}

///|
/// A complete rule: `name := value` or `name if { body }`.
pub fn Rule::complete(
  name : String,
  value : Expr?,
  body : Array[Expr],
  position : Position,
) -> Rule {
  Rule::empty(Complete, name, None, value, body, position)
}

///|
/// A partial set rule: `name contains element if { body }`.
pub fn Rule::partial_set(
  name : String,
  element : Term,
  body : Array[Expr],
  position : Position,
) -> Rule {
  Rule::empty(PartialSet, name, Some(element), None, body, position)
}

///|
/// A partial object rule: `name[key] := value if { body }`.
pub fn Rule::partial_object(
  name : String,
  key : Term,
  value : Expr,
  body : Array[Expr],
  position : Position,
) -> Rule {
  Rule::empty(PartialObject, name, Some(key), Some(value), body, position)
}

///|
/// A function rule: `name(args) := value if { body }`.
pub fn Rule::function(
  name : String,
  args : Array[String],
  value : Expr?,
  body : Array[Expr],
  position : Position,
) -> Rule {
  let rule = Rule::empty(Function, name, None, value, body, position)
  { ..rule, args, }
}

///|
/// One `else` branch of a rule.
pub(all) struct ElseRule {
  value : Expr?
  body : Array[Expr]
  position : Position
} derive(Eq, @debug.Debug)

///|
pub extend ElseRule with Eq::{equal, not_equal}

///|
pub extend ElseRule with @debug.Debug::{to_repr}

///|
pub fn ElseRule::new(
  value : Expr?,
  body : Array[Expr],
  position : Position,
) -> ElseRule {
  { value, body, position, }
}

///|
/// A comparison operator inside an expression.
pub(all) enum CompareOp {
  CmpEqual
  CmpNotEqual
  CmpLess
  CmpLessEqual
  CmpGreater
  CmpGreaterEqual
} derive(Eq, @debug.Debug)

///|
pub extend CompareOp with Eq::{equal, not_equal}

///|
pub extend CompareOp with @debug.Debug::{to_repr}

///|
pub extend CompareOp with Show::{to_string, output}

///|
pub impl Show for CompareOp with fn output(self, logger) {
  logger.write_string(
    match self {
      CmpEqual => "=="
      CmpNotEqual => "!="
      CmpLess => "<"
      CmpLessEqual => "<="
      CmpGreater => ">"
      CmpGreaterEqual => ">="
    },
  )
}

///|
/// The comparison operator for one token, or `None` when the token is not a
/// comparison.
pub fn CompareOp::from_token(kind : TokenKind) -> CompareOp? {
  match kind {
    EqualEqual => Some(CmpEqual)
    NotEqual => Some(CmpNotEqual)
    Less => Some(CmpLess)
    LessEqual => Some(CmpLessEqual)
    Greater => Some(CmpGreater)
    GreaterEqual => Some(CmpGreaterEqual)
    _ => None
  }
}

///|
/// One expression in a rule body.
pub(all) struct Expr {
  kind : ExprKind
  position : Position
} derive(Eq, @debug.Debug)

///|
pub extend Expr with Eq::{equal, not_equal}

///|
pub extend Expr with @debug.Debug::{to_repr}

///|
pub fn Expr::new(kind : ExprKind, position : Position) -> Expr {
  { kind, position, }
}

///|
/// The shape of one expression.
pub(all) enum ExprKind {
  /// A bare term, which is true when the term is defined and not false.
  Term(Term)
  /// `term := term`
  Assign(Term, Term)
  /// `term = term`
  Unify(Term, Term)
  /// `left op right`
  Compare(CompareOp, Term, Term)
  /// `some x, y`
  SomeVars(Array[Term])
  /// `some x, y in collection`
  SomeIn(Array[Term], Term)
  /// `every x in collection { body }`
  Every(Array[Term], Term, Array[Expr])
  /// `not { body }` or `not expr`
  Not(Array[Expr])
  /// `expr with target as value`
  With(Expr, Array[WithModifier])
} derive(Eq, @debug.Debug)

///|
pub extend ExprKind with Eq::{equal, not_equal}

///|
pub extend ExprKind with @debug.Debug::{to_repr}

///|
pub fn Expr::term(term : Term, position : Position) -> Expr {
  Expr::new(Term(term), position)
}

///|
pub fn Expr::assign(target : Term, value : Term, position : Position) -> Expr {
  Expr::new(Assign(target, value), position)
}

///|
pub fn Expr::unify(target : Term, value : Term, position : Position) -> Expr {
  Expr::new(Unify(target, value), position)
}

///|
pub fn Expr::compare(
  op : CompareOp,
  left : Term,
  right : Term,
  position : Position,
) -> Expr {
  Expr::new(Compare(op, left, right), position)
}

///|
pub fn Expr::some_vars(vars : Array[Term], position : Position) -> Expr {
  Expr::new(SomeVars(vars), position)
}

///|
pub fn Expr::some_in(
  vars : Array[Term],
  collection : Term,
  position : Position,
) -> Expr {
  Expr::new(SomeIn(vars, collection), position)
}

///|
pub fn Expr::every(
  vars : Array[Term],
  collection : Term,
  body : Array[Expr],
  position : Position,
) -> Expr {
  Expr::new(Every(vars, collection, body), position)
}

///|
pub fn Expr::not(body : Array[Expr], position : Position) -> Expr {
  Expr::new(Not(body), position)
}

///|
pub fn Expr::with_modifiers(
  expr : Expr,
  modifiers : Array[WithModifier],
  position : Position,
) -> Expr {
  Expr::new(With(expr, modifiers), position)
}

///|
/// One `with target as value` modifier.
pub(all) struct WithModifier {
  target : Term
  value : Term
} derive(Eq, @debug.Debug)

///|
pub extend WithModifier with Eq::{equal, not_equal}

///|
pub extend WithModifier with @debug.Debug::{to_repr}

///|
pub fn WithModifier::new(target : Term, value : Term) -> WithModifier {
  { target, value, }
}

///|
/// A term: a value-producing piece of syntax.
///
/// Numbers keep their literal text, because Rego numbers are arbitrary
/// precision and the evaluator decides how to represent them. A leading minus
/// is folded into the literal by the parser.
pub(all) enum Term {
  NullTerm
  BoolTerm(Bool)
  NumberTerm(String)
  StringTerm(String)
  Var(String)
  Ref(Term, Array[RefStep])
  ArrayLit(Array[Term])
  ObjectLit(Array[(Term, Term)])
  SetLit(Array[Term])
  Call(Term, Array[Term])
  ArrayComprehension(Array[Expr], Term)
  SetComprehension(Array[Expr], Term)
  ObjectComprehension(Array[Expr], Term, Term)
} derive(Eq, @debug.Debug)

///|
pub extend Term with Eq::{equal, not_equal}

///|
pub extend Term with @debug.Debug::{to_repr}

///|
pub fn Term::null() -> Term {
  NullTerm
}

///|
pub fn Term::boolean(value : Bool) -> Term {
  BoolTerm(value)
}

///|
pub fn Term::number(literal : String) -> Term {
  NumberTerm(literal)
}

///|
pub fn Term::string(value : String) -> Term {
  StringTerm(value)
}

///|
pub fn Term::variable(name : String) -> Term {
  Var(name)
}

///|
pub fn Term::reference(base : Term, steps : Array[RefStep]) -> Term {
  Ref(base, steps)
}

///|
pub fn Term::array_lit(items : Array[Term]) -> Term {
  ArrayLit(items)
}

///|
pub fn Term::object_lit(pairs : Array[(Term, Term)]) -> Term {
  ObjectLit(pairs)
}

///|
pub fn Term::set_lit(items : Array[Term]) -> Term {
  SetLit(items)
}

///|
pub fn Term::call(name : String, args : Array[Term]) -> Term {
  Call(Term::variable(name), args)
}

///|
pub fn Term::call_term(callee : Term, args : Array[Term]) -> Term {
  Call(callee, args)
}

///|
pub fn Term::array_comprehension(body : Array[Expr], value : Term) -> Term {
  ArrayComprehension(body, value)
}

///|
pub fn Term::set_comprehension(body : Array[Expr], value : Term) -> Term {
  SetComprehension(body, value)
}

///|
pub fn Term::object_comprehension(
  body : Array[Expr],
  key : Term,
  value : Term,
) -> Term {
  ObjectComprehension(body, key, value)
}

///|
/// One step of a reference: a field access or an index expression.
pub(all) enum RefStep {
  Field(String)
  Index(Term)
} derive(Eq, @debug.Debug)

///|
pub extend RefStep with Eq::{equal, not_equal}

///|
pub extend RefStep with @debug.Debug::{to_repr}

///|
pub fn RefStep::field(name : String) -> RefStep {
  Field(name)
}

///|
pub fn RefStep::index(term : Term) -> RefStep {
  Index(term)
}
