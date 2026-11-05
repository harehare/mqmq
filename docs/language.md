# Language Support

## Supported features

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

Performance notes: [performance.md](performance.md).
