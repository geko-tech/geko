#!/usr/bin/env bash

set -euo pipefail

ROOT_PATH="${GITHUB_WORKSPACE}"
BIN_PATH="$(xcrun swift build --show-bin-path)"
PROFDATA_PATH="$(find "${BIN_PATH}" -type f -name '*.profdata' -print -quit)"

XCTEST_PATH="$(
  find "${BIN_PATH}" \
    -maxdepth 2 \
    -name '*PackageTests.xctest' \
    -print \
    -quit
)"

if [[ -z "${PROFDATA_PATH}" ]]; then
  echo "Coverage profile was not found"
  exit 1
fi

if [[ -z "${XCTEST_PATH}" ]]; then
  echo "Test bundle was not found"
  exit 1
fi

TEST_BINARY_NAME="$(basename "${XCTEST_PATH}" .xctest)"
TEST_BINARY="${XCTEST_PATH}/Contents/MacOS/${TEST_BINARY_NAME}"

if [[ ! -f "${TEST_BINARY}" ]]; then
  echo "Test binary was not found: ${TEST_BINARY}"
  exit 1
fi

echo "Test binary: ${TEST_BINARY}"
echo "Coverage profile: ${PROFDATA_PATH}"

PRODUCTION_SOURCES=()

while IFS= read -r -d '' source_file; do
  PRODUCTION_SOURCES+=("${source_file}")
done < <(
  find "${ROOT_PATH}/Sources" \
    -type d \
    -name '*Testing' \
    -prune \
    -o \
    -type f \
    -name '*.swift' \
    -print0
)

if [[ ${#PRODUCTION_SOURCES[@]} -eq 0 ]]; then
  echo "Production Swift sources were not found"
  exit 1
fi

echo "Production source files: ${#PRODUCTION_SOURCES[@]}"

COVERAGE_DIRECTORY="${ROOT_PATH}/coverage"
COVERAGE_REPORT_PATH="${COVERAGE_DIRECTORY}/coverage-report.txt"

mkdir -p "${COVERAGE_DIRECTORY}"

xcrun llvm-cov report \
  "${TEST_BINARY}" \
  -instr-profile="${PROFDATA_PATH}" \
  -show-branch-summary=false \
  "${PRODUCTION_SOURCES[@]}" \
  | tee "${COVERAGE_REPORT_PATH}"

COVERAGE_SUMMARY="$(
  awk '
    NR <= 2 {
      print
      next
    }

    $1 == "TOTAL" {
      print
      exit
    }
  ' "${COVERAGE_REPORT_PATH}"
)"

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "## Code coverage"
    echo
    echo "Coverage includes production Swift files from \`Sources\`."
    echo
    echo "The following files are excluded:"
    echo
    echo "- targets whose directory name ends with \`Testing\`"
    echo "- all files under \`Tests\`"
    echo
    echo '```text'
    echo "${COVERAGE_SUMMARY}"
    echo '```'
    echo
    echo "Full report: \`coverage/coverage-report.txt\`"
  } >> "${GITHUB_STEP_SUMMARY}"

  echo "Coverage was added to GitHub Actions summary"
fi
