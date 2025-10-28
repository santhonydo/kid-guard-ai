#!/bin/bash

echo "🧪 Testing Network Extension..."

# Create the App Group directory if it doesn't exist
APP_GROUP_DIR="$HOME/Library/Group Containers/group.com.kidguardai.shared"
mkdir -p "$APP_GROUP_DIR"

# Create a simple test rule that blocks TikTok
cat > "$APP_GROUP_DIR/simple-rules.json" << 'EOF'
[
  {
    "description": "Block TikTok",
    "categories": ["tiktok", "social media"],
    "shouldBlock": true,
    "isActive": true
  }
]
EOF

echo "✅ Created test rule for TikTok blocking"
echo "📁 Rule file location: $APP_GROUP_DIR/simple-rules.json"
echo "📄 Rule content:"
cat "$APP_GROUP_DIR/simple-rules.json"

echo ""
echo "🚀 Next steps:"
echo "1. Build the Network Extension: xcodebuild -project KidGuardAI.xcodeproj -target KidGuardAIFilterExtension"
echo "2. Install it using System Preferences or systemextensionsctl"
echo "3. Enable content filtering"
echo "4. Test TikTok access"