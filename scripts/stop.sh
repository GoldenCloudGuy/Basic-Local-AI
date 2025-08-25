#!/bin/bash

# Basic Local AI - Graceful stop script
# Stops services but preserves data

set -e  # Exit on any error

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "⏹️  Basic Local AI - Stop Script"
echo "================================="

cd "$PROJECT_ROOT"

# Stop services gracefully
echo "🛑 Stopping Basic Local AI services..."
docker compose down

echo ""
echo "✅ Services stopped successfully!"
echo ""
echo "📊 What was preserved:"
echo "   - Generated conversations in $PROJECT_ROOT/data/conversations.json"
echo "   - Ollama models and data in $PROJECT_ROOT/ollama_data/"
echo "   - Docker images (for faster restart)"
echo ""
echo "🚀 To restart: bash scripts/start.sh"
echo "💥 To destroy everything: bash scripts/destroy.sh"
