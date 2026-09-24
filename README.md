<p align="center"><img src="assets/logo.svg" width="120" height="120" alt="mqmq logo" /></p>
<h1 align="center">mqmq</h1>

<p align="center">A self-hosted <a href="https://github.com/harehare/mq">mq</a> interpreter: mq's own query language, implemented in mq.</p>
<p align="center"><em>A hobby project and self-hosting experiment, not a production-grade or spec-compliant mq implementation.</em></p>

`mqmq` is a meta-interpreter for the `mq` query language, written in `mq` itself.
It demonstrates that `mq` is expressive enough to implement its own core evaluation model:
a tokenizer → parser → tree-walking evaluator pipeline, layered on top of the real `mq` runtime.

> This is a hobby project, built for fun and to explore what `mq` can express, not a
> production-grade or fully spec-compliant `mq` implementation. See
> [Known Limitations](#known-limitations) for what's intentionally out of scope.

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
    ▼  eval.mq   ── mq_eval(ast, value, env)
  result
```

| Module | Role |
|--------|------|
| `lexer.mq`  | Tokenizer: converts a query string into a flat list of typed tokens |
| `parser.mq` | Recursive-descent parser: builds an AST from the token stream |
| `eval.mq`   | Tree-walking evaluator: evaluates the AST against an input Markdown node |
| `mqmq.mq`   | Entry point: wires the three stages together |
| `moku.mq`   | Markdown template renderer using mqmq expressions |

## Installation

Clone or copy this directory anywhere and reference it with `-L`:

```sh
git clone https://github.com/harehare/mqmq.git
```

## Usage

`mqmq.mq` is loaded with `include`, then called as a function: `nodes | mqmq("<mq-query>")`.
`nodes` (all input Markdown nodes) is passed in as `self`, so the query runs against the whole
document.

```sh
mq -L mqmq 'include "mqmq" | nodes | mqmq("<mq-query>")' <markdown-files...>
```

## Moku templates

`moku` is a small Markdown template module built on mqmq.  Expressions in
`<% ... %>` are mqmq source, so a JSON configuration object supplies both the
input value (`.`) and top-level variables.  This keeps template syntax small:
all transformations are ordinary mq pipes and functions.

Moku adds Markdown-oriented pipe filters to the mqmq subset, including `h1`
through `h6`, `blockquote`, `bold`, `italic`, `strike`, `code_inline`,
`code("language")`, `wikilink`, and `yaml_property("key")`.  The first group
delegates to mq's native Markdown constructors (`to_h`, `to_blockquote`, and
so on), so their output is Markdown rather than a hand-built delimiter string.

```sh
printf x | mq -L . \
  --args template $'# <% title | upper %>\n\nTags: <% join(tags, ", ") %>' \
  --args data '{"title":"Moku","tags":["mq","markdown"]}' \
  'import "moku" | moku::render_json(template, data)'
# => # MOKU
# =>
# => Tags: mq, markdown
```

```md
---
<% directors | wikilink | yaml_property("directors") %>
---

# <% title | h1 %>
<% plot | blockquote %>
```

With `{"title":"The Matrix","plot":"A simulation.","directors":["Lana Wachowski"]}`,
this renders as:

```md
---
directors:
  - [[Lana Wachowski]]
---

# The Matrix
> A simulation.
```

For files, grant only the directory containing the template and config read
access:

```sh
printf x | mq --allow-read=. -L . \
  'import "moku" | moku::render_files("note.template.md", "note.json")'
```

The first version deliberately renders expressions only; it does not add a
second control-tag language.  Use mqmq's existing `if`, `let`, `match`,
functions, and collection operations inside an expression instead.

### Examples

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

- **Streaming semantics**: Selectors (`.h1`, `.text`, etc.) return arrays rather than
  individual streaming values. Piping a selector into a per-node transform (`| to_md_text`)
  operates on the whole array, not each node independently.
- **No file-based `import`/`include`**: inline `module name: ... end` is supported, but mqmq's own
  interpreted language cannot load and namespace a *separate* `.mq` file at runtime the way real `mq`'s
  `import "file"` / `include "file"` do. That would require re-entering the whole
  lex to parse to eval pipeline recursively with its own file resolution, which is out of scope for a
  single-query meta-interpreter.
- **`|=` in-place path assignment is not implemented**: real `mq`'s `.code.value |= "x"` mutates a
  value at a selector path; mqmq only supports simple `var x |= y` on a plain variable (currently
  treated the same as `x = y`).
- **Every statement must be `|`-chained**: real `mq` allows bare newline-separated statements in some
  contexts (e.g. consecutive `def`s inside a `module` block or at the top of a file, with no `|`
  between them). mqmq's parser always requires an explicit `|` between statements, including inside
  `module` bodies.
- **Match patterns don't nest**: array patterns (`[a, b]`, `[head, ..tail]`) and dict patterns
  (`{name, age}`) only bind identifiers (or a rest identifier); they can't contain nested literal or
  type sub-patterns the way real `mq` allows.
- **`catch(e)` binder isn't scope-restricted**: real `mq` scopes the bound error variable to the catch
  expression only; mqmq binds it into the same flat environment as `let`/`var`, so (consistent with how
  mqmq handles all other bindings) it stays visible after the `try` if nothing else overwrites it.
- **`@` conversion operator**: reimplemented from scratch (see `_eval_convert` in `eval.mq`) since
  mqmq's atoms evaluate to plain strings rather than real `mq`'s distinct Symbol runtime type, so it
  can't delegate to the host `@` operator. Covers headings, blockquote, list item, strong,
  strikethrough, horizontal rule, links, `base64`/`md5`/`sha256`/`uri`/`urid`/`html`/`text`; the `:sh`
  (shell execution) target is intentionally not implemented.
- **Partial builtin coverage**: real `mq` has grown a large standard library (HTTP, file I/O, CSV/TOML
  parsing, statistics, coroutines, and more); mqmq's meta-evaluator only implements the core language
  and a modest set of builtins used by its own examples and tests.

## Performance Notes

A few characteristics of the host `mq` runtime matter a lot for code written, like this, entirely
in `mq` itself:

- **Index/slice a string by character position, not an array, when scanning it.** The host runtime
  walks grapheme boundaries from the start of the string on every `s[i]`/`s[i:j]`, so a character-at-a-
  time scan over a raw string is effectively quadratic in its length. `lexer.mq` grapheme-splits the
  query into an array once (`graphemes(query)`) and indexes/slices that array instead; array indexing
  is O(1). `_is_alpha`/`_is_digit` also switched from `regex_match` to direct range comparisons, since
  invoking the regex engine per character is far more expensive than a couple of string comparisons,
  even with `mq`'s process-wide regex cache.
- **Prefer `foreach` over a manual `var acc = [] | while (...): acc += [...] end` loop when building an
  array.** `foreach`'s accumulator is a dedicated VM opcode that collects in place; a hand-rolled `+=`
  loop goes through the generic add-two-values path, which cannot mutate in place once the loop
  variable has been read for the current iteration and ends up copying the whole array on every
  append, making the loop quadratic in its length. `eval.mq`'s `_eval_foreach` (which evaluates the
  interpreted language's *own* `foreach`) is written this way, using real `break`/`continue` inside
  the host `foreach` to short-circuit and to skip collecting a `continue`d iteration.
- **A keyword/lookup table only needs to be built once.** `lexer.mq`'s keyword set is a top-level `let`
  (evaluated once at module load, then captured by every `def` that follows, the same pattern `mq`'s
  own bundled `html.mq` module uses for `_void_tags`) checked with an O(1) dict lookup, rather than a
  function that reconstructed and linearly scanned an array on every call.

## Running the Tests

Tests are written with [`mq-test`](https://github.com/harehare/mq) (`def test_*(): assert_eq(...) end`,
auto-discovered by name), matching the convention of `mq`'s own module test suites. Most cases are
table-driven with `# @parametrize([[query, ..., expected], ...])` (see any `*_tests.mq` file) rather
than one `def` per case, so adding a case is usually a new row, not a new function:

```sh
mq-test lexer_tests.mq parser_tests.mq eval_tests.mq
```

or, to discover and run every `*_tests.mq` file in the directory:

```sh
mq-test
```

## Compatibility

Requires [mq](https://github.com/harehare/mq) v0.8.3 or later (needed for the host-level `until`,
`unless`, and `catch(e)` syntax mqmq's own evaluator relies on).

## License

MIT
