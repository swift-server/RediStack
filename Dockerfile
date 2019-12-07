FROM swiftlang/swift:nightly-5.2

RUN apt-get update
RUN apt-get install -y curl

ENV BINARY_PATH=".build/x86_64-unknown-linux-gnu/debug/redi-stackPackageTests.xctest"
ENV PROF_DATA_PATH=".build/x86_64-unknown-linux-gnu/debug/codecov/default.profdata"
ENV IGNORE_FILENAME_REGEX="(.build|TestUtils|Tests)"

ENTRYPOINT ["/bin/bash", "./scripts/generate_code_cov.sh", $BINARY_PATH, $PROF_DATA_PATH, $IGNORE_FILENAME_REGEX]
