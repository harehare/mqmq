#!/bin/sh
# Lists host (mq) built-ins that eval.mq does not mention, i.e. features mqmq
# has not caught up with. Usage: scripts/check_builtins.sh
cd "$(dirname "$0")/.." || exit 1
mq help 2>&1 | sed -n '/^Functions:/,$p' | grep -E '^  [a-z_0-9]+$' | tr -d ' ' | sort -u |
while read -r n; do
  grep -q "\"$n\"" eval.mq || echo "$n"
done
