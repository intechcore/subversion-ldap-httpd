#!/bin/bash
set -euo pipefail

# Tests for subversion-ldap-httpd Docker image.
# Includes structural checks (image, modules, user) and end-to-end integration tests.
#
# Usage: ./tests/integration/test-integration.sh [IMAGE_NAME:TAG]
#
# Requires: docker compose, curl (svn commands run inside the container)

IMAGE="${1:-subversion-ldap-httpd:1.14.5}"
IMAGE_NAME="${IMAGE%%:*}"
IMAGE_TAG="${IMAGE##*:}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_URL="http://localhost:${SVN_TEST_PORT:-18080}"
# URL for svn commands inside the container (Apache listens on 8080)
CONTAINER="svn-integration-test"
INTERNAL_URL="http://localhost:8080"
PASS=0
FAIL=0
TOTAL=17

cleanup() {
    echo ""
    echo "--- Cleanup ---"
    cd "$SCRIPT_DIR"
    IMAGE_NAME="$IMAGE_NAME" IMAGE_TAG="$IMAGE_TAG" docker compose down -v 2>/dev/null || true
}
trap cleanup EXIT

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

# Run with the platform of the image. Otherwise docker warns on stderr when an
# arm64 image runs under emulation, and the warning ends up in the output.
PLATFORM=$(docker image inspect -f '{{.Os}}/{{.Architecture}}' "$IMAGE" 2>/dev/null || echo "")

echo "=== Tests for $IMAGE ==="
echo ""

# ============================================================
# Structural checks (no running container needed)
# ============================================================

# --- Test 1: Image exists ---
echo "[1/$TOTAL] Image exists"
if docker image inspect "$IMAGE" > /dev/null 2>&1; then
    pass "Image $IMAGE found"
else
    fail "Image $IMAGE not found — build it first"
    echo ""
    echo "=== Results: $PASS passed, $FAIL failed ==="
    exit 1
fi

# --- Test 2: Apache modules loaded ---
echo "[2/$TOTAL] Required Apache modules enabled"
MODULES_OUTPUT=$(docker run --rm ${PLATFORM:+--platform "$PLATFORM"} --entrypoint "" "$IMAGE" apache2ctl -M 2>&1) || true
ALL_FOUND=true
for mod in dav_module dav_svn_module ldap_module authnz_ldap_module; do
    if ! echo "$MODULES_OUTPUT" | grep -q "$mod"; then
        ALL_FOUND=false
        fail "Module $mod not found"
    fi
done
if $ALL_FOUND; then
    pass "All required modules enabled (dav, dav_svn, ldap, authnz_ldap)"
fi

# --- Test 3: Runs as non-root ---
echo "[3/$TOTAL] Runs as non-root user"
RUN_USER=$(docker run --rm ${PLATFORM:+--platform "$PLATFORM"} --entrypoint "" "$IMAGE" id -un 2>&1)
if [ "$RUN_USER" = "subversion" ]; then
    pass "Runs as user 'subversion'"
else
    fail "Expected user 'subversion', got '$RUN_USER'"
fi

# --- Test 4: HEALTHCHECK defined ---
echo "[4/$TOTAL] HEALTHCHECK instruction present"
HC=$(docker inspect --format='{{.Config.Healthcheck}}' "$IMAGE" 2>/dev/null || echo "")
if [ -n "$HC" ] && [ "$HC" != "<nil>" ]; then
    pass "HEALTHCHECK is defined"
else
    fail "HEALTHCHECK not found in image"
fi

# --- Test 5: Subversion binary present ---
echo "[5/$TOTAL] Subversion binaries present"
if docker run --rm ${PLATFORM:+--platform "$PLATFORM"} --entrypoint "" "$IMAGE" svn --version --quiet > /dev/null 2>&1; then
    SVN_VER=$(docker run --rm ${PLATFORM:+--platform "$PLATFORM"} --entrypoint "" "$IMAGE" svn --version --quiet 2>&1)
    pass "svn $SVN_VER is installed"
else
    fail "svn binary not found"
fi

# ============================================================
# Integration tests (container with test fixtures)
# ============================================================

echo ""
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

# --- Test 6: Welcome page ---
echo "[6/$TOTAL] Welcome page returns HTTP 200"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/")
if [ "$HTTP_CODE" = "200" ]; then
    pass "GET / returns 200"
else
    fail "GET / returns $HTTP_CODE (expected 200)"
fi

# --- Test 7: SVNListParentPath listing ---
echo "[7/$TOTAL] SVNListParentPath listing"
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

# --- Test 8: Authentication required (401 without creds) ---
echo "[8/$TOTAL] Authentication required"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/alpha-project/")
if [ "$HTTP_CODE" = "401" ]; then
    pass "Unauthenticated access returns 401"
else
    fail "Unauthenticated access returns $HTTP_CODE (expected 401)"
fi

# Helper: run svn inside the container
dsvn() {
    docker exec "$CONTAINER" svn --non-interactive --trust-server-cert-failures=unknown-ca "$@"
}

# --- Test 9: svn checkout ---
echo "[9/$TOTAL] svn checkout"
if dsvn checkout --username alice --password password-alice \
    "$INTERNAL_URL/alpha-project/src" /tmp/alpha-src > /dev/null 2>&1; then
    pass "svn checkout alpha-project/src"
else
    fail "svn checkout alpha-project/src failed"
fi

# --- Test 10: svn commit ---
echo "[10/$TOTAL] svn commit (alice writes to alpha-project)"
if docker exec "$CONTAINER" test -d /tmp/alpha-src; then
    docker exec "$CONTAINER" sh -c 'echo "test content" > /tmp/alpha-src/testfile.txt'
    docker exec "$CONTAINER" svn add /tmp/alpha-src/testfile.txt > /dev/null 2>&1
    if dsvn commit --username alice --password password-alice \
        -m "Integration test commit" /tmp/alpha-src > /dev/null 2>&1; then
        pass "svn commit as alice (admin) succeeds"
    else
        fail "svn commit as alice (admin) failed"
    fi
else
    fail "svn commit skipped (checkout failed)"
fi

# --- Test 11: svn list ---
echo "[11/$TOTAL] svn list"
LIST_OUTPUT=$(dsvn list --username alice --password password-alice \
    "$INTERNAL_URL/alpha-project/src" 2>&1)
if echo "$LIST_OUTPUT" | grep -q "testfile.txt"; then
    pass "svn list shows committed file"
else
    fail "svn list does not show testfile.txt"
fi

# --- Test 12: svn info ---
echo "[12/$TOTAL] svn info"
INFO_OUTPUT=$(dsvn info --username alice --password password-alice \
    "$INTERNAL_URL/alpha-project/src" 2>&1)
if echo "$INFO_OUTPUT" | grep -q "Revision:"; then
    pass "svn info returns revision info"
else
    fail "svn info did not return expected data"
fi

# --- Test 13: Authz — bob can read alpha-project ---
echo "[13/$TOTAL] Authz: bob (dev) reads alpha-project"
if dsvn list --username bob --password password-bob \
    "$INTERNAL_URL/alpha-project/src" > /dev/null 2>&1; then
    pass "bob can read alpha-project/src"
else
    fail "bob cannot read alpha-project/src (expected access)"
fi

# --- Test 14: Authz — charlie can read alpha-project but not write ---
echo "[14/$TOTAL] Authz: charlie (viewer) reads but cannot write alpha-project"
CHARLIE_READ=false
if dsvn list --username charlie --password password-charlie \
    "$INTERNAL_URL/alpha-project/src" > /dev/null 2>&1; then
    CHARLIE_READ=true
fi

# Checkout as charlie, try to commit
dsvn checkout --username charlie --password password-charlie \
    "$INTERNAL_URL/alpha-project/src" /tmp/charlie-src > /dev/null 2>&1 || true
docker exec "$CONTAINER" sh -c 'echo "charlie test" > /tmp/charlie-src/charlie-test.txt' 2>/dev/null || true
docker exec "$CONTAINER" svn add /tmp/charlie-src/charlie-test.txt > /dev/null 2>&1 || true
CHARLIE_WRITE=true
if ! dsvn commit --username charlie --password password-charlie \
    -m "Should fail" /tmp/charlie-src > /dev/null 2>&1; then
    CHARLIE_WRITE=false
fi

if $CHARLIE_READ && ! $CHARLIE_WRITE; then
    pass "charlie can read but not write alpha-project"
elif ! $CHARLIE_READ; then
    fail "charlie cannot read alpha-project (expected read access)"
else
    fail "charlie can write to alpha-project (expected read-only)"
fi

# --- Test 15: Authz — charlie denied access to beta-project ---
echo "[15/$TOTAL] Authz: charlie denied access to beta-project"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -u charlie:password-charlie "$BASE_URL/beta-project/docs/")
if [ "$HTTP_CODE" = "403" ]; then
    pass "charlie gets 403 on beta-project"
else
    fail "charlie gets $HTTP_CODE on beta-project (expected 403)"
fi

# --- Test 16: WebDAV — OPTIONS returns DAV header, PROPFIND returns 207 ---
echo "[16/$TOTAL] WebDAV: OPTIONS and PROPFIND"
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

# --- Test 17: Multi-repo isolation ---
echo "[17/$TOTAL] Multi-repo isolation"
# Verify bob can access beta-project listing and alpha-project content is not there
BETA_LISTING=$(curl -s -u bob:password-bob "$BASE_URL/beta-project/" 2>&1)
if echo "$BETA_LISTING" | grep -q "docs"; then
    # Verify beta-project/docs repo has no alpha-project content
    BETA_DOCS=$(dsvn list --username bob --password password-bob \
        "$INTERNAL_URL/beta-project/docs" 2>&1) || BETA_DOCS=""
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
