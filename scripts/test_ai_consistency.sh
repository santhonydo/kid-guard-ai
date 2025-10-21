#!/bin/bash

# KidGuard AI - JSON Consistency Testing
# Tests that AI returns valid, parseable JSON in the expected format

echo "🧪 KidGuard AI - JSON Consistency & Reliability Tests"
echo "======================================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Function to test rule parsing
test_rule_parsing() {
    local rule_text="$1"
    local test_num=$2

    echo "Test $test_num: Rule Parsing"
    echo "Input: \"$rule_text\""

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    # Make request
    response=$(curl -s -X POST http://localhost:11434/api/generate \
        -H 'Content-Type: application/json' \
        -d "{
            \"model\": \"mistral:7b-instruct\",
            \"prompt\": \"Parse this parental control rule into JSON. Return ONLY valid JSON with no markdown, no explanation. Format: {\\\"categories\\\":[],\\\"actions\\\":[],\\\"severity\\\":\\\"\\\"}.\\n\\nRule: $rule_text\\n\\nJSON:\",
            \"stream\": false
        }" 2>/dev/null)

    # Extract AI response
    ai_response=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('response', ''))" 2>/dev/null)

    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Failed to get response from Ollama${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        echo ""
        return 1
    fi

    # Try to extract JSON (remove markdown if present)
    json_content=$(echo "$ai_response" | python3 -c "
import sys, json, re

text = sys.stdin.read()

# Remove markdown code blocks
text = re.sub(r'\`\`\`json\s*', '', text)
text = re.sub(r'\`\`\`\s*', '', text)
text = text.strip()

# Find first { and last }
start = text.find('{')
end = text.rfind('}')

if start != -1 and end != -1:
    json_str = text[start:end+1]
    print(json_str)
else:
    print(text)
" 2>/dev/null)

    # Validate JSON structure
    validation_result=$(echo "$json_content" | python3 -c "
import sys, json

try:
    data = json.load(sys.stdin)

    # Check required fields
    if 'categories' not in data:
        print('MISSING_FIELD:categories')
        sys.exit(1)
    if 'actions' not in data:
        print('MISSING_FIELD:actions')
        sys.exit(1)
    if 'severity' not in data:
        print('MISSING_FIELD:severity')
        sys.exit(1)

    # Check types
    if not isinstance(data['categories'], list):
        print('WRONG_TYPE:categories should be array')
        sys.exit(1)
    if not isinstance(data['actions'], list):
        print('WRONG_TYPE:actions should be array')
        sys.exit(1)
    if not isinstance(data['severity'], str):
        print('WRONG_TYPE:severity should be string')
        sys.exit(1)

    # Check severity values
    valid_severities = ['low', 'medium', 'high', 'critical']
    if data['severity'].lower() not in valid_severities:
        print('INVALID_VALUE:severity must be low/medium/high/critical')
        sys.exit(1)

    # Valid!
    print('VALID')
    print(json.dumps(data, indent=2))
    sys.exit(0)

except json.JSONDecodeError as e:
    print(f'INVALID_JSON:{e}')
    sys.exit(1)
except Exception as e:
    print(f'ERROR:{e}')
    sys.exit(1)
" 2>&1)

    validation_status=$?

    if [ $validation_status -eq 0 ]; then
        echo -e "${GREEN}✓ JSON is valid and well-formed${NC}"
        echo "$validation_result" | tail -n +2  # Skip "VALID" line
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗ JSON validation failed${NC}"
        echo "Error: $validation_result"
        echo ""
        echo "Raw AI response:"
        echo "$ai_response"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi

    echo ""
}

# Function to test content analysis
test_content_analysis() {
    local content="$1"
    local test_num=$2

    echo "Test $test_num: Content Analysis"
    echo "Input: \"$content\""

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    response=$(curl -s -X POST http://localhost:11434/api/generate \
        -H 'Content-Type: application/json' \
        -d "{
            \"model\": \"mistral:7b-instruct\",
            \"prompt\": \"Analyze if this content is inappropriate for children. Return ONLY valid JSON with no markdown. Format: {\\\"violation\\\":true/false,\\\"reason\\\":\\\"\\\",\\\"severity\\\":\\\"low/medium/high/critical\\\"}.\\n\\nContent: $content\\n\\nJSON:\",
            \"stream\": false
        }" 2>/dev/null)

    ai_response=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('response', ''))" 2>/dev/null)

    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Failed to get response from Ollama${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        echo ""
        return 1
    fi

    # Extract and validate JSON
    json_content=$(echo "$ai_response" | python3 -c "
import sys, json, re

text = sys.stdin.read()
text = re.sub(r'\`\`\`json\s*', '', text)
text = re.sub(r'\`\`\`\s*', '', text)
text = text.strip()

start = text.find('{')
end = text.rfind('}')

if start != -1 and end != -1:
    json_str = text[start:end+1]
    print(json_str)
else:
    print(text)
" 2>/dev/null)

    validation_result=$(echo "$json_content" | python3 -c "
import sys, json

try:
    data = json.load(sys.stdin)

    # Check required fields
    if 'violation' not in data:
        print('MISSING_FIELD:violation')
        sys.exit(1)
    if 'reason' not in data:
        print('MISSING_FIELD:reason')
        sys.exit(1)
    if 'severity' not in data:
        print('MISSING_FIELD:severity')
        sys.exit(1)

    # Check types
    if not isinstance(data['violation'], bool):
        print('WRONG_TYPE:violation should be boolean')
        sys.exit(1)
    if not isinstance(data['reason'], str):
        print('WRONG_TYPE:reason should be string')
        sys.exit(1)

    # Valid!
    print('VALID')
    print(json.dumps(data, indent=2))
    sys.exit(0)

except json.JSONDecodeError as e:
    print(f'INVALID_JSON:{e}')
    sys.exit(1)
except Exception as e:
    print(f'ERROR:{e}')
    sys.exit(1)
" 2>&1)

    validation_status=$?

    if [ $validation_status -eq 0 ]; then
        echo -e "${GREEN}✓ JSON is valid and well-formed${NC}"
        echo "$validation_result" | tail -n +2
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗ JSON validation failed${NC}"
        echo "Error: $validation_result"
        echo ""
        echo "Raw AI response:"
        echo "$ai_response"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi

    echo ""
}

# Run multiple iterations of the same prompt to test consistency
test_consistency() {
    local prompt_type="$1"
    local prompt_text="$2"
    local iterations=5

    echo "=========================================="
    echo "Consistency Test: Running same prompt $iterations times"
    echo "Type: $prompt_type"
    echo "=========================================="
    echo ""

    for i in $(seq 1 $iterations); do
        if [ "$prompt_type" = "rule" ]; then
            test_rule_parsing "$prompt_text" "$i"
        else
            test_content_analysis "$prompt_text" "$i"
        fi
        sleep 1  # Brief pause between requests
    done
}

# Test Suite 1: Rule Parsing Variety
echo "=========================================="
echo "TEST SUITE 1: Rule Parsing - Different Rules"
echo "=========================================="
echo ""

test_rule_parsing "Block all violent content and alert me immediately" 1
test_rule_parsing "Log when my child visits social media sites" 2
test_rule_parsing "Block adult content and redirect to safe search" 3
test_rule_parsing "Alert me if someone searches for weapons or drugs" 4
test_rule_parsing "Block gaming websites during school hours" 5
test_rule_parsing "Prevent access to chat applications" 6

# Test Suite 2: Content Analysis Variety
echo "=========================================="
echo "TEST SUITE 2: Content Analysis - Different Content"
echo "=========================================="
echo ""

test_content_analysis "How to build a birdhouse - woodworking tutorial" 1
test_content_analysis "First-person shooter gameplay with graphic violence" 2
test_content_analysis "Explicit adult content - NSFW warning" 3
test_content_analysis "Educational documentary about ancient civilizations" 4
test_content_analysis "How to make homemade explosives" 5
test_content_analysis "Cute cat videos compilation" 6

# Test Suite 3: Consistency - Same Prompt Multiple Times
echo "=========================================="
echo "TEST SUITE 3: Consistency Check"
echo "=========================================="
echo ""

test_consistency "rule" "Block violent video games"
sleep 2
test_consistency "content" "Tutorial on hacking websites"

# Final Report
echo "=========================================="
echo "FINAL REPORT"
echo "=========================================="
echo ""
echo "Total Tests:  $TOTAL_TESTS"
echo -e "${GREEN}Passed:       $PASSED_TESTS${NC}"
echo -e "${RED}Failed:       $FAILED_TESTS${NC}"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed! AI responses are consistent.${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠ Some tests failed. AI may need prompt engineering.${NC}"
    echo ""
    echo "Recommendations:"
    echo "1. Improve prompts to be more explicit about JSON format"
    echo "2. Add response validation/retry logic in Swift code"
    echo "3. Consider using JSON mode if model supports it"
    exit 1
fi
