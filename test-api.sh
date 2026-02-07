#!/bin/bash

# Slack Webhook Relay API テストスクリプト

set -e

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 設定
API_ENDPOINT="${API_ENDPOINT:-}"
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}"

if [ -z "$API_ENDPOINT" ] || [ -z "$SLACK_WEBHOOK" ]; then
    echo -e "${RED}Error: Required environment variables are not set.${NC}"
    echo "Usage:"
    echo "  export API_ENDPOINT='https://your-api-endpoint.com/webhooks'"
    echo "  export SLACK_WEBHOOK='https://hooks.slack.com/services/XXX/YYY/ZZZ'"
    echo "  ./test-api.sh"
    exit 1
fi

echo -e "${YELLOW}=== Slack Webhook Relay API Test ===${NC}"
echo "API Endpoint: $API_ENDPOINT"
echo "Slack Webhook: ${SLACK_WEBHOOK:0:30}..."
echo ""

# テスト1: JSON形式のアラート送信 (YAMLシンタックスハイライト付きで表示される)
echo -e "${YELLOW}Test 1: JSON Alert (with YAML syntax highlighting)${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  "${API_ENDPOINT}?d=${SLACK_WEBHOOK}" \
  -H "Content-Type: application/json" \
  -d '{
    "alert": "High CPU Usage",
    "severity": "warning",
    "host": "web-server-01",
    "cpu_usage": 85.3,
    "timestamp": "2025-02-07T10:30:00Z",
    "details": {
      "process": "java",
      "pid": 1234,
      "threshold": 80
    }
  }')

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ Test 1 Passed${NC}"
    echo "Response: $BODY"
else
    echo -e "${RED}✗ Test 1 Failed (HTTP $HTTP_CODE)${NC}"
    echo "Response: $BODY"
fi
echo ""

# テスト2: プレーンテキストの送信
echo -e "${YELLOW}Test 2: Plain Text${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  "${API_ENDPOINT}?d=${SLACK_WEBHOOK}" \
  -H "Content-Type: text/plain" \
  -d "サーバーweb-server-01が正常に起動しました")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ Test 2 Passed${NC}"
    echo "Response: $BODY"
else
    echo -e "${RED}✗ Test 2 Failed (HTTP $HTTP_CODE)${NC}"
    echo "Response: $BODY"
fi
echo ""

# テスト3: 複雑なJSONオブジェクト
echo -e "${YELLOW}Test 3: Complex JSON${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  "${API_ENDPOINT}?d=${SLACK_WEBHOOK}" \
  -H "Content-Type: application/json" \
  -d '{
    "alert_name": "Database Connection Pool Exhausted",
    "severity": "critical",
    "environment": "production",
    "service": "api-backend",
    "metrics": {
      "active_connections": 100,
      "max_connections": 100,
      "queue_size": 50,
      "avg_wait_time_ms": 5000
    },
    "tags": ["database", "performance", "api"],
    "runbook_url": "https://wiki.example.com/runbooks/db-pool-exhausted"
  }')

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ Test 3 Passed${NC}"
    echo "Response: $BODY"
else
    echo -e "${RED}✗ Test 3 Failed (HTTP $HTTP_CODE)${NC}"
    echo "Response: $BODY"
fi
echo ""

# テスト4: 不正なWebhook URL (エラーテスト)
echo -e "${YELLOW}Test 4: Invalid Webhook URL (Expected to fail)${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  "${API_ENDPOINT}?d=https://invalid-url.com/webhook" \
  -H "Content-Type: application/json" \
  -d '{"test": "message"}')

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

if [ "$HTTP_CODE" = "400" ]; then
    echo -e "${GREEN}✓ Test 4 Passed (Correctly rejected invalid URL)${NC}"
    echo "Response: $BODY"
else
    echo -e "${RED}✗ Test 4 Failed (Should have rejected, got HTTP $HTTP_CODE)${NC}"
    echo "Response: $BODY"
fi
echo ""

# テスト5: 宛先URLなし (エラーテスト)
echo -e "${YELLOW}Test 5: Missing Destination URL (Expected to fail)${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  "${API_ENDPOINT}" \
  -H "Content-Type: application/json" \
  -d '{"test": "message"}')

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

if [ "$HTTP_CODE" = "400" ]; then
    echo -e "${GREEN}✓ Test 5 Passed (Correctly rejected missing URL)${NC}"
    echo "Response: $BODY"
else
    echo -e "${RED}✗ Test 5 Failed (Should have rejected, got HTTP $HTTP_CODE)${NC}"
    echo "Response: $BODY"
fi
echo ""

# テスト6: 空のボディ (エラーテスト)
echo -e "${YELLOW}Test 6: Empty Body (Expected to fail)${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  "${API_ENDPOINT}?d=${SLACK_WEBHOOK}" \
  -H "Content-Type: application/json")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

if [ "$HTTP_CODE" = "400" ]; then
    echo -e "${GREEN}✓ Test 6 Passed (Correctly rejected empty body)${NC}"
    echo "Response: $BODY"
else
    echo -e "${RED}✗ Test 6 Failed (Should have rejected, got HTTP $HTTP_CODE)${NC}"
    echo "Response: $BODY"
fi
echo ""

# テスト7: シンプルモード
echo -e "${YELLOW}Test 7: Simple Mode (simple=true)${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  "${API_ENDPOINT}?d=${SLACK_WEBHOOK}&simple=true" \
  -H "Content-Type: application/json" \
  -d '{
    "alert": "Database Error",
    "severity": "critical",
    "host": "db-server-01",
    "error_code": 500
  }')

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ Test 7 Passed${NC}"
    echo "Response: $BODY"
else
    echo -e "${RED}✗ Test 7 Failed (HTTP $HTTP_CODE)${NC}"
    echo "Response: $BODY"
fi
echo ""

echo -e "${YELLOW}=== Test Complete ===${NC}"
