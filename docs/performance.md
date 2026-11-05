# Performance

## Design

`eval.mq` compiles the AST into closures once (`mq_compile`), then runs them (`mq_eval` / `mqmq_eval_ast`). Against a tree-walking evaluator, `fib(20)` went from 125 ms to 28 ms. Compiling costs about 1–3 µs per AST node, so reuse a compiled query with `mqmq_compile` when you run it more than once.

- **Purity analysis**: a node that cannot bind a name or raise `break` / `continue` returns its value alone, with no `{val, env}` pair.
- **Resolved at compile time**: built-ins, operators and literals are looked up or built once, not on every evaluation.
- **Flat pipes**: `a | b | c` and long binary chains are arrays walked by a loop.

## Costs of the host `mq` runtime

Code written in `mq` itself is shaped by these (per call, on the development machine):

- Host built-ins such as `is_none(x)` cost about 70 ns; operators, indexing and `has(x, key)` are nearly free. Prefer `x == None` and `has`.
- `map` / `filter` / `all` have a fixed cost of several hundred ns; `foreach` does not. Use `foreach` on hot paths.
- `s[i]` walks graphemes from the start, so split once with `graphemes(s)` and index that.
- A `+=` loop copies the array on every append; `foreach` collects in place.
- `set()` is O(dict size), so many sequential `set()`s are O(n²). Build dicts once, with `dict(entries)`.
- Build lookup tables at module load, not per call.

## Benchmarks

Benchmarks live in `bench/` and run with `mq-bench` from the repository root:

```sh
mq-bench bench/benchmarks.mq --filter fibonacci_20 --iterations 1 --warmup 0
mq-bench bench/benchmarks_patterns.mq --iterations 10 --warmup 2
```

| File | Measures |
|------|----------|
| `benchmarks.mq` | lex / parse / eval / full pipeline, long strings, `fib(20)` |
| `benchmarks_lists.mq`, `_parser_patterns.mq`, `_scanning.mq` | parsing of large lists, patterns, long expressions |
| `benchmarks_selectors.mq`, `_collections.mq`, `_higher_order.mq` | selectors, `foreach`, `map` / `filter` |
| `benchmarks_branches.mq`, `_patterns.mq`, `_loops.mq`, `_calls.mq` | `elif` / `match`, destructuring, loops, calls |
| `benchmarks_pipes.mq`, `_dicts.mq`, `_modules.mq`, `_builtins.mq` | long pipes, dict literals, modules, built-in dispatch |
| `benchmarks_compile.mq`, `_reuse.mq` | compile cost, reuse of a compiled query |

Timings vary a lot between runs; compare several runs before trusting a difference.
