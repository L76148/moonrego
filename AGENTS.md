# Project Agents.md Guide

This is a [MoonBit](https://docs.moonbitlang.com) project.

You can browse and install extra skills here:
<https://github.com/moonbitlang/skills>

## Project Structure

- MoonBit packages are organized per directory; each directory contains a
  `moon.pkg` file listing its dependencies. Each package has its files and
  blackbox test files (ending in `_test.mbt`) and whitebox test files (ending in
  `_wbtest.mbt`).
- In the toplevel directory, there is a `moon.mod` file listing module
  metadata.

## Coding convention

- MoonBit code is organized in block style, each block is separated by `///|`.
- Keep deprecated blocks in a file called `deprecated.mbt` in each directory.

## Tooling

- `moon fmt` formats the code.
- `moon info` updates the generated interface (`.mbti`); commit it with the
  change.
- `moon test` runs the test suite; `moon test --update` refreshes snapshots.
- Run `moon check --deny-warn` and `moon fmt --check` before committing.