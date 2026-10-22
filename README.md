# MoonRego

A Rego (Open Policy Agent) implementation for MoonBit: lexer, parser, evaluator
and a command line tool.

Status: the project is initialised. The lexer is the next increment, and the
public surface currently exposes only `version()` and the CLI skeleton.

## Why

Rego is the policy language of Open Policy Agent: Kubernetes admission control,
Terraform and Conftest checks, and authorization in microservices all speak it.
MoonBit already has Cedar (`jaredzhou/mooncedar`) and CEL
(`aloyscc/moon_cel`), but `moon search rego` and `moon search "opa policy"`
return no modules. A MoonBit service that needs to evaluate existing Rego
policies has no native way to do it.

This project fills that gap with an original MoonBit implementation: a
hand-written lexer and Pratt parser, an evaluator with virtual documents and
partial sets, a JSON data and input bridge, and a CLI that answers the same
queries as `opa eval`.

## Scope

- Lexer and parser for Rego modules: packages, imports, complete and partial
  rules, `default`, `else`, function rules, `some`, `every`, `not`,
  comprehensions and references.
- Evaluator: data and input documents, virtual documents, rule iteration,
  partial sets and objects, and Rego's undefined semantics.
- Built-ins: comparison, arithmetic, strings, arrays, objects, sets, type
  checks and JSON helpers.
- CLI: `eval`, `check` and `parse`.
- A conformance corpus derived from public OPA cases.

Out of scope: bundles, decision logs, partial evaluation, the OPA REST server
and built-ins that need external I/O.

## Install

Planned for the first release:

```text
moon add L76148/moonrego
```

## Use

```text
moon run cmd/moonrego -- eval --data data.json --input input.json policy.rego 'data.example.allow'
```

## Design

The lexer and parser are hand-written so errors carry line and column
information. The evaluator works on a value model with sets and objects and
follows Rego's semantics: a rule that cannot be satisfied produces no result
instead of an error. Rules are indexed by package path and evaluated lazily
with memoisation per query, and comprehensions are evaluated as generators so
that `some` and `every` share the same iteration machinery.

## Roadmap

1. Lexer, tokens and source positions.
2. Parser and AST: modules, rules, expressions, comprehensions.
3. Value model and the JSON bridge.
4. Evaluator: documents, rules, references, iteration.
5. Built-ins, the CLI commands and the conformance corpus.
6. First release on mooncakes.io.

## License

Apache-2.0. Rego and Open Policy Agent are the semantic reference; no Go source
code is copied. See `NOTICE.md`.