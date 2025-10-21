#!/bin/bash

# Quick test of improved prompts
echo "🧪 Testing Improved Prompts"
echo "=============================="
echo ""

# Test with improved prompt (explicit JSON requirements)
test_improved() {
    echo "Test: Improved Prompt (with explicit JSON format)"

    response=$(curl -s -X POST http://localhost:11434/api/generate \
        -H 'Content-Type: application/json' \
        -d '{
            "model": "mistral:7b-instruct",
            "prompt": "You are a JSON-only API. Parse this parental control rule.\\n\\nCRITICAL: Return ONLY valid JSON, NO markdown.\\n\\nRule: Block violent video games\\n\\nRequired format (copy exactly):\\n{\\n  \"categories\": [\"violence\"],\\n  \"actions\": [\"block\"],\\n  \"severity\": \"high\"\\n}\\n\\nSEVERITY MUST BE: low, medium, high, or critical\\n\\nJSON:",
            "stream": false,
            "temperature": 0.1
        }')

    ai_response=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('response', ''))")

    echo "Response:"
    echo "$ai_response"
    echo ""

    # Validate
    validation=$(echo "$ai_response" | python3 -c "
import sys, json, re
text = sys.stdin.read()
text = re.sub(r'\`\`\`.*?\`\`\`', '', text, flags=re.DOTALL)
start = text.find('{')
end = text.rfind('}')
if start != -1 and end != -1:
    try:
        data = json.loads(text[start:end+1])
        if 'severity' in data and data['severity'] in ['low', 'medium', 'high', 'critical']:
            print('✓ VALID - Severity:', data['severity'])
        else:
            print('✗ INVALID - Severity:', data.get('severity', 'MISSING'))
    except:
        print('✗ INVALID JSON')
else:
    print('✗ NO JSON FOUND')
")

    echo "$validation"
    echo ""
}

# Run multiple times to test consistency
echo "Running 5 iterations..."
echo ""

for i in {1..5}; do
    echo "=== Iteration $i ==="
    test_improved
    sleep 1
done

echo "=============================="
echo "Test complete!"
