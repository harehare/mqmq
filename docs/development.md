# Development


```sh
mq-test                    # runs every *_tests.mq
scripts/difftest.sh        # compares query results with the real mq (MQ=path/to/mq)
scripts/check_builtins.sh  # host built-ins mqmq does not know yet
mq-bench bench/benchmarks.mq --filter fibonacci_20 --iterations 1 --warmup 0
```

Design notes and the full benchmark list are in [performance.md](performance.md).
