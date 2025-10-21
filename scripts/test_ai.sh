#!/bin/bash

# KidGuard AI - Quick AI Testing Script
# Run this to verify Ollama and AI models are working

echo "🧪 KidGuard AI - AI Testing Suite"
echo "=================================================="
echo ""

# Test 1: Check Ollama is running
echo "📡 Test 1: Checking Ollama Connection..."
if curl -s http://localhost:11434/api/tags > /dev/null; then
    echo "✅ Ollama is running"
    echo ""
    echo "📦 Installed models:"
    curl -s http://localhost:11434/api/tags | python3 -c "
import sys, json
data = json.load(sys.stdin)
for model in data.get('models', []):
    name = model['name']
    size = model['size'] / 1_000_000_000
    print(f'   - {name} ({size:.1f} GB)')
"
else
    echo "❌ Ollama is not running!"
    echo "   Start it with: ollama serve"
    exit 1
fi

echo ""
echo "=================================================="
echo ""

# Test 2: Rule Parsing
echo "📝 Test 2: AI Rule Parsing"
echo "--------------------------------------------------"

test_rules=(
    "Block all violent content and alert me immediately"
    "Log when my child visits social media sites"
    "Block adult content and redirect to safe search"
)

for i in "${!test_rules[@]}"; do
    rule="${test_rules[$i]}"
    echo "Test $((i+1)): \"$rule\""

    response=$(curl -s -X POST http://localhost:11434/api/generate \
        -H 'Content-Type: application/json' \
        -d "{
            \"model\": \"mistral:7b-instruct\",
            \"prompt\": \"Parse this parental control rule into JSON. Return ONLY valid JSON with categories (array), actions (array), and severity (string). Rule: $rule\",
            \"stream\": false
        }")

    # Extract just the response text
    ai_response=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('response', ''))" 2>/dev/null)

    if [ $? -eq 0 ]; then
        echo "✅ AI Response:"
        echo "$ai_response" | head -10
    else
        echo "❌ Failed to get response"
    fi
    echo ""
done

echo "=================================================="
echo ""

# Test 3: Content Analysis
echo "🔍 Test 3: Content Violation Detection"
echo "--------------------------------------------------"

test_contents=(
    "How to build a birdhouse - woodworking tutorial"
    "First-person shooter gameplay with graphic violence"
    "Explicit adult content - NSFW warning"
)

for i in "${!test_contents[@]}"; do
    content="${test_contents[$i]}"
    echo "Test $((i+1)): \"$content\""

    response=$(curl -s -X POST http://localhost:11434/api/generate \
        -H 'Content-Type: application/json' \
        -d "{
            \"model\": \"mistral:7b-instruct\",
            \"prompt\": \"Is this content inappropriate for children? Answer with JSON {\\\"violation\\\": true/false, \\\"reason\\\": \\\"...\\\"}. Content: $content\",
            \"stream\": false
        }")

    ai_response=$(echo "$response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('response', ''))" 2>/dev/null)

    if [ $? -eq 0 ]; then
        echo "AI Analysis:"
        echo "$ai_response" | head -5
    else
        echo "❌ Failed"
    fi
    echo ""
done

echo "=================================================="
echo ""
echo "✅ All tests completed!"
echo ""
echo "Next steps:"
echo "1. Build the daemon: swift build --product KidGuardAIDaemon"
echo "2. Run the daemon: ./.build/debug/KidGuardAIDaemon --foreground"
echo "3. Build the app: swift build --product KidGuardAI"
