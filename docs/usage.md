# Usage
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

See also: [language reference](language.md), [development](development.md).
