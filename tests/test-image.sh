#!/bin/bash
set -euo pipefail

# Smoke tests for subversion-ldap-httpd Docker image.
# Usage: ./tests/test-image.sh [IMAGE_NAME]

IMAGE="${1:-subversion-ldap-httpd:latest}"
CONTAINER_NAME="svn-test-$$"
PASS=0
FAIL=0

cleanup() {
    echo ""
    echo "--- Cleanup ---"
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
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

echo "=== Smoke tests for $IMAGE ==="
echo ""

# --- Test 1: Image exists ---
echo "[1/6] Image exists"
if docker image inspect "$IMAGE" > /dev/null 2>&1; then
    pass "Image $IMAGE found"
else
    fail "Image $IMAGE not found — build it first"
    echo ""
    echo "Results: $PASS passed, $FAIL failed"
    exit 1
fi

# --- Test 2: Apache modules loaded ---
echo "[2/6] Required Apache modules enabled"
MODULES_OUTPUT=$(docker run --rm "$IMAGE" apache2ctl -M 2>&1) || true
ALL_FOUND=true
for mod in dav_module dav_svn_module ldap_module authnz_ldap_module; do
    if echo "$MODULES_OUTPUT" | grep -q "$mod"; then
        : # ok
    else
        ALL_FOUND=false
        fail "Module $mod not found"
    fi
done
if $ALL_FOUND; then
    pass "All required modules enabled (dav, dav_svn, ldap, authnz_ldap)"
fi

# --- Test 3: Runs as non-root ---
echo "[3/6] Runs as non-root user"
RUN_USER=$(docker run --rm "$IMAGE" id -un 2>&1)
if [ "$RUN_USER" = "intechcore" ]; then
    pass "Runs as user 'intechcore'"
else
    fail "Expected user 'intechcore', got '$RUN_USER'"
fi

# --- Test 4: Apache responds on port 8080 ---
echo "[4/6] Apache responds to HTTP requests"
docker run -d --name "$CONTAINER_NAME" "$IMAGE" > /dev/null 2>&1

READY=false
for i in $(seq 1 10); do
    if docker exec "$CONTAINER_NAME" curl -sf http://localhost:8080/ > /dev/null 2>&1; then
        READY=true
        break
    fi
    sleep 1
done

if $READY; then
    pass "Apache responds on port 8080"
else
    fail "Apache did not respond within 10s"
    echo "  Container logs:"
    docker logs "$CONTAINER_NAME" 2>&1 | tail -5 | sed 's/^/    /'
fi

docker rm -f "$CONTAINER_NAME" > /dev/null 2>&1

# --- Test 5: HEALTHCHECK defined ---
echo "[5/6] HEALTHCHECK instruction present"
HC=$(docker inspect --format='{{.Config.Healthcheck}}' "$IMAGE" 2>/dev/null || echo "")
if [ -n "$HC" ] && [ "$HC" != "<nil>" ]; then
    pass "HEALTHCHECK is defined"
else
    fail "HEALTHCHECK not found in image"
fi

# --- Test 6: svnserve binary present ---
echo "[6/6] Subversion binaries present"
if docker run --rm "$IMAGE" svn --version --quiet > /dev/null 2>&1; then
    SVN_VER=$(docker run --rm "$IMAGE" svn --version --quiet 2>&1)
    pass "svn $SVN_VER is installed"
else
    fail "svn binary not found"
fi

# --- Summary ---
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
