#!/usr/bin/env bash
# ==============================================================================
# Automated Verification Test Suite for Project 6: ECS Fargate Microservices
# ==============================================================================
set -e

BASE_URL="${1:-http://localhost:8888}"
echo "============================================================"
echo " Starting End-to-End Microservices Test Suite on $BASE_URL"
echo "============================================================"

# Colors for terminal output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

pass() { echo -e "${GREEN}✔ PASS:${NC} $1"; }
fail() { echo -e "${RED}✖ FAIL:${NC} $1"; exit 1; }

# 1. Health Checks
echo -e "\n1. Verifying Microservices Health via ALB..."
AUTH_HEALTH=$(curl -s "$BASE_URL/api/auth/health")
echo "$AUTH_HEALTH" | grep -q '"status": "healthy"' && pass "Auth Service is healthy (Redis connected)" || fail "Auth Health Failed"

ORDERS_HEALTH=$(curl -s "$BASE_URL/api/orders/health")
echo "$ORDERS_HEALTH" | grep -q '"status": "healthy"' && pass "Orders Service is healthy (Discovery configured)" || fail "Orders Health Failed"

NOTIF_HEALTH=$(curl -s "$BASE_URL/api/notifications/health")
echo "$NOTIF_HEALTH" | grep -q '"status": "healthy"' && pass "Notifications Service is healthy" || fail "Notifications Health Failed"

# 2. User Registration & Login (Auth Microservice)
echo -e "\n2. Testing User Registration & Authentication (Auth Service)..."
RANDOM_USER="tester_$(date +%s)@example.com"
REG_RES=$(curl -s -X POST "$BASE_URL/api/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"Graduation Evaluator\",\"email\":\"$RANDOM_USER\",\"password\":\"SecurePassword2026!\"}")
echo "$REG_RES" | grep -q '"message": "User registered successfully"' && pass "User Registration Succeeded" || fail "Registration Failed"

LOGIN_RES=$(curl -s -X POST "$BASE_URL/api/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$RANDOM_USER\",\"password\":\"SecurePassword2026!\"}")
echo "$LOGIN_RES" | grep -q '"token":' && pass "User Authentication & JWT Issuance Succeeded" || fail "Login Failed"

TOKEN=$(echo "$LOGIN_RES" | python3 -c "import sys, json; print(json.load(sys.stdin).get('token', ''))")

# 3. Inter-Service Communication: Orders -> Auth (Verification) & Orders -> Notifications
echo -e "\n3. Testing Inter-Service Communication via Cloud Map Service Discovery..."
ORDER_RES=$(curl -s -X POST "$BASE_URL/api/orders" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"items":[{"name":"AWS ECS Deep Dive Handbook","price":49.99,"quantity":2}]}')

echo "$ORDER_RES" | grep -q '"notificationDispatched": true' && pass "Order Created & Cloud Map Notification Dispatched" || fail "Order Placement Failed"

ORDER_ID=$(echo "$ORDER_RES" | python3 -c "import sys, json; print(json.load(sys.stdin)['order']['id'])")

# 4. Verify Dispatched Notification in Notifications Service
echo -e "\n4. Verifying Event Ingestion in Notifications Service..."
NOTIF_FOUND=false
for i in {1..6}; do
  HISTORY_RES=$(curl -s "$BASE_URL/api/notifications/history")
  if echo "$HISTORY_RES" | grep -q "$ORDER_ID"; then
    NOTIF_FOUND=true
    break
  fi
  sleep 1
done

if [ "$NOTIF_FOUND" = true ]; then
  pass "Notification Record Found in Service Log"
else
  fail "Notification Record Missing"
fi

# 5. Order Cancellation
echo -e "\n5. Testing Order Lifecycle Operations..."
CANCELLED=false
for i in {1..6}; do
  CANCEL_RES=$(curl -s -X DELETE "$BASE_URL/api/orders/$ORDER_ID" \
    -H "Authorization: Bearer $TOKEN")
  if echo "$CANCEL_RES" | grep -q '"status": "CANCELLED"'; then
    CANCELLED=true
    break
  fi
  sleep 1
done

if [ "$CANCELLED" = true ]; then
  pass "Order Cancelled & Update Notification Dispatched"
else
  fail "Cancellation Failed"
fi

echo -e "\n============================================================"
echo -e "${GREEN}All 5 Test Suites Passed Successfully!${NC}"
echo "============================================================"

