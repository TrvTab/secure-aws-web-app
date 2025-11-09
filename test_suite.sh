#!/bin/bash

# TEST 22 and 23 commented out since they are not pertinent. sql injection is avoided by using parametrized queries so 
# so the input is only treated as data not executable code. XSS is avoided because we are returning json reponses
# so all data is treated as data and not executable code.

# This is completely AI generated.

# Security Testing Suite for Flask Application with JWT Authentication
# Tests: Registration, Login, JWT Authorization, CRUD operations, and Security Hardening

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
ORANGE='\033[0;33m'
NC='\033[0m' # No Color

# Load environment variables from .env file if it exists
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Configuration - Uses .env variable or falls back to default
ALB_DNS="${ALB_DNS:-my-alb-123.us-east-1.elb.amazonaws.com}"
BASE_URL="http://${ALB_DNS}"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=0

# Global variable to store JWT token
JWT_TOKEN=""

# Helper function to increment test counter
pass_test() {
    ((TESTS_PASSED++))
    ((TOTAL_TESTS++))
}

fail_test() {
    ((TESTS_FAILED++))
    ((TOTAL_TESTS++))
}

echo "=========================================="
echo "  Security Testing Suite"
echo "  Target: $BASE_URL"
echo "=========================================="
echo ""

#===========================================
# SECTION 1: BASIC CONNECTIVITY
#===========================================
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}  SECTION 1: Basic Connectivity Tests${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo ""

# Test 1: Health Check
echo -e "${ORANGE}[TEST 1]Health Check${NC}"
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" $BASE_URL/healthCheck)
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)
echo "$RESPONSE" | grep -v "HTTP_CODE" | jq . 2>/dev/null || echo "$RESPONSE"
if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ PASS${NC}"
    pass_test
else
    echo -e "${RED}✗ FAIL (HTTP $HTTP_CODE)${NC}"
    fail_test
fi
echo ""

#===========================================
# SECTION 2: USER REGISTRATION TESTS
#===========================================
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}  SECTION 2: User Registration Tests${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo ""

# Test 2: Valid User Registration
echo -e "${ORANGE}[TEST 2]Valid User Registration${NC}"
TIMESTAMP=$(date +%s)
TEST_USERNAME="testuser_${TIMESTAMP}"
TEST_EMAIL="test_${TIMESTAMP}@example.com"
TEST_PASSWORD="SecurePass123!"

RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST $BASE_URL/api/register \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"${TEST_USERNAME}\",\"email\":\"${TEST_EMAIL}\",\"password\":\"${TEST_PASSWORD}\"}")
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)
echo "$RESPONSE" | grep -v "HTTP_CODE" | jq . 2>/dev/null || echo "$RESPONSE"
if [ "$HTTP_CODE" = "201" ]; then
    echo -e "${GREEN}✓ PASS - User registered successfully${NC}"
    pass_test
else
    echo -e "${RED}✗ FAIL (HTTP $HTTP_CODE)${NC}"
    fail_test
fi
echo ""

# Test 3: Duplicate Username Registration (should fail)
echo -e "${ORANGE}[TEST 3]Duplicate Username Registration (should FAIL)${NC}"
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST $BASE_URL/api/register \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"${TEST_USERNAME}\",\"email\":\"another_${TIMESTAMP}@example.com\",\"password\":\"${TEST_PASSWORD}\"}")
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)
echo "$RESPONSE" | grep -v "HTTP_CODE" | jq . 2>/dev/null || echo "$RESPONSE"
if [ "$HTTP_CODE" != "201" ] && [ "$HTTP_CODE" != "200" ]; then
    echo -e "${GREEN}✓ PASS - Correctly rejected duplicate username${NC}"
    pass_test
else
    echo -e "${RED}✗ FAIL - Should have rejected duplicate username${NC}"
    fail_test
fi
echo ""

# Test 4: Missing Required Fields (should fail)
echo -e "${ORANGE}[TEST 4]Registration Missing Username (should FAIL)${NC}"
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST $BASE_URL/api/register \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"missing_${TIMESTAMP}@example.com\",\"password\":\"${TEST_PASSWORD}\"}")
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)
echo "$RESPONSE" | grep -v "HTTP_CODE" | jq . 2>/dev/null || echo "$RESPONSE"
if [ "$HTTP_CODE" = "400" ] || [ "$HTTP_CODE" = "422" ]; then
    echo -e "${GREEN}✓ PASS - Correctly rejected missing fields${NC}"
    pass_test
else
    echo -e "${RED}✗ FAIL - Should have rejected missing fields (got HTTP $HTTP_CODE)${NC}"
    fail_test
fi
echo ""

#===========================================
# SECTION 3: AUTHENTICATION TESTS
#===========================================
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}  SECTION 3: Authentication Tests${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo ""

# Test 5: Valid Login
echo -e "${ORANGE}[TEST 5]Valid Login with JWT${NC}"
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST $BASE_URL/login \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"${TEST_USERNAME}\",\"password\":\"${TEST_PASSWORD}\"}")
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)
RESPONSE_BODY=$(echo "$RESPONSE" | grep -v "HTTP_CODE")
echo "$RESPONSE_BODY" | jq . 2>/dev/null || echo "$RESPONSE_BODY"

if [ "$HTTP_CODE" = "200" ]; then
    JWT_TOKEN=$(echo "$RESPONSE_BODY" | jq -r '.access_token' 2>/dev/null)
    if [ -n "$JWT_TOKEN" ] && [ "$JWT_TOKEN" != "null" ]; then
        echo -e "${GREEN}✓ PASS - Login successful, JWT token obtained${NC}"
        echo -e "${YELLOW}JWT Token: ${JWT_TOKEN:0:50}...${NC}"
        pass_test
    else
        echo -e "${RED}✗ FAIL - Login succeeded but no JWT token${NC}"
        fail_test
    fi
else
    echo -e "${RED}✗ FAIL (HTTP $HTTP_CODE)${NC}"
    fail_test
fi
echo ""

# Test 6: Invalid Password Login (should fail)
echo -e "${ORANGE}[TEST 6]Login with Invalid Password (should FAIL)${NC}"
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST $BASE_URL/login \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"${TEST_USERNAME}\",\"password\":\"WrongPassword123!\"}")
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)
echo "$RESPONSE" | grep -v "HTTP_CODE" | jq . 2>/dev/null || echo "$RESPONSE"
if [ "$HTTP_CODE" = "401" ]; then
    echo -e "${GREEN}✓ PASS - Correctly rejected invalid password${NC}"
    pass_test
else
    echo -e "${RED}✗ FAIL - Should have rejected invalid password${NC}"
    fail_test
fi
echo ""

# Test 7: Non-existent User Login (should fail)
echo -e "${ORANGE}[TEST 7]Login with Non-existent User (should FAIL)${NC}"
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST $BASE_URL/login \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"nonexistent_user_999\",\"password\":\"${TEST_PASSWORD}\"}")
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)
echo "$RESPONSE" | grep -v "HTTP_CODE" | jq . 2>/dev/null || echo "$RESPONSE"
if [ "$HTTP_CODE" = "401" ]; then
    echo -e "${GREEN}✓ PASS - Correctly rejected non-existent user${NC}"
    pass_test
else
    echo -e "${RED}✗ FAIL - Should have rejected non-existent user${NC}"
    fail_test
fi
echo ""

#===========================================
# SECTION 4: JWT AUTHORIZATION TESTS
#===========================================
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}  SECTION 4: JWT Authorization Tests${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo ""

# Test 8: Get User Info with Valid JWT
echo -e "${ORANGE}[TEST 8]GET /api/users/me with Valid JWT${NC}"
if [ -z "$JWT_TOKEN" ]; then
    echo -e "${RED}✗ FAIL - No JWT token available from login${NC}"
    fail_test
else
    RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X GET $BASE_URL/api/users/me \
      -H "Authorization: Bearer ${JWT_TOKEN}")
    HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)
    echo "$RESPONSE" | grep -v "HTTP_CODE" | jq . 2>/dev/null || echo "$RESPONSE"
    if [ "$HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}✓ PASS - Successfully retrieved user info${NC}"
        pass_test
    else
        echo -e "${RED}✗ FAIL (HTTP $HTTP_CODE)${NC}"
        fail_test
    fi
fi
echo ""

# Test 9: Access Protected Endpoint without JWT (should fail)
echo -e "${ORANGE}[TEST 9]GET /api/users/me WITHOUT JWT (should FAIL)${NC}"
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X GET $BASE_URL/api/users/me)
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)
echo "$RESPONSE" | grep -v "HTTP_CODE" | jq . 2>/dev/null || echo "$RESPONSE"
if [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "422" ]; then
    echo -e "${GREEN}✓ PASS - Correctly rejected request without JWT${NC}"
    pass_test
else
    echo -e "${RED}✗ FAIL - Should have rejected request without JWT${NC}"
    fail_test
fi
echo ""

# Test 10: Access Protected Endpoint with Invalid JWT (should fail)
echo -e "${ORANGE}[TEST 10]GET /api/users/me with Invalid JWT (should FAIL)${NC}"
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X GET $BASE_URL/api/users/me \
  -H "Authorization: Bearer invalid.jwt.token.here")
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)
echo "$RESPONSE" | grep -v "HTTP_CODE" | jq . 2>/dev/null || echo "$RESPONSE"
if [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "422" ]; then
    echo -e "${GREEN}✓ PASS - Correctly rejected invalid JWT${NC}"
    pass_test
else
    echo -e "${RED}✗ FAIL - Should have rejected invalid JWT${NC}"
    fail_test
fi
echo ""

#===========================================
# SECTION 5: PASSWORD UPDATE TESTS
#===========================================
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}  SECTION 5: Password Update Tests${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo ""

# Test 11: Update Password with Valid JWT
echo -e "${ORANGE}[TEST 11]PUT /api/users/me/password with Valid JWT${NC}"
NEW_PASSWORD="NewSecurePass456!"
if [ -z "$JWT_TOKEN" ]; then
    echo -e "${RED}✗ FAIL - No JWT token available${NC}"
    fail_test
else
    RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X PUT $BASE_URL/api/users/me/password \
      -H "Authorization: Bearer ${JWT_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"new_password\":\"${NEW_PASSWORD}\"}")
    HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)
    echo "$RESPONSE" | grep -v "HTTP_CODE" | jq . 2>/dev/null || echo "$RESPONSE"
    if [ "$HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}✓ PASS - Password updated successfully${NC}"
        pass_test
        # Update password for subsequent tests
        TEST_PASSWORD="$NEW_PASSWORD"
    else
        echo -e "${RED}✗ FAIL (HTTP $HTTP_CODE)${NC}"
        fail_test
    fi
fi
echo ""

# Test 12: Verify New Password Works
echo -e "${ORANGE}[TEST 12]Login with New Password${NC}"
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST $BASE_URL/login \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"${TEST_USERNAME}\",\"password\":\"${NEW_PASSWORD}\"}")
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)
RESPONSE_BODY=$(echo "$RESPONSE" | grep -v "HTTP_CODE")
echo "$RESPONSE_BODY" | jq . 2>/dev/null || echo "$RESPONSE_BODY"
if [ "$HTTP_CODE" = "200" ]; then
    JWT_TOKEN=$(echo "$RESPONSE_BODY" | jq -r '.access_token' 2>/dev/null)
    echo -e "${GREEN}✓ PASS - New password works correctly${NC}"
    pass_test
else
    echo -e "${RED}✗ FAIL - New password doesn't work (HTTP $HTTP_CODE)${NC}"
    fail_test
fi
echo ""

# Test 13: Update Password without JWT (should fail)
echo -e "${ORANGE}[TEST 13]PUT /api/users/me/password WITHOUT JWT (should FAIL)${NC}"
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X PUT $BASE_URL/api/users/me/password \
  -H "Content-Type: application/json" \
  -d "{\"new_password\":\"AnotherPass789!\"}")
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)
echo "$RESPONSE" | grep -v "HTTP_CODE" | jq . 2>/dev/null || echo "$RESPONSE"
if [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "422" ]; then
    echo -e "${GREEN}✓ PASS - Correctly rejected password update without JWT${NC}"
    pass_test
else
    echo -e "${RED}✗ FAIL - Should have rejected password update without JWT${NC}"
    fail_test
fi
echo ""

#===========================================
# SECTION 6: USER DELETION TESTS
#===========================================
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}  SECTION 6: User Deletion Tests${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo ""

# Test 14: Create Another User for Deletion Test
echo -e "${ORANGE}[TEST 14]Create User for Deletion Test${NC}"
DELETE_TIMESTAMP=$(date +%s)
DELETE_USERNAME="delusr_${DELETE_TIMESTAMP}"
DELETE_EMAIL="delete_${DELETE_TIMESTAMP}@example.com"
DELETE_PASSWORD="DeletePass123!"

RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST $BASE_URL/api/register \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"${DELETE_USERNAME}\",\"email\":\"${DELETE_EMAIL}\",\"password\":\"${DELETE_PASSWORD}\"}")
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)
echo "$RESPONSE" | grep -v "HTTP_CODE" | jq . 2>/dev/null || echo "$RESPONSE"
if [ "$HTTP_CODE" = "201" ]; then
    echo -e "${GREEN}✓ PASS - Test user created${NC}"
    pass_test
else
    echo -e "${RED}✗ FAIL (HTTP $HTTP_CODE)${NC}"
    fail_test
fi
echo ""

# Test 15: Login as User to be Deleted
echo -e "${ORANGE}[TEST 15]Login as User to be Deleted${NC}"
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST $BASE_URL/login \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"${DELETE_USERNAME}\",\"password\":\"${DELETE_PASSWORD}\"}")
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)
RESPONSE_BODY=$(echo "$RESPONSE" | grep -v "HTTP_CODE")
DELETE_JWT_TOKEN=$(echo "$RESPONSE_BODY" | jq -r '.access_token' 2>/dev/null)
echo "$RESPONSE_BODY" | jq . 2>/dev/null || echo "$RESPONSE_BODY"
if [ "$HTTP_CODE" = "200" ] && [ -n "$DELETE_JWT_TOKEN" ] && [ "$DELETE_JWT_TOKEN" != "null" ]; then
    echo -e "${GREEN}✓ PASS - Deletion test user logged in${NC}"
    pass_test
else
    echo -e "${RED}✗ FAIL (HTTP $HTTP_CODE)${NC}"
    fail_test
fi
echo ""

# Test 16: Delete User with Valid JWT
echo -e "${ORANGE}[TEST 16]DELETE /api/users/me with Valid JWT${NC}"
if [ -z "$DELETE_JWT_TOKEN" ]; then
    echo -e "${RED}✗ FAIL - No JWT token for deletion test${NC}"
    fail_test
else
    RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X DELETE $BASE_URL/api/users/me \
      -H "Authorization: Bearer ${DELETE_JWT_TOKEN}")
    HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)
    echo "$RESPONSE" | grep -v "HTTP_CODE" | jq . 2>/dev/null || echo "$RESPONSE"
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "204" ]; then
        echo -e "${GREEN}✓ PASS - User deleted successfully${NC}"
        pass_test
    else
        echo -e "${RED}✗ FAIL (HTTP $HTTP_CODE)${NC}"
        fail_test
    fi
fi
echo ""

# Test 17: Verify Deleted User Cannot Login
echo -e "${ORANGE}[TEST 17]Login as Deleted User (should FAIL)${NC}"
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST $BASE_URL/login \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"${DELETE_USERNAME}\",\"password\":\"${DELETE_PASSWORD}\"}")
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)
echo "$RESPONSE" | grep -v "HTTP_CODE" | jq . 2>/dev/null || echo "$RESPONSE"
if [ "$HTTP_CODE" = "401" ]; then
    echo -e "${GREEN}✓ PASS - Deleted user cannot login${NC}"
    pass_test
else
    echo -e "${RED}✗ FAIL - Deleted user should not be able to login${NC}"
    fail_test
fi
echo ""

# Test 18: Delete User without JWT (should fail)
echo -e "${ORANGE}[TEST 18]DELETE /api/users/me WITHOUT JWT (should FAIL)${NC}"
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X DELETE $BASE_URL/api/users/me)
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)
echo "$RESPONSE" | grep -v "HTTP_CODE" | jq . 2>/dev/null || echo "$RESPONSE"
if [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "422" ]; then
    echo -e "${GREEN}✓ PASS - Correctly rejected deletion without JWT${NC}"
    pass_test
else
    echo -e "${RED}✗ FAIL - Should have rejected deletion without JWT${NC}"
    fail_test
fi
echo ""

#===========================================
# SECTION 7: INPUT VALIDATION TESTS
#===========================================
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}  SECTION 7: Input Validation Tests${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo ""

# Test 19: Short Username (should fail)
echo -e "${ORANGE}[TEST 19]Registration with Short Username (should FAIL)${NC}"
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST $BASE_URL/api/register \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"ab\",\"email\":\"short@example.com\",\"password\":\"ValidPass123!\"}")
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)
echo "$RESPONSE" | grep -v "HTTP_CODE" | jq . 2>/dev/null || echo "$RESPONSE"
if [ "$HTTP_CODE" = "400" ] || [ "$HTTP_CODE" = "422" ]; then
    echo -e "${GREEN}✓ PASS - Correctly rejected short username (< 3 chars)${NC}"
    pass_test
else
    echo -e "${RED}✗ FAIL - Should have rejected short username (got HTTP $HTTP_CODE)${NC}"
    fail_test
fi
echo ""

# Test 20: Invalid Email Format (should fail)
echo -e "${ORANGE}[TEST 20]Registration with Invalid Email (should FAIL)${NC}"
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST $BASE_URL/api/register \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"validuser123\",\"email\":\"notanemail\",\"password\":\"ValidPass123!\"}")
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)
echo "$RESPONSE" | grep -v "HTTP_CODE" | jq . 2>/dev/null || echo "$RESPONSE"
if [ "$HTTP_CODE" = "400" ] || [ "$HTTP_CODE" = "422" ]; then
    echo -e "${GREEN}✓ PASS - Correctly rejected invalid email${NC}"
    pass_test
else
    echo -e "${RED}✗ FAIL - Should have rejected invalid email (got HTTP $HTTP_CODE)${NC}"
    fail_test
fi
echo ""

# Test 21: Weak Password (should fail if validation exists)
echo -e "${ORANGE}[TEST 21]Registration with Weak Password (should FAIL)${NC}"
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST $BASE_URL/api/register \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"weakpass$(date +%s | tail -c 5)\",\"email\":\"weak_$(date +%s)@example.com\",\"password\":\"short7\"}")
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)
echo "$RESPONSE" | grep -v "HTTP_CODE" | jq . 2>/dev/null || echo "$RESPONSE"
if [ "$HTTP_CODE" = "400" ] || [ "$HTTP_CODE" = "422" ]; then
    echo -e "${GREEN}✓ PASS - Correctly rejected weak password (< 8 chars)${NC}"
    pass_test
else
    echo -e "${YELLOW}⚠ WARNING - Weak password accepted (got HTTP $HTTP_CODE, expected 400/422)${NC}"
    fail_test
fi
echo ""

#===========================================
# SECTION 8: SECURITY HARDENING TESTS
#===========================================
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}  SECTION 8: Security Hardening Tests${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo ""


# # Test 22: SQL Injection Attempt
# echo -e "${ORANGE}[TEST 22]SQL Injection Prevention (should FAIL)${NC}"
# RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST $BASE_URL/api/register \
#   -H "Content-Type: application/json" \
#   -d "{\"username\":\"admin'OR'1'='1\",\"email\":\"sqli_$(date +%s)@test.com\",\"password\":\"password123\"}")
# HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)
# echo "$RESPONSE" | grep -v "HTTP_CODE" | jq . 2>/dev/null || echo "$RESPONSE"
# if [ "$HTTP_CODE" = "400" ] || [ "$HTTP_CODE" = "422" ]; then
#     echo -e "${GREEN}✓ PASS - SQL injection attempt blocked by input validation${NC}"
#     pass_test
# else
#     echo -e "${RED}✗ FAIL - SQL injection not properly prevented (got HTTP $HTTP_CODE)${NC}"
#     fail_test
# fi
# echo ""

# # Test 23: XSS Attempt
# echo -e "${ORANGE}[TEST 23]XSS Prevention (should FAIL)${NC}"
# RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST $BASE_URL/api/register \
#   -H "Content-Type: application/json" \
#   -d "{\"username\":\"<script>xss</script>\",\"email\":\"xss_$(date +%s)@test.com\",\"password\":\"password123\"}")
# HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)
# echo "$RESPONSE" | grep -v "HTTP_CODE" | jq . 2>/dev/null || echo "$RESPONSE"
# if [ "$HTTP_CODE" = "400" ] || [ "$HTTP_CODE" = "422" ]; then
#     echo -e "${GREEN}✓ PASS - XSS attempt blocked by input validation${NC}"
#     pass_test
# else
#     echo -e "${YELLOW}⚠ WARNING - XSS payload accepted (got HTTP $HTTP_CODE). Check if properly sanitized.${NC}"
#     fail_test
# fi
# echo ""

# Test 24: Rate Limiting Check
echo -e "${ORANGE}[TEST 24] ${YELLOW}Rate Limiting Test (should block after threshold)${NC}"
echo "Sending 10 rapid registration requests..."
RATE_LIMIT_TRIGGERED=0
for i in {1..10}; do
    SHORT_TS=$(date +%s | tail -c 6)
    RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST $BASE_URL/api/register \
      -H "Content-Type: application/json" \
      -d "{\"username\":\"RL${i}_${SHORT_TS}\",\"email\":\"rate${i}_${SHORT_TS}@test.com\",\"password\":\"RateLimit123!\"}" 2>/dev/null)
    HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)
    
    if [ "$HTTP_CODE" = "429" ]; then
        RATE_LIMIT_TRIGGERED=1
        echo -e "${YELLOW}  Request $i: Rate limited (HTTP 429)${NC}"
    elif [ "$HTTP_CODE" = "201" ] || [ "$HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}  Request $i: Accepted (HTTP $HTTP_CODE)${NC}"
    else
        echo -e "${RED}  Request $i: Other response (HTTP $HTTP_CODE)${NC}"
    fi
done

if [ $RATE_LIMIT_TRIGGERED -eq 1 ]; then
    echo -e "${GREEN}✓ PASS - Rate limiting is working${NC}"
    pass_test
else
    echo -e "${YELLOW}⚠ WARNING - Rate limiting not detected (consider implementing)${NC}"
    fail_test
fi
echo ""



# Test 25: JWT Expiration Test
echo -e "${ORANGE}[TEST 25]JWT Token Format Validation${NC}"
if [ -n "$JWT_TOKEN" ]; then
    # Check if JWT has three parts separated by dots
    JWT_PARTS=$(echo "$JWT_TOKEN" | tr '.' '\n' | wc -l)
    if [ "$JWT_PARTS" -eq 3 ]; then
        echo -e "${GREEN}✓ PASS - JWT has correct format (header.payload.signature)${NC}"
        pass_test
    else
        echo -e "${RED}✗ FAIL - JWT format invalid${NC}"
        fail_test
    fi
else
    echo -e "${YELLOW}⚠ SKIP - No JWT token available${NC}"
    fail_test
fi
echo ""

# Test 26: Password Hashing Verification
echo -e "${ORANGE}[TEST 26]Password Storage Security${NC}"
echo "Verifying that passwords are not returned in responses..."
# Get user info and check response doesn't contain password
if [ -n "$JWT_TOKEN" ]; then
    RESPONSE=$(curl -s -X GET $BASE_URL/api/users/me \
      -H "Authorization: Bearer ${JWT_TOKEN}")
    
    if echo "$RESPONSE" | grep -i "password" > /dev/null; then
        echo -e "${RED}✗ FAIL - Password data leaked in response${NC}"
        fail_test
    else
        echo -e "${GREEN}✓ PASS - No password data in user response${NC}"
        pass_test
    fi
else
    echo -e "${YELLOW}⚠ SKIP - No JWT token available${NC}"
    fail_test
fi
echo ""

# Test 27: CORS Configuration Check
echo -e "${ORANGE}[TEST 27]CORS Headers Check${NC}"
CORS_HEADERS=$(curl -I -X OPTIONS $BASE_URL/api/users/me \
  -H "Origin: http://malicious-site.com" \
  -H "Access-Control-Request-Method: GET" 2>&1)

if echo "$CORS_HEADERS" | grep -i "Access-Control-Allow-Origin" > /dev/null; then
    ALLOWED_ORIGIN=$(echo "$CORS_HEADERS" | grep -i "Access-Control-Allow-Origin" | cut -d':' -f2- | tr -d ' \r\n')
    if [ "$ALLOWED_ORIGIN" = "*" ]; then
        echo -e "${YELLOW}⚠ WARNING - CORS allows all origins (*) - consider restricting${NC}"
        fail_test
    else
        echo -e "${GREEN}✓ PASS - CORS is configured with specific origins${NC}"
        pass_test
    fi
else
    echo -e "${GREEN}✓ PASS - CORS headers not present (or properly restricted)${NC}"
    pass_test
fi
echo ""

# Test 28: JSON Content-Type Enforcement
echo -e "${ORANGE}[TEST 28]Content-Type Validation${NC}"
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST $BASE_URL/api/register \
  -H "Content-Type: text/plain" \
  -d "username=test&email=test@test.com&password=test123")
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)

if [ "$HTTP_CODE" = "400" ] || [ "$HTTP_CODE" = "415" ]; then
    echo -e "${GREEN}✓ PASS - Non-JSON content-type properly rejected${NC}"
    pass_test
else
    echo -e "${YELLOW}⚠ WARNING - Non-JSON content-type accepted (got HTTP $HTTP_CODE). Consider enforcing application/json.${NC}"
    fail_test
fi
echo ""

#===========================================
# FINAL SUMMARY
#===========================================
echo ""
echo "=========================================="
echo "  TEST SUMMARY"
echo "=========================================="
echo -e "Total Tests: ${TOTAL_TESTS}"
echo -e "${GREEN}Passed: ${TESTS_PASSED}${NC}"
echo -e "${RED}Failed: ${TESTS_FAILED}${NC}"
echo ""

SUCCESS_RATE=$(awk "BEGIN {printf \"%.1f\", ($TESTS_PASSED/$TOTAL_TESTS)*100}")
echo -e "Success Rate: ${SUCCESS_RATE}%"
echo ""

if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "${GREEN}🎉 ALL TESTS PASSED! 🎉${NC}"
    echo "Your application has excellent security!"
    exit 0
elif [ "$TESTS_PASSED" -ge $((TOTAL_TESTS * 3 / 4)) ]; then
    echo -e "${YELLOW}⚠ MOST TESTS PASSED${NC}"
    echo "Your application is generally secure but has some areas for improvement."
    exit 1
else
    echo -e "${RED}❌ MULTIPLE FAILURES DETECTED${NC}"
    echo "Your application needs security improvements before production deployment."
    exit 1
fi