#!/usr/bin/env bash
# Contract coverage: every feature and every configuration path that the
# README promises must be exercised by a test.
#
#   - each bullet under "## Features" appears in a "# Contract: <bullet>"
#     comment next to the test that exercises it
#   - each path in the "## Configuration" table is used by the integration
#     setup in tests/integration/docker-compose.yml
#
# Prints every item and exits non-zero if one is not covered.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
README="$ROOT/README.md"
COMPOSE="$ROOT/tests/integration/docker-compose.yml"
total=0
missing=0

# section <heading>: the lines between "## <heading>" and the next "## ".
section() {
    awk -v heading="## $1" '$0 == heading { found = 1; next } found && /^## / { exit } found' "$README"
}

check() {
    total=$((total + 1))
    if "$@"; then
        echo "  covered  $item"
    else
        echo "  MISSING  $item"
        missing=$((missing + 1))
    fi
}

feature_tested() { grep -rqF -- "# Contract: $feature" "$ROOT/tests/integration"; }
path_used() { grep -qF -- "$prefix" "$COMPOSE"; }

while IFS= read -r feature; do
    item="feature: $feature"
    check feature_tested
done < <(section Features | sed -n 's/^- //p')

# shellcheck disable=SC2016 # the backticks are Markdown, not a command
while IFS= read -r path; do
    prefix=${path%%\**}
    item="path: $path"
    check path_used
done < <(section Configuration | sed -n 's/^| `\([^`]*\)` |.*/\1/p')

echo "$((total - missing)) of $total contract items covered"
[[ $missing -eq 0 ]]
