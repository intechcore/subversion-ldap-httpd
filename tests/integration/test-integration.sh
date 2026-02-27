#!/bin/bash
set -euo pipefail

# Integration tests for subversion-ldap-httpd Docker image.
# Usage: ./tests/integration/test-integration.sh [IMAGE_NAME:TAG]
#
# Requires: docker compose, svn client, curl

IMAGE="${1:-subversion-ldap-httpd:1.14.5}"
IMAGE_NAME="${IMAGE%%:*}"
IMAGE_TAG="${IMAGE##*:}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_URL="http://localhost:${SVN_TEST_PORT:-18080}"
PASS=0
FAIL=0

cleanup() {
    echo ""
    echo "--- Cleanup ---"
    cd "$SCRIPT_DIR"
    IMAGE_NAME="$IMAGE_NAME" IMAGE_TAG="$IMAGE_TAG" docker compose down -v 2>/dev/null || true
    rm -rf "$CHECKOUT_DIR"
}
trap cleanup EXIT

CHECKOUT_DIR=$(mktemp -d)

pass() {
    PASS=$((PASS + 1))
    echo "  PASS: $1"
}

fail() {
    FAIL=$((FAIL + 1))
    echo "  FAIL: $1"
}

wait_for_service() {
    local url="$1"
    local timeout="${2:-30}"
    for _i in $(seq 1 "$timeout"); do
        if curl -sf "$url" > /dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done
    echo "  Service did not become ready within ${timeout}s"
    docker compose -f "$SCRIPT_DIR/docker-compose.yml" logs 2>&1 | tail -20 | sed 's/^/    /'
    return 1
}

echo "=== Integration tests for $IMAGE ==="
echo ""

# --- Start services ---
echo "Starting test environment..."
cd "$SCRIPT_DIR"
IMAGE_NAME="$IMAGE_NAME" IMAGE_TAG="$IMAGE_TAG" docker compose up -d

echo "Waiting for Apache to be ready..."
if ! wait_for_service "$BASE_URL" 30; then
    fail "Apache did not start"
    echo ""
    echo "=== Results: $PASS passed, $FAIL failed ==="
    exit 1
fi
echo ""

# --- Test 1: Welcome page ---
echo "[1/12] Welcome page returns HTTP 200"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/")
if [ "$HTTP_CODE" = "200" ]; then
    pass "GET / returns 200"
else
    fail "GET / returns $HTTP_CODE (expected 200)"
fi

# --- Test 2: SVNListParentPath listing ---
echo "[2/12] SVNListParentPath listing"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -u alice:password-alice "$BASE_URL/alpha-project/")
if [ "$HTTP_CODE" = "200" ]; then
    BODY=$(curl -s -u alice:password-alice "$BASE_URL/alpha-project/")
    if echo "$BODY" | grep -q "src"; then
        pass "SVNListParentPath shows repositories (found 'src')"
    else
        fail "SVNListParentPath listing missing expected repos"
    fi
else
    fail "SVNListParentPath returns $HTTP_CODE (expected 200)"
fi

# --- Test 3: Authentication required (401 without creds) ---
echo "[3/12] Authentication required"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/alpha-project/")
if [ "$HTTP_CODE" = "401" ]; then
    pass "Unauthenticated access returns 401"
else
    fail "Unauthenticated access returns $HTTP_CODE (expected 401)"
fi

# --- Test 4: svn checkout ---
echo "[4/12] svn checkout"
if svn checkout --username alice --password password-alice --non-interactive --trust-server-cert-failures=unknown-ca \
    "$BASE_URL/alpha-project/src" "$CHECKOUT_DIR/alpha-src" > /dev/null 2>&1; then
    pass "svn checkout alpha-project/src"
else
    fail "svn checkout alpha-project/src failed"
fi

# --- Test 5: svn commit ---
echo "[5/12] svn commit (alice writes to alpha-project)"
if [ -d "$CHECKOUT_DIR/alpha-src" ]; then
    echo "test content" > "$CHECKOUT_DIR/alpha-src/testfile.txt"
    svn add "$CHECKOUT_DIR/alpha-src/testfile.txt" > /dev/null 2>&1
    if svn commit --username alice --password password-alice --non-interactive --trust-server-cert-failures=unknown-ca \
        -m "Integration test commit" "$CHECKOUT_DIR/alpha-src" > /dev/null 2>&1; then
        pass "svn commit as alice (admin) succeeds"
    else
        fail "svn commit as alice (admin) failed"
    fi
else
    fail "svn commit skipped (checkout failed)"
fi

# --- Test 6: svn list ---
echo "[6/12] svn list"
LIST_OUTPUT=$(svn list --username alice --password password-alice --non-interactive --trust-server-cert-failures=unknown-ca \
    "$BASE_URL/alpha-project/src" 2>&1)
if echo "$LIST_OUTPUT" | grep -q "testfile.txt"; then
    pass "svn list shows committed file"
else
    fail "svn list does not show testfile.txt"
fi

# --- Test 7: svn info ---
echo "[7/12] svn info"
INFO_OUTPUT=$(svn info --username alice --password password-alice --non-interactive --trust-server-cert-failures=unknown-ca \
    "$BASE_URL/alpha-project/src" 2>&1)
if echo "$INFO_OUTPUT" | grep -q "Revision:"; then
    pass "svn info returns revision info"
else
    fail "svn info did not return expected data"
fi

# --- Test 8: Authz — bob can read alpha-project ---
echo "[8/12] Authz: bob (dev) reads alpha-project"
if svn list --username bob --password password-bob --non-interactive --trust-server-cert-failures=unknown-ca \
    "$BASE_URL/alpha-project/src" > /dev/null 2>&1; then
    pass "bob can read alpha-project/src"
else
    fail "bob cannot read alpha-project/src (expected access)"
fi

# --- Test 9: Authz — charlie can read alpha-project but not write ---
echo "[9/12] Authz: charlie (viewer) reads but cannot write alpha-project"
CHARLIE_READ=false
if svn list --username charlie --password password-charlie --non-interactive --trust-server-cert-failures=unknown-ca \
    "$BASE_URL/alpha-project/src" > /dev/null 2>&1; then
    CHARLIE_READ=true
fi

# Checkout as charlie, try to commit
svn checkout --username charlie --password password-charlie --non-interactive --trust-server-cert-failures=unknown-ca \
    "$BASE_URL/alpha-project/src" "$CHECKOUT_DIR/charlie-src" > /dev/null 2>&1 || true
echo "charlie test" > "$CHECKOUT_DIR/charlie-src/charlie-test.txt" 2>/dev/null || true
svn add "$CHECKOUT_DIR/charlie-src/charlie-test.txt" > /dev/null 2>&1 || true
CHARLIE_WRITE=true
if ! svn commit --username charlie --password password-charlie --non-interactive --trust-server-cert-failures=unknown-ca \
    -m "Should fail" "$CHECKOUT_DIR/charlie-src" > /dev/null 2>&1; then
    CHARLIE_WRITE=false
fi

if $CHARLIE_READ && ! $CHARLIE_WRITE; then
    pass "charlie can read but not write alpha-project"
elif ! $CHARLIE_READ; then
    fail "charlie cannot read alpha-project (expected read access)"
else
    fail "charlie can write to alpha-project (expected read-only)"
fi

# --- Test 10: Authz — charlie denied access to beta-project ---
echo "[10/12] Authz: charlie denied access to beta-project"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -u charlie:password-charlie "$BASE_URL/beta-project/docs/")
if [ "$HTTP_CODE" = "403" ]; then
    pass "charlie gets 403 on beta-project"
else
    fail "charlie gets $HTTP_CODE on beta-project (expected 403)"
fi

# --- Test 11: WebDAV — OPTIONS returns DAV header, PROPFIND returns 207 ---
echo "[11/12] WebDAV: OPTIONS and PROPFIND"
DAV_HEADER=$(curl -s -I -u alice:password-alice -X OPTIONS "$BASE_URL/alpha-project/src/" 2>&1 | grep -i "^DAV:" || echo "")
if [ -n "$DAV_HEADER" ]; then
    pass "OPTIONS returns DAV header"
else
    fail "OPTIONS does not return DAV header"
fi

PROPFIND_CODE=$(curl -s -o /dev/null -w "%{http_code}" -u alice:password-alice -X PROPFIND \
    -H "Depth: 0" "$BASE_URL/alpha-project/src/")
if [ "$PROPFIND_CODE" = "207" ]; then
    pass "PROPFIND returns 207 Multi-Status"
else
    fail "PROPFIND returns $PROPFIND_CODE (expected 207)"
fi

# --- Test 12: Multi-repo isolation ---
echo "[12/12] Multi-repo isolation"
# Verify bob can access beta-project listing and alpha-project content is not there
BETA_LISTING=$(curl -s -u bob:password-bob "$BASE_URL/beta-project/" 2>&1)
if echo "$BETA_LISTING" | grep -q "docs"; then
    # Verify beta-project/docs repo has no alpha-project content
    BETA_DOCS=$(svn list --username bob --password password-bob --non-interactive --trust-server-cert-failures=unknown-ca \
        "$BASE_URL/beta-project/docs" 2>&1) || BETA_DOCS=""
    if echo "$BETA_DOCS" | grep -q "testfile.txt"; then
        fail "alpha-project content leaked into beta-project"
    else
        pass "Repos are isolated (beta-project has no alpha-project content)"
    fi
else
    fail "beta-project listing does not contain expected repos"
fi

# --- Summary ---
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
