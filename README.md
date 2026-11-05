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

## Usage

Requires [mq](https://github.com/harehare/mq) v0.9.0 or later. Clone the repo and load it with `-L`:

```sh
git clone https://github.com/harehare/mqmq.git
printf '# Hello\n\n## World\n' | mq -L mqmq 'include "mqmq" | nodes | mqmq(".h2")'
# => ## World
```

To run one query many times, compile it once:

```sh
mq -I null -L mqmq 'include "mqmq" | let ast = mqmq_compile("x + .") | [mqmq_eval_ast(ast, 2, {x: 1}), mqmq_eval_ast(ast, 3, {x: 2})]'
# => [3, 5]
```

To get a standalone program (no `-L` needed; the `.mqc` format is experimental):

```sh
mq compile -L mqmq 'include "mqmq" | nodes | mqmq(query)' -o mqmq.mqc
mq mqmq.mqc --arg query '.h2' notes.md
```

## Supported Language Features

- **Selectors**: all of mq's except `..`, `.<>`, `.[]`, `.[][]`
- **Built-ins**: about 420; core ones are implemented here, the rest are forwarded to the host
- **Expressions**: arithmetic, comparison, boolean, `??`, `=~`, `..` ranges, `@` conversion, `?` error suppression, string interpolation (`s"${x}"`)
- **Bindings**: `let` / `var` (with array and dict destructuring), assignment operators
- **Control flow**: `if`/`elif`/`else`, `unless`, `while`, `until`, `loop`, `foreach`, `break`/`continue`, `try`/`catch(e)`, `match` with guards
- **Functions**: `def`, `fn`, `->`, default parameters, parenthesis-free calls, first-class built-ins
- **Modules**: inline `module name: ... end` with `::`
- **Streams**: `to_coroutine`, `stream_range`, `collect`, `take`, ...

## Known Limitations

- Selectors return arrays instead of streaming nodes.
- No file-based `import` / `include` inside a query.
- `|=` selector-path assignment is not implemented (`xs[i] += 1` and `d[:a][:b] = v` are).
- Statements must be `|`-chained, except directly after a block closed by `end` (or a `def` closed by `;`), as in mq.
- No `yield`; no `:sh`; no built-ins that touch the host (files, network, processes, stdin, `halt`).
- A function passed to a forwarded built-in must take exactly the arguments the built-in supplies.

## Tests and Benchmarks

```sh
mq-test                    # runs every *_tests.mq
scripts/difftest.sh        # compares query results with the real mq (MQ=path/to/mq)
scripts/check_builtins.sh  # host built-ins mqmq does not know yet
mq-bench bench/benchmarks.mq --filter fibonacci_20 --iterations 1 --warmup 0
```

Design notes and the full benchmark list are in [docs/performance.md](docs/performance.md).

## License

MIT
