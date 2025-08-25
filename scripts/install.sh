#!/usr/bin/env bash
set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "📥 Basic Local AI - Installation Script"
echo "========================================"

# Change to project root directory
cd "$PROJECT_ROOT"

echo "📍 Project root: $PROJECT_ROOT"

# Create necessary directories with proper paths
echo "📁 Creating necessary directories..."
mkdir -p "$PROJECT_ROOT/ollama_data"
mkdir -p "$PROJECT_ROOT/data"

# Ensure directories have proper permissions
chmod 755 "$PROJECT_ROOT/ollama_data" 2>/dev/null || true
chmod 755 "$PROJECT_ROOT/data" 2>/dev/null || true

echo "✅ Created ollama_data directory: $PROJECT_ROOT/ollama_data"
echo "✅ Created data directory for conversation storage: $PROJECT_ROOT/data"

# Show directory structure
echo "📂 Directory structure created:"
ls -la "$PROJECT_ROOT" | grep -E "(data|ollama_data)" || echo "   (directories may be empty)"

# Ensure executable perms for scripts
chmod +x ./scripts/*.sh || true

# Pull/prepare services
echo "🐳 Pulling Docker images..."
docker compose pull || true

# Start Ollama to install model
echo "🚀 Starting Ollama service..."
docker compose up -d ollama

# Wait for Ollama to be healthy
echo "⏳ Waiting for Ollama to become healthy..."
printf "Waiting for Ollama"
for i in {1..30}; do
  if curl -fsS http://localhost:11434/api/tags >/dev/null 2>&1; then
    echo "\n✅ Ollama is up and healthy!"
    break
  fi
  printf "."
  sleep 2
  if [[ $i -eq 30 ]]; then 
    echo "\n❌ Timeout waiting for Ollama"
    exit 1
  fi
done

# Pull default model
MODEL_NAME=${MODEL_NAME:-llama3.2:3b}
echo "📦 Installing default model: $MODEL_NAME"
echo "   📥 This may take 5-15 minutes for the first download..."
echo "   💾 Model size: ~2-4 GB (depending on model)"

if docker exec basic-ollama ollama pull "$MODEL_NAME"; then
    echo "✅ Model '$MODEL_NAME' installed successfully"
else
    echo "❌ Failed to install model '$MODEL_NAME'"
    echo "   Trying alternative model names..."
    
    # Try alternative model names
    ALTERNATIVE_MODELS=("llama3.2:1b" "llama3.1:3b" "llama3.1:1b")
    MODEL_INSTALLED=false
    
    for alt_model in "${ALTERNATIVE_MODELS[@]}"; do
        echo "   🔄 Trying alternative model: $alt_model"
        if docker exec basic-ollama ollama pull "$alt_model"; then
            echo "✅ Alternative model '$alt_model' installed successfully"
            MODEL_INSTALLED=true
            break
        fi
    done
    
    if [ "$MODEL_INSTALLED" = false ]; then
        echo "❌ Failed to install any compatible model"
        echo "   Please check your internet connection and try again"
        exit 1
    fi
fi

echo ""
echo "🎉 Installation complete!"
echo "================================"
echo "✅ Ollama service is running"
echo "✅ AI model is installed"
echo "✅ Data directories created with proper permissions"
echo "🚀 Use './scripts/start.sh' to run the full stack"
echo "📱 API will be available at: http://localhost:5000"
echo "🌐 Web interface will be available at: http://localhost:5000"
echo ""
echo "💡 Note: If running from WSL, ensure Docker Desktop has access to your Windows drives"

