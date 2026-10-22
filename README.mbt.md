# L76148/moonrego

A Rego (Open Policy Agent) implementation for MoonBit: lexer, parser, evaluator
and a command line tool.

The project is developed one capability at a time. This release initialises the
package, the licence and the command line skeleton; the lexer is next.

## Why Rego

Rego is the policy language of Open Policy Agent: Kubernetes admission control,
Terraform and Conftest checks, and authorization in microservices all speak it.
MoonBit already has Cedar (`jaredzhou/mooncedar`) and CEL
(`aloyscc/moon_cel`), but `moon search rego` and `moon search "opa policy"`
return no modules.

## Scope

- Lexer and parser for Rego modules: packages, imports, complete and partial
  rules, `default`, `else`, function rules, `some`, `every`, `not`,
  comprehensions and references.
- Evaluator with virtual documents, partial sets and objects, and undefined
  semantics.
- Built-ins for comparison, arithmetic, strings, arrays, objects, sets and
  type checks.
- A CLI with `eval`, `check` and `parse`, plus a conformance corpus.

Out of scope: bundles, decision logs, partial evaluation and the OPA server.

## Command line

```text
moon run cmd/moonrego -- version
moon run cmd/moonrego -- help
```

## Quality gates

```text
moon check --target all --deny-warn
moon fmt --check
moon test --target wasm --deny-warn
moon test --target wasm-gc --deny-warn
```

## License

Apache-2.0. Open Policy Agent is the semantic reference; no Go code is copied.