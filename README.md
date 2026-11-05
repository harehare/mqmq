<p align="center"><img src="assets/logo.svg" width="120" height="120" alt="mqmq logo" /></p>
<h1 align="center">mqmq</h1>

<p align="center">A self-hosted <a href="https://github.com/harehare/mq">mq</a> interpreter: mq's own query language, implemented in mq.</p>
<p align="center"><em>A hobby project and self-hosting experiment, not a production-grade or spec-compliant mq implementation.</em></p>

`mqmq` is a meta-interpreter for the `mq` query language, written in `mq` itself. It demonstrates that `mq` is expressive enough to implement its own core evaluation model: a tokenizer, a parser, and a tree-walking evaluator, layered on top of the real `mq` runtime.

> This is a hobby project, built for fun and to explore what `mq` can express, not a production-grade or fully spec-compliant `mq` implementation. See [Known Limitations](#known-limitations) for what's intentionally out of scope.

## Architecture

```
query string ─ lexer.mq ─▶ tokens ─ parser.mq ─▶ AST ─ eval.mq (compile → closures) ─▶ result
```

| Module | Role |
|--------|------|
| `lexer.mq`  | Tokenizer |
| `parser.mq` | Recursive-descent parser |
| `eval.mq`   | Compiles the AST into closures once, then runs them |
| `mqmq.mq`   | Entry point |

## Quick start

Requires [mq](https://github.com/harehare/mq) v0.9.0 or later.

```sh
git clone https://github.com/harehare/mqmq.git
printf '# Hello\n\n## World\n' | mq -L mqmq 'include "mqmq" | nodes | mqmq(".h2")'
# => ## World
```

## Documentation

- [Usage](docs/usage.md): compiling a query once, standalone `.mqc` programs
- [Language support](docs/language.md): supported features and known limitations
- [Development](docs/development.md): tests, differential test, benchmarks
- [Performance notes](docs/performance.md): design and measurements

## License

MIT
