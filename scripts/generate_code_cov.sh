#!/bin/bash

BINARY_PATH=$1
PROF_DATA_PATH=$2
IGNORE_FILENAME_REGEX=$3
CODECOV_TOKEN=$4

swift test --enable-code-coverage

llvm-cov report \
    $BINARY_PATH \
    --format=text \
    -instr-profile="$PROF_DATA_PATH" \
    -ignore-filename-regex="$IGNORE_FILENAME_REGEX"

llvm-cov show \
    $BINARY_PATH \
    -instr-profile="$PROF_DATA_PATH" \
    -ignore-filename-regex="$IGNORE_FILENAME_REGEX" > coverage.txt

bash <(curl -s https://codecov.io/bash) \
    -J "RediStack" \
    -D ".build/debug" \
    -t "$CODECOV_TOKEN"
