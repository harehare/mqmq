<p align="center"><img src="assets/logo.svg" width="120" height="120" alt="mqmq logo" /></p>
<h1 align="center">mqmq</h1>

<p align="center">A self-hosted <a href="https://github.com/harehare/mq">mq</a> interpreter: mq's own query language, implemented in mq.</p>
<p align="center"><em>A hobby project and self-hosting experiment, not a production-grade or spec-compliant mq implementation.</em></p>

`mqmq` is a meta-interpreter for the `mq` query language, written in `mq` itself. It demonstrates that `mq` is expressive enough to implement its own core evaluation model: a tokenizer, a parser, and a tree-walking evaluator, layered on top of the real `mq` runtime.

> This is a hobby project, built for fun and to explore what `mq` can express, not a production-grade or fully spec-compliant `mq` implementation. See [Known Limitations](#known-limitations) for what's intentionally out of scope.

## Architecture

```
query string
    │
    ▼  lexer.mq  ──  lex(query)
 token list
    │
    ▼  parser.mq ── mq_parse(tokens)
   AST
    │
    ▼  eval.mq   ── mq_compile(ast)        compile once into closures
 compiled query
    │
    ▼  eval.mq   ── mq_eval(compiled, value, env)
  result
```

| Module | Role |
|--------|------|
| `lexer.mq`  | Tokenizer: converts a query string into a flat list of typed tokens |
| `parser.mq` | Recursive-descent parser: builds an AST from the token stream |
| `eval.mq`   | Evaluator: compiles the AST into closures once, then runs them against an input Markdown node |
| `mqmq.mq`   | Entry point: wires the three stages together |

## Installation

Clone or copy this directory anywhere and reference it with `-L`:

```sh
git clone https://github.com/harehare/mqmq.git
```

## Usage

`mqmq.mq` is loaded with `include`, then called as a function: `nodes | mqmq("<mq-query>")`. `nodes` (all input Markdown nodes) is passed in as `self`, so the query runs against the whole document.

```sh
mq -L mqmq 'include "mqmq" | nodes | mqmq("<mq-query>")' <markdown-files...>
```

When applying the same query to multiple values, compile it once and reuse the result. `mqmq_compile` parses the query and compiles its AST into closures (the AST stays available as `compiled[:ast]`); `mqmq_eval_ast` accepts the same value and environment as `mqmq_with`:

```sh
mq -I null -L mqmq \
  'include "mqmq" | let ast = mqmq_compile("x + .") | [mqmq_eval_ast(ast, 2, {x: 1}), mqmq_eval_ast(ast, 3, {x: 2})]'
# => [3, 5]
```

### Compile with mq

From the directory containing the `mqmq` checkout, compile an mq program that accepts the mqmq query at run time:

```sh
mq compile -L mqmq \
  'include "mqmq" | nodes | mqmq(query)' \
  -o mqmq.mqc

printf '# Hello\n\n## World\n' | mq mqmq.mqc --args query '.h1'
# => # Hello

# Reuse the same compiled program with a Markdown file:
mq mqmq.mqc --args query '.h2' notes.md
```

The compiled program contains the imported `mqmq` modules, so running the `.mqc` file does not need `-L mqmq`. `mq compile` compiles the outer mq program; `mqmq(query)` still parses and compiles the supplied query when it runs. For repeated evaluation of the same query within one run, use `mqmq_compile` and `mqmq_eval_ast` as shown above. Recompile after changing the outer query or the mqmq source files. The `.mqc` format is experimental; recompile after upgrading mq.

## Examples

```sh
# Select all h1 headings
printf '# Hello\n\n## World\n' | mq -L mqmq 'include "mqmq" | nodes | mqmq(".h1")'
# => # Hello

# Select all headings
printf '# Hello\n\n## World\n' | mq -L mqmq 'include "mqmq" | nodes | mqmq(".h")'
# => # Hello
# => ## World

# String expression
printf '# Hello\n' | mq -L mqmq 'include "mqmq" | nodes | mqmq("\"hello\" + \" world\"")'
# => hello world

# Arithmetic
printf '# Hello\n' | mq -L mqmq 'include "mqmq" | nodes | mqmq("(2 + 3) * 4")'
# => 20

# Let binding and pipe
printf '# Hello\n' | mq -L mqmq 'include "mqmq" | nodes | mqmq("let x = 10 | x * 3")'
# => 30

# If/else
printf '# Hello\n' | mq -L mqmq 'include "mqmq" | nodes | mqmq("if (1 == 1): \"yes\" else: \"no\"")'
# => yes

# String interpolation
printf '# Hello\n' | mq -L mqmq 'include "mqmq" | nodes | mqmq("let x = 5 | s\"val=${x}\"")'
# => val=5

# try/catch
printf '# Hello\n' | mq -L mqmq 'include "mqmq" | nodes | mqmq("try: error(\"boom\") catch: \"caught\"")'
# => caught

# try/catch with error binder
printf '# Hello\n' | mq -L mqmq 'include "mqmq" | nodes | mqmq("try: error(\"boom\") catch(e): e[:message]")'
# => boom

# while + break
printf '# Hello\n' | mq -L mqmq 'include "mqmq" | nodes | mqmq("var i = 0 | while (true): i += 1 | if (i == 5): break i end end")'
# => 5

# until (loops while the condition is false)
printf '# Hello\n' | mq -L mqmq 'include "mqmq" | nodes | mqmq("var i = 0 | until (i == 5): i += 1 end | i")'
# => 5

# unless (runs only when the condition is false)
printf '# Hello\n' | mq -L mqmq 'include "mqmq" | nodes | mqmq("unless (1 == 2): \"skipped the else\"")'
# => skipped the else

# @ conversion operator
printf '# Hello\n' | mq -L mqmq 'include "mqmq" | nodes | mqmq("\"Hello\" @ :h1")'
# => # Hello

# Range operator
printf '# Hello\n' | mq -L mqmq 'include "mqmq" | nodes | mqmq("1..5")'
# => 1
# => 2
# => 3
# => 4
# => 5

# Destructuring
printf '# Hello\n' | mq -L mqmq 'include "mqmq" | nodes | mqmq("let [head, ..tail] = [1, 2, 3] | tail")'
# => 2
# => 3

# Pattern matching
printf '# Hello\n' | mq -L mqmq 'include "mqmq" | nodes | mqmq("let n = 5 | match (n): | x if (x > 0): \"positive\" | x if (x < 0): \"negative\" | _: \"zero\" end")'
# => positive

# Default parameters
printf '# Hello\n' | mq -L mqmq 'include "mqmq" | nodes | mqmq("def greet(name, greeting=\"Hi\"): greeting + \" \" + name end | greet(\"Bob\")")'
# => Hi Bob

# Inline module + namespaced call
printf '# Hello\n' | mq -L mqmq 'include "mqmq" | nodes | mqmq("module math: def add(a, b): a + b; end | math::add(5, 3)")'
# => 8
```

## Supported Language Features

| Feature | Example |
|---------|---------|
| Selectors | `.h1`, `.h2`, `.h`, `.text`, `.list`, `.table`, `.table_cell`, `.blockquote`, `.thematic_break`, `.definition`, `.html` |
| Dot (identity) | `.` |
| `nodes` (all input nodes) | `nodes` |
| Arithmetic | `1 + 2`, `x * 3`, `10 / 2` |
| Comparison | `x == y`, `x != y`, `x < y`, `x > y` |
| Boolean | `a && b`, `a \|\| b`, `!x` |
| Coalesce | `x ?? "default"` (binds tighter than `+`/`*`, matching real mq) |
| Regex match | `"abc" =~ "a.c"`, `"abc" !~ "zzz"` |
| Bit/string shift | `2 << 3`, `16 >> 3` |
| Range | `1..5`, `'a'..'e'` |
| Conversion (`@`) | `"Hello" @ :h1`, `"note" @ ">"`, `"hello" @ :base64`, `"mq" @ "https://mqlang.org"` |
| Error suppression | `error("boom")?` → `None` instead of propagating |
| String concat | `"a" + "b"` |
| String interpolation | `s"val=${x}"` |
| Let binding | `let x = 10 \| x * 2` |
| Let/var destructuring | `let [a, b] = arr`, `let [head, ..tail] = arr`, `let {name, age} = dict` |
| Var (mutable) | `var i = 0 \| i += 1` |
| Assignment ops | `+=`, `-=`, `*=`, `/=`, `%=`, `//=` |
| If/else | `if (cond): a else: b` |
| If/elif/else | `if (c1): a elif (c2): b else: c` |
| Unless | `unless (cond): a` (runs `a` only when `cond` is false) |
| Pipe | `expr \| expr` |
| Function call | `len("hello")`, `to_string(42)` |
| Coroutine / stream builtins | `to_coroutine([1,2,3]) \| collect()`, `stream_range(1, 10) \| take(3) \| collect()` |
| Default parameters | `def f(x, y=1): x + y end` |
| Array literal | `[1, 2, 3]` |
| Dict literal | `{key: "val"}` |
| Atom key access | `d[:key]` |
| Index access | `a[0]` |
| Slice access | `a[1:3]` |
| While loop | `while (cond): body end` |
| Until loop | `until (cond): body end` (loops while `cond` is false) |
| Foreach loop | `foreach (x, arr): body end` |
| Break / continue | `while (cond): break end`, `foreach (x, arr): continue end` |
| Try/catch | `try: risky() catch: fallback` |
| Try/catch with error binder | `try: risky() catch(e): e[:message]` |
| Pattern matching | `match (v): \| 1: "one" \| [x]: x \| {name}: name \| x if (x > 0): "pos" \| _: "other" end` |
| User-defined functions | `def f(x): x * 2 end \| f(5)`, or `def f(x): x * 2;` |
| Inline module + `::` | `module m: def f(x): x; end \| m::f(1)` |

## Known Limitations

- **Streaming semantics**: Selectors (`.h1`, `.text`, etc.) return arrays rather than individual streaming values. Piping a selector into a per-node transform (`| to_md_text`) operates on the whole array, not each node independently.
- **No file-based `import`/`include`**: inline `module name: ... end` is supported, but mqmq's own interpreted language can't load and namespace a *separate* `.mq` file at runtime the way real `mq`'s `import "file"` / `include "file"` do. That would require re-entering the whole lex-parse-eval pipeline recursively with its own file resolution, out of scope for a single-query meta-interpreter.
- **`|=` in-place path assignment is not implemented**: real `mq`'s `.code.value |= "x"` mutates a value at a selector path. mqmq only supports simple `var x |= y` on a plain variable, currently treated the same as `x = y`.
- **Every statement must be `|`-chained**: real `mq` allows bare newline-separated statements in some contexts, such as consecutive `def`s inside a `module` block or at the top of a file. mqmq's parser always requires an explicit `|` between statements, including inside `module` bodies.
- **Match patterns don't nest**: array patterns (`[a, b]`, `[head, ..tail]`) and dict patterns (`{name, age}`) only bind identifiers or a rest identifier. They can't contain nested literal or type sub-patterns the way real `mq` allows.
- **`catch(e)` binder isn't scope-restricted**: real `mq` scopes the bound error variable to the catch expression only. mqmq binds it into the same flat environment as `let`/`var`, so (consistent with how mqmq handles all other bindings) it stays visible after the `try` if nothing else overwrites it.
- **`@` conversion operator**: reimplemented from scratch (see `_eval_convert` in `eval.mq`) since mqmq's atoms evaluate to plain strings rather than real `mq`'s distinct Symbol runtime type, so it can't delegate to the host `@` operator. Covers headings, blockquote, list item, strong, strikethrough, horizontal rule, links, `base64`/`md5`/`sha256`/`uri`/`urid`/`html`/`text`. The `:sh` (shell execution) target is intentionally not implemented.
- **Partial builtin coverage**: real `mq` has grown a large standard library (HTTP, file I/O, CSV/TOML parsing, statistics, and more). mqmq's meta-evaluator only implements the core language and a modest set of builtins used by its own examples and tests.
- **No `yield` keyword of its own**: real `mq` compiles a generator to a bytecode chunk its VM can suspend mid-frame. Any host function that lexically contains `yield:` becomes a coroutine on every call, so wiring `yield:` into `mq_eval`'s generic dispatch would turn every evaluation into a suspended coroutine, not just the ones hitting an interpreted `yield`. mqmq does forward the eager coroutine/stream value builtins (`to_coroutine`, `stream_range`, `collect`, `take`, `skip`, `take_while`, `skip_while`, `next`, `send`, `close`, `is_coroutine`, `iterables`), so a query can build and drain a coroutine, it just can't author one with `yield`.

## Performance Notes

### Evaluator: compile once, run closures

`eval.mq` does not walk the AST on every evaluation. `mq_compile` turns each node into a closure once, and `mq_eval` (or `mqmq_eval_ast`) runs those closures. Dispatch on the node kind, dict field reads, and `{val, env}` result allocation then happen at compile time, or not at all. Measured against a tree-walking evaluator on the same machine, `fib(20)` went from 125 ms to 28 ms.

I compared representations on a minimal `fib(20)` evaluator before choosing: a dict AST with string kinds took 41 ms, a flat array AST with integer opcodes took 34 ms, and closures took 21–27 ms. A flat AST alone is worth about 17%, because the host indexes an array only slightly faster than a dict. It would also change the parser output and every test that builds an AST by hand. Compiling the parser's dict AST keeps both unchanged.

- **Purity analysis.** Each node compiles to a `[pure, code]` pair. A pure node cannot bind a name or raise `break`/`continue`, so its code returns the value alone and allocates no `{val, env}` pair. Purity is derived bottom-up, so `n - 1`, an `if` over pure branches, and a pipe of pure stages all take the cheap path. Other nodes return `{val, env[, ctrl]}`.
- **Built-ins are resolved when a call is compiled.** `_BUILTINS` maps each name to one implementation, so a call no longer scans a chain of name comparisons (up to about 900 ns for a name late in the chain). Calls of up to three arguments pass them straight to the implementation without building an argument array. A user function bound under the same name still takes precedence at run time.
- **Literals are built once.** An array or dictionary made only of numbers, strings, booleans, `None`, atoms, and other such literals is constructed at compile time, and every evaluation returns the same immutable value.
- **Operators are chosen at compile time.** `+`, `-`, `<`, `==` and the other eager operators compile to a closure that applies the host operator directly. A numeric literal on the right is read from the AST once, so it costs no call.
- **Pipes and long binary chains stay flat.** The parser stores `a | b | c` and chains of eight or more operators as arrays, and the compiler turns them into loops over stage closures. Identity stages (`.` and `self`) compile to nothing.
- **Compilation has a cost.** It is roughly 1–3 µs per AST node, so a query that is evaluated once pays it once. A typical small query spends roughly 25% as long compiling as it does lexing and parsing. Evaluating a compiled query again does not repeat it, so use `mqmq_compile` for a query you run more than once.

Rough end-to-end timings for lexing, parsing, compiling, and evaluating a query once (tree-walking evaluator → this one): `.h1` 30 → 27 µs, `map(.h, fn(h): to_text(h) end)` over 64 nodes 108 → 66 µs, a string-building query 230 → 208 µs, `filter(nodes, ...) | len()` 212 → 94 µs, `foreach` over 64 items 336 → 87 µs, a 200-iteration `while` 1.76 → 0.48 ms, and `fib(15)` 15.3 → 2.5 ms. The deepest recursion that fits in the host's recursion limit grew too.

### Host runtime costs

A few characteristics of the host `mq` runtime matter a lot for code written, like this, entirely in `mq` itself. Costs below are per call on the development machine, relative to a user-defined function call at about 25 ns:

- **Host built-in calls are expensive; operators and indexing are not.** `is_none(x)` costs about 70 ns, and so do `is_dict`, `is_array`, `is_string`, and `is_number`. `is_empty` costs 240–440 ns. `x == None` and `len(x) == 0` cost close to nothing. `has(x, key)` costs about 18 ns and, unlike `x[key]`, is safe on any type, so it replaces `is_dict(x) && x[:kind] == ...`. Hot paths in `eval.mq`, `lexer.mq`, and `parser.mq` use the cheap forms.
- **`map`, `filter`, and `all` carry a fixed cost of several hundred nanoseconds per call; `foreach` does not.** Over three items `map` takes about 525 ns and `foreach` about 90 ns. Code that runs per compile or per evaluation (argument lists, array and dictionary literals, interpolation) uses `foreach`. A `try` costs about 85 ns, so it appears only where a failure must be caught.
- **Index/slice strings by character array, not by position.** `s[i]`/`s[i:j]` walks grapheme boundaries from the start each time, so `lexer.mq` grapheme-splits once (`graphemes(query)`) and indexes that instead.
- **Prefer `foreach`'s accumulator over a manual `while` + `+=` loop.** A hand-rolled `+=` loop copies the whole array on every append; `foreach` collects in place. The compiled `foreach` uses this for the interpreted language's own `foreach`.
- **Dict/`set()` construction is expensive** — confirmed O(dict size) per `set()` call, so `n` sequential `set()`s cost O(n²). Minimize dict allocations and repeated `set()` calls in hot paths; `has()`/`keys()` are comparatively cheap.
- **Build lookup tables once, at module load**, not per call (`lexer.mq`'s keyword set, `parser.mq`'s `_BIN_PREC`, `eval.mq`'s `_BUILTINS`).

### Evaluating collections, calls, and patterns

- **Reuse arrays for identity `foreach` bodies.** When the body returns each item unchanged (`.`, `self`, or the loop variable), the evaluator returns the input array and binds only the final item.
- **Bind simple `foreach` transformations once.** For a body such as `item * 2`, the evaluator applies the operator directly to each item and binds the loop variable after collecting the results, avoiding an environment copy per item.
- **Evaluate simple `map` and `filter` bodies directly.** A function body such as `fn(item): item * 2 end` reads only its parameter and a numeric literal, so it can process each item without copying the closure environment.
- **Build dynamic dictionary literals with `dict(entries)`** after evaluating their key/value pairs. This constructs the result in one pass instead of copying it with `set()` for every pair.
- **Bind supplied function arguments in one pass** for large calls. When a large captured environment makes repeated `set()` calls expensive, bind the supplied prefix together even if trailing arguments use defaults. Missing arguments still bind in order so each default expression can read earlier parameters.
- **Call single-parameter functions directly** when their argument is supplied. This avoids building an argument array and running the general binding loop for each recursive call.
- **Bind large destructuring patterns in one pass.** Array and dictionary patterns with at least 32 names build one new environment instead of copying it for every name. Small patterns retain the direct binding path.
- **Compare literal match arms directly** so a long list of non-matching literals does not allocate a result dictionary for every arm. Number, string, boolean, and `None` patterns use their AST values without calling the evaluator for each arm.
- **Classify `.h` and `.text` selectors with one Markdown-name lookup per node.** Their older predicates called several host helpers that each repeated the lookup. A selector's predicate is chosen once, when it is compiled.
- **Function values carry their compiled body and defaults.** A function built by `def` or `fn` holds `code` and `dflt` beside its AST `params` and `body`, so a call never compiles. A function value assembled by hand from AST nodes, with neither field, is compiled on first call.

### Lexing and parsing

- **Collect long destructuring patterns with `foreach`.** After roughly 64 comma-separated names, the parser collects the remaining names without copying the growing array for each one.
- **Store pipes as flat AST stage arrays.** The parser collects `a | b | c` in source order, so compiling and running them walk an array without rebuilding a traversal stack.
- **Store long binary chains as flat AST stage arrays.** Chains with at least eight operators are flattened during parsing; the compiler turns them into a loop that preserves short-circuit behavior and bindings. Short expressions keep the simpler binary-node path.
- **Read standalone numeric and identifier right operands directly** in long binary expressions. Higher-precedence operators and postfix syntax still use the normal parser; numeric operands also reuse the following operator's precedence.
- **Let the host regex engine split the query into lexemes in one call**, falling back to a char-by-char scanner only for cases it can't represent (interpolated strings, non-ASCII, multi-code-point graphemes).
- **Bound a `foreach`-driving `range()` to its own span, not to end-of-file.** `range()` eagerly allocates, so sizing it as `range(cur, len(toks) - 1)` made parsing/lexing quadratic when a file had several lists/calls/dicts/escaped strings. `_find_closer` (parser.mq) and `_find_string_close` (lexer.mq) prescan for the real closing token instead.
- **Read each token once while finding a matching delimiter.** `_find_closer` caches the token type and value and checks punctuation only for operator tokens, reducing repeated lookups in long arrays, calls, and dictionaries.
- **Inspect the next token directly for namespaced identifiers.** The lexer always appends an EOF token, so identifier parsing can check for `::` without a bounds-checking helper call.
- **Collect interpolated-string text in spans.** The lexer slices text between escapes and `${...}` expressions, then joins each segment once. For many escapes or interpolation expressions, it stores later pieces as links to avoid repeated array copies.
- **Decode escapes directly in each lexer path.** An escape with a following character always consumes two graphemes, and only `\\n` and `\\t` change that character. Skipping a per-escape result dictionary reduces work in escaped strings.

## Running the Tests

Tests are written with [`mq-test`](https://github.com/harehare/mq) (`def test_*(): assert_eq(...) end`, auto-discovered by name), matching the convention of `mq`'s own module test suites. Most cases are table-driven with `# @parametrize([[query, ..., expected], ...])` (see any `*_tests.mq` file) rather than one `def` per case, so adding a case is usually a new row, not a new function:

```sh
mq-test lexer_tests.mq parser_tests.mq eval_tests.mq mqmq_tests.mq
```

or, to discover and run every `*_tests.mq` file in the directory:

```sh
mq-test
```

## Benchmarks

`benchmarks.mq` exercises lexing, parsing, evaluation, and the full pipeline on the same 64-number arithmetic query, plus a repeated 256-number evaluation, long strings (including interpolation and escapes), short-circuit, and recursive Fibonacci cases. The Fibonacci cases call `fib(20)` in native `mq` and `mqmq`. Benchmarks live in `bench/`. Run them with `mq-bench` from the [mq repository](https://github.com/harehare/mq), from the repository root (the current directory is searched for `import "lexer"` etc.; this needs an `mq-bench` that supports it):

```sh
mq-bench bench/benchmarks.mq --filter fibonacci_20 --iterations 1 --warmup 0
```

The interpreted `fib(20)` case is the slowest. Use `--filter arithmetic` or `--filter long_string` for quicker pipeline runs with more iterations.

Benchmarks that evaluate an AST compile it once in module setup with `eval::mq_compile`, so the timed function measures evaluation. Because the runner executes that setup on every iteration, a benchmark that evaluates a large AST only once mostly shows its compile cost; compare it with `benchmarks_compile.mq` below.

`benchmarks_lists.mq` measures parsing of larger arrays, call arguments, and dictionaries, including 2,048-element cases. Run it separately so its token generation doesn't add setup time to the Fibonacci results:

```sh
mq-bench bench/benchmarks_lists.mq --iterations 3 --warmup 1
```

`benchmarks_selectors.mq` measures selector filtering over 1,024 headings, including repeated `.h` and `.text` filtering:

```sh
mq-bench bench/benchmarks_selectors.mq --iterations 3 --warmup 1
```

`benchmarks_scanning.mq` covers long numeric and identifier expressions (including repeated parsing) and a long whitespace run without changing the setup cost of `benchmarks.mq`:

```sh
mq-bench bench/benchmarks_scanning.mq --iterations 3 --warmup 1
```

`benchmarks_branches.mq` measures evaluation of 512-way `elif` and `match` expressions, including repeated match evaluation:

```sh
mq-bench bench/benchmarks_branches.mq --iterations 3 --warmup 1
```

`benchmarks_modules.mq` measures namespace creation when the environment already contains 1,024 bindings:

```sh
mq-bench bench/benchmarks_modules.mq --iterations 3 --warmup 1
```

`benchmarks_collections.mq` measures identity and transforming `foreach` bodies over 8,192 items:

```sh
mq-bench bench/benchmarks_collections.mq --iterations 3 --warmup 1
```

`benchmarks_higher_order.mq` measures `map` and `filter` with simple numeric function bodies over 8,192 items:

```sh
mq-bench bench/benchmarks_higher_order.mq --iterations 7 --warmup 2
```

`benchmarks_reuse.mq` compares repeated parsing with explicit reuse of a compiled query:

```sh
mq-bench bench/benchmarks_reuse.mq --iterations 3 --warmup 1
```

`benchmarks_pipes.mq` measures parsing and evaluation of a 2,048-stage pipeline, including repeated evaluation of one compiled AST:

```sh
mq-bench bench/benchmarks_pipes.mq --iterations 3 --warmup 1
```

`benchmarks_dicts.mq` measures evaluation of a 1,024-entry dictionary literal:

```sh
mq-bench bench/benchmarks_dicts.mq --iterations 10 --warmup 2
```

It also measures arrays and dictionaries nested inside an array. `benchmarks_loops.mq` compares 1,000-iteration `while` and `until` loops:

```sh
mq-bench bench/benchmarks_loops.mq --iterations 10 --warmup 2
```

`benchmarks_calls.mq` measures function calls with 8 and 128 supplied parameters, plus calls with a missing defaulted parameter:

```sh
mq-bench bench/benchmarks_calls.mq --iterations 10 --warmup 2
```

`benchmarks_builtins.mq` measures repeated calls through the shared builtin dispatcher:

```sh
mq-bench bench/benchmarks_builtins.mq --iterations 10 --warmup 2
```

`benchmarks_patterns.mq` measures array and dictionary destructuring with 8, 16, and 128 names:

```sh
mq-bench bench/benchmarks_patterns.mq --iterations 10 --warmup 2
```

`benchmarks_parser_patterns.mq` measures parsing of 64, 512, and 1,024-name destructuring patterns:

```sh
mq-bench bench/benchmarks_parser_patterns.mq --iterations 10 --warmup 2
```

`benchmarks_binary_ops.mq` measures repeated short `+`, `-`, `<`, and `==` evaluation:

```sh
mq-bench bench/benchmarks_binary_ops.mq --iterations 10 --warmup 2
```

`benchmarks_compile.mq` measures compiling a parsed AST into closures: a 256-term chain, a 512-stage pipe, `fib`, a 256-entry dictionary, and a small query repeated 100 times. Its `setup_only` case isolates the module setup, which runs on every iteration; subtract it from the others:

```sh
mq-bench bench/benchmarks_compile.mq --iterations 10 --warmup 2
```

Use `--format json --output baseline.json` to save a run, then `--baseline baseline.json` on a later run to compare timings. The runner compiles once, but executes imports and top-level setup on every iteration, so compare each benchmark against the same benchmark in a previous run. The reported times are not isolated stage timings.

## Compatibility

Requires [mq](https://github.com/harehare/mq) v0.9.0 or later. v0.8.3 added the host-level `until`, `unless`, and `catch(e)` syntax mqmq's own evaluator relies on, and v0.9.0 added the coroutine/stream builtins (`to_coroutine`, `stream_range`, `collect`, etc.) forwarded in the Known Limitations above.

## License

MIT
