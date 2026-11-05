#!/bin/sh
# Differential test: runs each query in scripts/corpus.txt (one per line) through
# the real mq and through mqmq, and reports any whose output differs.
#   MQ=/path/to/mq scripts/difftest.sh [corpus-file]
# Both erroring counts as a match (the messages differ by design).
cd "$(dirname "$0")/.." || exit 1
MQ=${MQ:-mq}
corpus=${1:-scripts/corpus.txt}
total=0; bad=0
while IFS= read -r q; do
  [ -z "$q" ] && continue
  total=$((total + 1))
  want=$($MQ -I null "$q" 2>/dev/null); wst=$?
  got=$($MQ -I null -L . --arg q "$q" 'include "mqmq" | mqmq_with(q, None, {})' 2>/dev/null); gst=$?
  if [ $wst -ne 0 ] && [ $gst -ne 0 ]; then continue; fi
  if [ $wst -ne $gst ] || [ "$want" != "$got" ]; then
    bad=$((bad + 1))
    printf 'MISMATCH: %s\n  mq:   %s (exit %s)\n  mqmq: %s (exit %s)\n' "$q" "$(echo "$want" | head -3)" "$wst" "$(echo "$got" | head -3)" "$gst"
  fi
done < "$corpus"
echo "$bad mismatches / $total queries"
[ "$bad" -eq 0 ]
# scripts/corpus_known_diffs.txt lists queries where mqmq deliberately (or not
# yet) differs from mq: the older `break expr`, names mq does not define
# (`unique`, `head`, `upper`, ...), and `}` inside an interpolated string.
