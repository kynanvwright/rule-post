#!/bin/bash
set -e

echo "🚀 Setting up development environment..."

# Get the workspace directory (parent of .devcontainer)
WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$WORKSPACE_DIR"

# Ensure Flutter is in PATH
export PATH="/home/vscode/flutter/bin:$PATH"

# Configure Flutter
echo "🔧 Configuring Flutter..."
flutter config --enable-web --no-analytics
flutter doctor -v || true

# Install Firebase CLI
echo "🔥 Installing Firebase CLI..."
sudo env "PATH=$PATH" npm install -g firebase-tools

# Install TypeScript globally
echo "📘 Installing TypeScript..."
sudo env "PATH=$PATH" npm install -g typescript

# Install project dependencies
if [ -d "$WORKSPACE_DIR/functions" ]; then
    echo "📦 Installing Firebase Functions dependencies..."
    cd "$WORKSPACE_DIR/functions"
    npm install
fi

if [ -d "$WORKSPACE_DIR/flutter_app" ]; then
    echo "📦 Installing Flutter dependencies..."
    cd "$WORKSPACE_DIR/flutter_app"
    flutter pub get
fi

echo "✅ Development environment setup complete!"
echo ""
echo "🎯 Quick Start Commands:"
echo "  cd flutter_app && flutter run -d web-server --web-port 3000"
echo "  firebase emulators:start"
echo "  cd functions && npm run build"
echo ""
echo "Run 'flutter doctor' to verify the installation."
