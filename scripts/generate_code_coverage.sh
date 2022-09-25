#!/bin/bash

##===----------------------------------------------------------------------===##
##
## This source file is part of the RediStack open source project
##
## Copyright (c) 2022 RediStack project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.txt for the list of RediStack project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##

swift test --enable-code-coverage --enable-test-discovery

BUILD_BIN_PATH=$(swift build --show-bin-path)
CODE_COV_PATH=$(swift test --show-codecov-path)

PROF_DATA_PATH="${CODE_COV_PATH%/*}/default.profdata"
TEST_BINARY_PATH="${BUILD_BIN_PATH}/RediStackPackageTests.xctest"

IGNORE_FILENAME_REGEX="(\.build|TestUtils|Tests)"

llvm-cov report \
    $TEST_BINARY_PATH \
    --format=text \
    --instr-profile="$PROF_DATA_PATH" \
    --ignore-filename-regex="$IGNORE_FILENAME_REGEX"
