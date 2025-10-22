#!/bin/bash

# Delete the duplicate main.swift file that was causing the build error
# This script should be run from your project root directory

echo "🗑️  Looking for duplicate main.swift files..."

# Find all main.swift files
find . -name "main.swift" -type f

echo ""
echo "❌ Please delete the command-line main.swift file manually in Xcode"
echo "   Keep only the SwiftUI KidGuardAIApp main.swift file"
echo ""
echo "The correct main.swift should contain:"
echo "   - import SwiftUI"
echo "   - struct KidGuardAIApp: App"
echo "   - MenuBarExtra"
echo ""
echo "The incorrect main.swift would contain:"
echo "   - import Foundation (only)"
echo "   - ProxyService initialization"
echo "   - RunLoop.main.run()"